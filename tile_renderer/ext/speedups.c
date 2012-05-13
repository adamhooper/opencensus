#include <Python.h>
#include <pycairo.h>

static Pycairo_CAPI_t *Pycairo_CAPI;

#define ADVANCE_TO_NEXT_TOKEN(s, end) \
	do { \
		s = strchr(s, ' '); \
		if (s != NULL) s++; \
	} while (0);

int
svg_path_to_cairo_num_data(const char *svg_path, int svg_path_len)
{
	int num_data = 0;
	const char *svg_path_end = svg_path + svg_path_len + 1;
	int instruction_num_data = 0;

	while (svg_path != NULL && svg_path < svg_path_end) {
		switch (svg_path[0]) {
		case 'M':
		case 'L':
			instruction_num_data = 2;
			ADVANCE_TO_NEXT_TOKEN(svg_path, svg_path_end);
			break;
		case 'Z':
			num_data += 1;
			ADVANCE_TO_NEXT_TOKEN(svg_path, svg_path_end);
			break;
		case '0':
		case '1':
		case '2':
		case '3':
		case '4':
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
		case '-':
			num_data += instruction_num_data;
			ADVANCE_TO_NEXT_TOKEN(svg_path, svg_path_end);
			ADVANCE_TO_NEXT_TOKEN(svg_path, svg_path_end);
			break;
		default:
			ADVANCE_TO_NEXT_TOKEN(svg_path, svg_path_end);
		}
	}

	return num_data;
}

static cairo_path_t *
svg_path_to_cairo_path_impl(
		const char *svg_path, int svg_path_len,
		double meters_per_half_map, double pixels_per_meter,
		double left, double top)
{
	int num_data = svg_path_to_cairo_num_data(svg_path, svg_path_len);
	const char *svg_path_end = svg_path + svg_path_len + 1;
	cairo_path_t *path;
	cairo_path_data_t *data;
	cairo_path_data_t *cur_data;
	cairo_path_data_type_t data_type = CAIRO_PATH_MOVE_TO;

	path = malloc(sizeof(cairo_path_t));
	if (path == NULL) return NULL;

	data = malloc(sizeof(cairo_path_data_t) * num_data);
	if (data == NULL) {
		free(path);
		return NULL;
	}
	cur_data = data;

	path->status = CAIRO_STATUS_SUCCESS;
	path->num_data = num_data;
	path->data = data;

	while (svg_path != NULL && svg_path < svg_path_end) {
		switch (svg_path[0]) {
		case 'M':
			data_type = CAIRO_PATH_MOVE_TO;
			ADVANCE_TO_NEXT_TOKEN(svg_path, svg_path_end);
			break;
		case 'L':
			data_type = CAIRO_PATH_LINE_TO;
			ADVANCE_TO_NEXT_TOKEN(svg_path, svg_path_end);
			break;
		case 'Z':
			cur_data[0].header.type = CAIRO_PATH_CLOSE_PATH;
			cur_data[0].header.length = 1;
			cur_data++;
			ADVANCE_TO_NEXT_TOKEN(svg_path, svg_path_end);
			break;
		case '0':
		case '1':
		case '2':
		case '3':
		case '4':
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
		case '-':
			cur_data[0].header.type = data_type;
			cur_data[0].header.length = 2;
			cur_data[1].point.x = (strtod(svg_path, NULL) + meters_per_half_map) * pixels_per_meter - left;
			ADVANCE_TO_NEXT_TOKEN(svg_path, svg_path_end);
			cur_data[1].point.y = (strtod(svg_path, NULL) + meters_per_half_map) * pixels_per_meter - top;
			ADVANCE_TO_NEXT_TOKEN(svg_path, svg_path_end);
			cur_data += 2;
			break;
		default:
			ADVANCE_TO_NEXT_TOKEN(svg_path, svg_path_end);
		}
	}

	return path;
}

static PyObject *
speedups_svg_path_to_cairo_path(PyObject *self, PyObject *args)
{
	PyObject *pycairo_path;
	const char *svg_path;
	int svg_path_len;
	double meters_per_half_map;
	double pixels_per_meter;
	double left;
	double top;
	cairo_path_t *path;

	if (!PyArg_ParseTuple(args, "s#dddd",
				&svg_path, &svg_path_len,
				&meters_per_half_map, &pixels_per_meter,
				&left, &top))
	{
		return NULL;
	}

	path = svg_path_to_cairo_path_impl(
			svg_path, svg_path_len,
			meters_per_half_map, pixels_per_meter,
			left, top);
	if (path == NULL) return NULL;

	pycairo_path = PycairoPath_FromPath(path);

	return pycairo_path;
}

static PyObject *
speedups_argb256_to_unicode(PyObject *self, PyObject *args)
{
	PyObject *old_buffer_object;
	const void *full_buffer;
	int offset;
	Py_ssize_t buffer_length;
	const unsigned int *ints;
	const unsigned int *cur_int;
	const unsigned int *ints_end;
	unsigned short shorts[256];
	unsigned short *cur_short;
	PyObject *unicode;

	if (!PyArg_ParseTuple(args, "Oi", &old_buffer_object, &offset)) {
		return NULL;
	}

	if (-1 == PyObject_AsReadBuffer(old_buffer_object, &full_buffer, &buffer_length)) {
		return NULL;
	}

	if (offset + (sizeof(int) * 256) > buffer_length) {
		return PyErr_Format(PyExc_ValueError,
				"We've gone too far: buffer length is %zd and offset is %d"
				"so there isn't enough room for 256 integers",
				buffer_length, offset);
	}

	ints = (const unsigned int *) &((const char *)full_buffer)[offset];
	ints_end = &ints[256];

	for (cur_int = ints, cur_short = &shorts[0]; cur_int < ints_end; cur_int++, cur_short++) {
		cur_short[0] = (unsigned int) (cur_int[0] & 0xffff);
	}

	if (!(unicode = PyUnicode_DecodeUTF16((const char*) shorts, 256 * sizeof(unsigned short), NULL, NULL))) {
		return NULL;
	}

	return unicode;
}

static PyMethodDef SpeedupsMethods[] = {
	{ "svg_path_to_cairo_path", speedups_svg_path_to_cairo_path,
		METH_VARARGS, "Create a PycairoPath, given a string" },
	{ "argb256_to_unicode", speedups_argb256_to_unicode,
		METH_VARARGS, "Convert an ARGB256 buffer at given offset to 256-uchar unicode" },
	{ NULL, NULL, 0, NULL } /* Sentinel */
};

PyMODINIT_FUNC
initspeedups(void)
{
	Pycairo_IMPORT;
	Py_InitModule("speedups", SpeedupsMethods);
}
