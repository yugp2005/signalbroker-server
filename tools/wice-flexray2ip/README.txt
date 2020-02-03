Overview
--------

Simple FlexRay to TCP/IP on Wice MX-4 T-30 converter that listens on port 51111.
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

The gcc compiler on the Wice-Box is named: arm-angstrom-linux-gnueabi-gcc
and you have to "opkg update && opkg install gcc" to get it.
If that doesn't work you can download the required packages from:
http://www.hostmobility.org:8008/ipk2/armv7ahf-vfp-neon/

I'm not 100% sure of what packages that are really needed, but I installed:

binutils_2.23.1-r3_armv7ahf-vfp-neon.ipk
gcc-dbg_linaro-4.7-r2013.09_armv7ahf-vfp-neon.ipk
gcc-dev_linaro-4.7-r2013.09_armv7ahf-vfp-neon.ipk
gcc_linaro-4.7-r2013.09_armv7ahf-vfp-neon.ipk
libmpc2_0.8.2-r1_armv7ahf-vfp-neon.ipk
libmpfr4_3.1.1-r0_armv7ahf-vfp-neon.ipk

There is a precompiled binary checked in as well.

You need to tell the antique compiler on the wice-box to use C99 (-std=c99)
