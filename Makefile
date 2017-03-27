CXX := g++
OPENMP_CFLAGS=-fopenmp
OPENMP_LDFLAGS=-fopenmp
CXXFLAGS=-O3 -std=c++11 -DNDEBUG -DS2_USE_EXACTFLOAT -fPIC $(OPENMP_CFLAGS)
LDFLAGS=-flto $(OPENMP_LDFLAGS)

S2SRC=s2latlng s2cellid s2regionintersection s2 s2edgeutil s2r2rect s1angle s2edgeindex base/int128 base/logging base/strtoint base/stringprintf util/hash/hash util/coding/coder util/coding/varint util/math/mathutil util/math/exactfloat/exactfloat s2regionunion s2polygon s2regioncoverer s2polyline s2polygonbuilder s2loop s2cell s2cellunion s2cap base/logging s1interval s2pointregion s2region s2latlngrect strings/split strings/stringprintf strings/strutil
S2OBJ := $(S2SRC:%=s2-geometry-library/geometry/%.o) qs2.o

LOCAL_INCLUDES=-I. -Is2-geometry-library/geometry/s2 -Is2-geometry-library/geometry
CXXFLAGS += $(LOCAL_INCLUDES)

ifeq ($(shell uname),Linux)
  LDFLAGS += -fPIC -shared -lcrypto
  PLATFORM=l
else ifeq ($(shell uname),Darwin)
  ifeq ($(USE_CLANG),1)
    NO_OPENMP=1
    CXX=clang++
  else
    CXX=g++-6 # from homebrew
  endif
  OPENSSL_PATH := /usr/local/Cellar/openssl/1.0.2k
  OPENSSL_INC=$(OPENSSL_PATH)/include
  OPENSSL_LIB=$(OPENSSL_PATH)/lib/libcrypto.a
  LDFLAGS += -bundle -undefined dynamic_lookup $(OPENSSL_LIB)
  CXXFLAGS += -I$(OPENSSL_INC)
  PLATFORM=m
endif

ifeq ($(NO_OPENMP),1)
  OPENMP_CFLAGS=
  OPENMP_LDFLAGS=
  CXXFLAGS += -DNO_OPENMP
  DESC=_no_openmp
endif

m32: BITNESS=32
m64: BITNESS=64
l32: BITNESS=32
l64: BITNESS=64

ifeq ($(BITNESS),32)
  CXXFLAGS += -m32
  LDFLAGS += -m32
endif
ifeq ($(BITNESS),64)
  CXXFLAGS += -m64
  LDFLAGS += -m64
endif

PLUGIN=qs2_$(PLATFORM)$(BITNESS)$(DESC).so

qs2.so: $(S2OBJ)
	$(CXX) $(LDFLAGS) -o $@ $^
	cp qs2.so $(PLUGIN)

m32: qs2.so
m64: qs2.so
l32: qs2.so
l64: qs2.so

clean:
	rm -f qs2.so $(S2OBJ)
