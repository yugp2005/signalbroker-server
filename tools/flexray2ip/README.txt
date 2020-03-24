Overview
--------

Simple FlexRay to TCP/IP on Host Mobility MX-4 T-30 converter that listens on port 51111.
Only supports one client. And you can only read.
There is an internal cache, which means that you will only get updated frames.

Internal
--------
It read frames (See struct flexray_frame in flexray.h) of 296 bytes from the
FlexRay socket. Since most of the time about 40-50 bytes are actually used,
each Flexray frame will be sent in another format:

struct flexray_compressed_frame {
    uint16_t magic;
    uint32_t flags;    /* Copied from the flexray stuct */
    uint8_t sid;       /* slot id */
    uint8_t cycle;
    uint8_t data_size; /* Size of data, _excluding_ header */
    uint8_t reserved;
    uint8_t data[0]; /* Beware! */
} __attribute__((__packed__));

Building
--------

You can typically build the Flexray agent in an environment with Gnu Make and GCC.
To be able to run the binary on the Host Mobility MX-4 you need to compile it for
the armv7 architecture. The easiest way to do that if you're inexperienced is to build
it on a Raspberry Pi with Raspbian.

In that case it's just a matter of running "make" in this directory.
