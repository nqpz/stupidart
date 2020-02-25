.PHONY: all clean

LYS_TTF=1

all: stupidart

ifeq ($(shell test futhark.pkg -nt lib; echo $$?),0)
stupidart:
	futhark pkg sync
	@make # The sync might have resulted in a new Makefile.
else
include lib/github.com/diku-dk/lys/setup_flags.mk
stupidart: libstupidart.o lib/github.com/diku-dk/lys/liblys.c lib/github.com/diku-dk/lys/liblys.h stupidart.c pam.h
	gcc lib/github.com/diku-dk/lys/liblys.c stupidart.c -I. -DPROGHEADER='"libstupidart.h"' libstupidart.o -o $@ $(CFLAGS) $(LDFLAGS)
endif

# We do not want warnings and such for the generated code.
libstupidart.o: libstupidart.c
	gcc -o $@ -c $< $(NOWARN_CFLAGS)

libstupidart.c: stupidart.fut $(PROG_FUT_DEPS) shapes/triangle.fut shapes/rectangle.fut shapes/circle.fut
	futhark $(LYS_BACKEND) -o libstupidart --library stupidart.fut

clean:
	rm -f stupidart libstupidart.o libstupidart.c libstupidart.h
