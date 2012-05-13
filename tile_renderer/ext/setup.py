from distutils.core import setup, Extension

module1 = Extension('speedups', sources=['speedups.c'],
        include_dirs=['/usr/include/cairo', '/usr/include/pycairo'],
        libraries=['cairo'])

setup(name='speedups', version='1.0', description='OpenCensus optimizations', ext_modules=[module1])
