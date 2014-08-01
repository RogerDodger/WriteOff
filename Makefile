# Makefile for WriteOff.pm

C_COMP = gcc
EF_DST = bin/libsqlitefunctions.so
EF_SRC = lib/extension-functions.c

BCS_DST = bin/libsqlitebcsum.so
BCS_SRC = lib/bcsum.c

all: $(EF_DST) $(BCS_DST)

$(EF_DST) : $(EF_SRC)
	$(C_COMP) -fPIC -shared $(EF_SRC) -o $(EF_DST) -lm

$(BCS_DST) : $(BCS_SRC)
	$(C_COMP) -fPIC -shared $(BCS_SRC) -o $(BCS_DST) -lm

clean:
	rm $(EF_DST) $(BCS_DST)
