#!/usr/bin/env python2.7

import os as _os
from time import time as _time
from sys import stderr as _logger

'''Dispatches a batch of work, in parallel with others

Depends upon a "work_queue" table, which is composed of a (possibly composite)
integer primary key and an INT DEFAULT NULL column called "worker".

Usage:

    def worker(pkeycol1, pkeycol2):
        ... do something...

    work_queue = WorkQueue(db, 'work_queue', [ 'pkeycol1', 'pkeycol2' ], worker)
    work_queue.work()

work() loops until the table is empty. It alters a row to set worker = [not null],
then it calls worker(), and then it deletes the row it altered. worker() need not
issue a commit: work() commits before and after every task is processed (so it can
execute in parallel).
'''
class WorkQueue:
    def __init__(self, db, table, args, worker):
        self.db = db
        self.cursor = db.cursor()
        self.args = args
        self.table = table
        self.worker = worker
        self.done = False

        self.cursor.execute('PREPARE get_reserved_task AS SELECT %s FROM %s WHERE worker = %d' % (', '.join(args), self.table, self.get_worker_id()))
        self.cursor.execute('PREPARE is_done AS SELECT 1 FROM %s WHERE worker IS NULL LIMIT 1' % (self.table,))
        self.cursor.execute('''
            PREPARE reserve_task AS
            UPDATE %s
            SET worker = %d
            WHERE worker IS NULL
            AND (%s) = (
                SELECT %s
                FROM %s
                WHERE worker IS NULL
                LIMIT 1)
            RETURNING %s'''
            % (self.table, self.get_worker_id(), ', '.join(self.args), ', '.join(self.args), self.table, ', '.join(self.args)))
        self.cursor.execute('PREPARE unreserve_tasks AS UPDATE %s SET worker = NULL WHERE worker = %d' % (self.table, self.get_worker_id()))
        self.cursor.execute('PREPARE mark_task_finished AS DELETE FROM %s WHERE worker = %d' % (self.table, self.get_worker_id()))

    def get_worker_id(self):
        return _os.getpid()

    def get_reserved_task(self):
        self.cursor.execute('EXECUTE get_reserved_task')
        return self.cursor.fetchone()

    def reserve_task_and_commit(self):
        ret = self.get_reserved_task()
        attempt = 0

        while ret is None:
            attempt += 1

            if attempt >= 5:
                self.maybe_set_done()
                if self.done:
                    break

            self.cursor.execute('EXECUTE reserve_task')
            self.db.commit()
            ret = self.cursor.fetchone()

        return ret

    def unreserve_tasks_and_commit(self):
        self.cursor.execute('EXECUTE unreserve_tasks')
        self.db.commit()

    def mark_task_finished_and_commit(self):
        self.cursor.execute('EXECUTE mark_task_finished')
        self.db.commit()

    def work(self):
        self.unreserve_tasks_and_commit()
        worker_id = self.get_worker_id()

        try:
            while True:
                t1 = _time()
                task = self.reserve_task_and_commit()
                if self.done: break
                t2 = _time()
                self.worker(*task)
                t3 = _time()
                self.mark_task_finished_and_commit()
                t4 = _time()

                _logger.write(
                    '%d done %r: q1 %0.1fms, process %0.1fms, q2 %0.1fms\n' % (
                        worker_id,
                        task,
                        (t2 - t1) * 1000,
                        (t3 - t2) * 1000,
                        (t4 - t3) * 1000))

        finally:
            self.db.rollback()
            self.unreserve_tasks_and_commit()
