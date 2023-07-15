.PHONY: all clean

LYS_TTF=1

PROG_FUT_DEPS:=$(shell find fut -name \*.fut; find lib -name \*.fut)
SELF_DIR=lib/github.com/diku-dk/lys
LYS_FRONTEND=sdl
FRONTEND_DIR = $(SELF_DIR)/$(LYS_FRONTEND)

all: stupidart

ifeq ($(shell test futhark.pkg -nt lib; echo $$?),0)
stupidart:
	futhark pkg sync
	@make # The sync might have resulted in a new Makefile.
else
STUPIDART_NO_INTERACTIVE?=0
ifeq ($(STUPIDART_NO_INTERACTIVE),1)
LYS_SDL=0
FUT_SOURCE=fut/stupidart_noninteractive.fut
else
FUT_SOURCE=fut/stupidart_lys.fut
endif
ifeq ($(STUPIDART_NO_FREEIMAGE),1)
CFLAGS_STUPIDART=-DSTUPIDART_NO_FREEIMAGE
LDFLAGS_STUPIDART=
else
CFLAGS_STUPIDART=
LDFLAGS_STUPIDART=-lfreeimage
endif
include $(SELF_DIR)/setup_flags.mk
ifeq ($(STUPIDART_NO_INTERACTIVE),1)
CFLAGS_NO_INTERACTIVE=$(NOWARN_CFLAGS) -Wall -Wextra -pedantic -DLYS_BACKEND_$(LYS_BACKEND) -DSTUPIDART_NO_INTERACTIVE
LDFLAGS_NO_INTERACTIVE=-lm $(DEVICE_LDFLAGS)
stupidart: stupidart_wrapper.o stupidart_printf.h font_data.h $(FRONTEND_DIR)/liblys.h $(SELF_DIR)/shared.c $(SELF_DIR)/shared.h c/stupidart.c c/pam.h c/freeimage_stupidart.h
	gcc $(SELF_DIR)/shared.c c/stupidart.c -I. -I$(SELF_DIR) -DPROGHEADER='"stupidart_wrapper.h"' -DPRINTFHEADER='"stupidart_printf.h"' stupidart_wrapper.o -o $@ $(CFLAGS_NO_INTERACTIVE) $(LDFLAGS_NO_INTERACTIVE) $(LDFLAGS_STUPIDART) $(CFLAGS_STUPIDART)
RT)
else
stupidart: stupidart_wrapper.o stupidart_printf.h font_data.h $(FRONTEND_DIR)/liblys.c $(FRONTEND_DIR)/liblys.h $(SELF_DIR)/shared.c $(SELF_DIR)/shared.h c/stupidart.c c/pam.h c/freeimage_stupidart.h
	gcc $(FRONTEND_DIR)/liblys.c $(SELF_DIR)/shared.c c/stupidart.c -I. -I$(SELF_DIR) -DPROGHEADER='"stupidart_wrapper.h"' -DPRINTFHEADER='"stupidart_printf.h"' stupidart_wrapper.o -o $@ $(CFLAGS) $(LDFLAGS) $(LDFLAGS_STUPIDART) $(CFLAGS_STUPIDART)
endif

stupidart_printf.h: stupidart_wrapper.c
	python3 $(SELF_DIR)/gen_printf.py $(FRONTEND_DIR) $@ $<

font_data.h: $(SELF_DIR)/Inconsolata-Regular.ttf
	echo 'unsigned char font_data[] = {' > $@
	xxd -i - < $< >> $@
	echo '};' >> $@

# We do not want warnings and such for the generated code.
stupidart_wrapper.o: stupidart_wrapper.c
	gcc -o $@ -c $< $(NOWARN_CFLAGS)

stupidart_wrapper.c: $(PROG_FUT_DEPS)
	futhark $(LYS_BACKEND) -o stupidart_wrapper --library $(FUT_SOURCE)
endif

clean:
	rm -f stupidart stupidart_wrapper.o stupidart_wrapper.c stupidart_wrapper.h
