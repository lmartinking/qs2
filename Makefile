CXX=g++-6
CXXFLAGS=-O3 -std=c++11 -DNDEBUG -DS2_USE_EXACTFLOAT -fPIC -fopenmp
LDFLAGS=-flto -fopenmp

S2SRC=s2latlng s2cellid s2regionintersection s2 s2edgeutil s2r2rect s1angle s2edgeindex base/int128 base/logging base/strtoint base/stringprintf util/hash/hash util/coding/coder util/coding/varint util/math/mathutil util/math/exactfloat/exactfloat s2regionunion s2polygon s2regioncoverer s2polyline s2polygonbuilder s2loop s2cell s2cellunion s2cap base/logging s1interval s2pointregion s2region s2latlngrect strings/split strings/stringprintf strings/strutil
S2OBJ := $(S2SRC:%=s2-geometry-library/geometry/%.o)

LOCAL_INCLUDES=-I. -Is2-geometry-library/geometry/s2 -Is2-geometry-library/geometry
CXXFLAGS += $(LOCAL_INCLUDES)

ifeq ($(shell uname),Linux)
  LDFLAGS += -fPIC -shared -lcrypto
else ifeq ($(shell uname),Darwin)
  OPENSSL_PATH=/usr/local/Cellar/openssl/1.0.2k
  OPENSSL_INC=$(OPENSSL_PATH)/include
  OPENSSL_LIB=$(OPENSSL_PATH)/lib
  LDFLAGS += -bundle -undefined dynamic_lookup -L$(OPENSSL_LIB) -lcrypto
  CXXFLAGS += -I$(OPENSSL_INC)
endif

s2.so: $(S2OBJ) qs2.o
	$(CXX) $(LDFLAGS) -o $@ $^ -lcrypto
clean:
	rm -f s2.so $(S2OBJ)
