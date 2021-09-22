CXX=mpicxx

CXXFLAGS=$CXXFLAGS -DQMP_COMMS -DMULTI_GPU
CXXFLAGS=$CXXFLAGS -I../qio/include -I../qmp/include

LDFLAGS=$LDFLAGS\
	-L../qio/lib\
	-lqio -llime\
	-L../qmp/lib\
	-lqmp

LIBOFILES=lib/communicator_qmp.o
