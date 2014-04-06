# Makefile for WriteOff.pm

C_COMP = gcc
EF_DST = bin/libsqlitefunctions.so
EF_SRC = lib/extension-functions.c

all: $(EF_DST)

$(EF_DST) : $(EF_SRC)
	$(C_COMP) -fPIC -shared $(EF_SRC) -o $(EF_DST) -lm

clean:
	rm $(EF_DST)
