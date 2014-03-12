# Makefile for WriteOff.pm

C_COMP = gcc

all: bin/libsqlitefunctions.so

bin/libsqlitefunctions.so : lib/extension-functions.c
	$(C_COMP) -fPIC -shared lib/extension-functions.c -o bin/libsqlitefunctions.so -lm

clean:
	rm bin/libsqlitefunctions.so
