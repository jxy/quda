CXX=mpicxx

CXXFLAGS=$CXXFLAGS -DQMP_COMMS -DMULTI_GPU -DHAVE_QIO
CXXFLAGS=$CXXFLAGS -I../qio/include -I../qmp/include

LDFLAGS=$LDFLAGS\
	-L../qio/lib\
	-lqio -llime\
	-L../qmp/lib\
	-lqmp\

LIBOFILES=$LIBOFILES\
	lib/communicator_qmp.o\
	lib/layout_hyper.o\
	lib/qio_field.o\

