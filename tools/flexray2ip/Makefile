CC=gcc
CFLAGS=-I. -std=c99 -D_DEFAULT_SOURCE
DEPS = flexray.h
.DEFAULT_GOAL := all

%.o: %.c $(DEPS)
	$(CC) -c -o $@ $< $(CFLAGS)

flexray2ip: flexray2ip.o
	$(CC) -o $@ $^ $(CFLAGS)

analyze-dump: analyze-dump.o
	$(CC) -o $@ $^ $(CFLAGS)

flexray-replaydump: flexray-replaydump.o
	$(CC) -o $@ $^ $(CFLAGS)

all: flexray2ip analyze-dump flexray-replaydump

clean:
	rm *.o flexray2ip analyze-dump flexray-replaydump
