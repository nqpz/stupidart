.PHONY: all clean

LYS_TTF=1

STUPIDART_FUT_DEPS=$(shell ls *.fut; find fut -name \*.fut; find lib -name \*.fut)

all: stupidart

ifeq ($(shell test futhark.pkg -nt lib; echo $$?),0)
stupidart:
	futhark pkg sync
	@make # The sync might have resulted in a new Makefile.
else
STUPIDART_NO_INTERACTIVE?=0
ifeq ($(STUPIDART_NO_INTERACTIVE),1)
LYS_SDL=0
FUT_SOURCE=stupidart_noninteractive.fut
else
FUT_SOURCE=stupidart_lys.fut
endif
include lib/github.com/diku-dk/lys/setup_flags.mk
ifeq ($(STUPIDART_NO_INTERACTIVE),1)
CFLAGS_NO_INTERACTIVE=$(NOWARN_CFLAGS) -Wall -Wextra -pedantic -DLYS_BACKEND_$(LYS_BACKEND) -DSTUPIDART_NO_INTERACTIVE
LDFLAGS_NO_INTERACTIVE=-lm $(DEVICE_LDFLAGS)
stupidart: libstupidart.o lib/github.com/diku-dk/lys/context_setup.c lib/github.com/diku-dk/lys/context_setup.h c/stupidart.c c/pam.h
	gcc lib/github.com/diku-dk/lys/context_setup.c c/stupidart.c -I. -DPROGHEADER='"libstupidart.h"' libstupidart.o -o $@ $(CFLAGS_NO_INTERACTIVE) $(LDFLAGS_NO_INTERACTIVE)
else
stupidart: libstupidart.o lib/github.com/diku-dk/lys/liblys.c lib/github.com/diku-dk/lys/liblys.h lib/github.com/diku-dk/lys/context_setup.c lib/github.com/diku-dk/lys/context_setup.h c/stupidart.c c/pam.h
	gcc lib/github.com/diku-dk/lys/liblys.c lib/github.com/diku-dk/lys/context_setup.c c/stupidart.c -I. -DPROGHEADER='"libstupidart.h"' libstupidart.o -o $@ $(CFLAGS) $(LDFLAGS)
endif
endif

# We do not want warnings and such for the generated code.
libstupidart.o: libstupidart.c
	gcc -o $@ -c $< $(NOWARN_CFLAGS)

libstupidart.c: $(STUPIDART_FUT_DEPS)
	futhark $(LYS_BACKEND) -o libstupidart --library $(FUT_SOURCE)

clean:
	rm -f stupidart libstupidart.o libstupidart.c libstupidart.h
