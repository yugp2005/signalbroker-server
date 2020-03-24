/*
 * Flexray to TCP/IP on Host Mobility MX-4 T30 hardware
 *
 */

#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdbool.h>
#include <signal.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <linux/if.h>

#if __has_include (<linux/flexray.h>)
#include <linux/flexray.h>
#else
#include "flexray.h"
#endif

#define PORT 51111

#ifndef PF_FLEXRAY
#define PF_FLEXRAY 40 /* See: https://github.com/hostmobility/linux-toradex/blob/7a52340eaf7b037460a146b49eede4fa9d090fd6/include/linux/socket.h#L198 */
#endif

static int flexray_connect(void)
{
    int fd = socket(PF_FLEXRAY, SOCK_RAW, 1);

    if (fd == -1) {
        fprintf(stderr, "Failed to open flexray socket: %s", strerror(errno));
        return -1;
    }

    struct ifreq ifr;
    strcpy(ifr.ifr_name, "vflexray0");
    ioctl(fd, SIOCGIFINDEX, &ifr);

    struct sockaddr_flexray s = {
       .flexray_family = PF_FLEXRAY,
       .flexray_ifindex = ifr.ifr_ifindex
    };

    int err = bind(fd, (struct sockaddr*)&s, sizeof(s));

    if (err == -1) {
        fprintf(stderr, "Failed to bind flexray socket: %s", strerror(errno));
        close(fd);
        return -1;
    }
    return fd;
}

#define MAX_SID 300
#define MAX_CYCLE 65

struct flexray_cache {
    bool is_clear;
    struct flexray_frame frame;
};

#define MAGIC 0x2018

struct flexray_compressed_frame {
    uint16_t magic;
    uint32_t flags;    /* Copied from the flexray stuct */
    uint8_t sid;       /* slot id */
    uint8_t cycle;
    uint8_t data_size; /* Size of data, _excluding_ header */
    uint8_t reserved;
    uint8_t data[0];   /* Beware! */
} __attribute__((__packed__));


int main(int argc, char **argv)
{
    struct flexray_cache *cache[MAX_SID][MAX_CYCLE];

    struct sockaddr_in servaddr = {
        .sin_family = AF_INET,
        .sin_addr.s_addr = htonl(INADDR_ANY),
        .sin_port = htons(PORT),
    };
    struct sockaddr_in cli = {0};

    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd == -1) {
        fprintf(stderr, "Failed to open socket: %s", strerror(errno));
        return -1;
    }

    if ((bind(fd, (struct sockaddr *)&servaddr, sizeof(servaddr))) != 0) {
        fprintf(stderr, "Failed to bind socket: %s", strerror(errno));
        return -1;
    }

    int fr = flexray_connect();

    signal(SIGPIPE, SIG_IGN);


    for (int sid = 0; sid < MAX_SID; sid++) {
        for (int cycle = 0; cycle < MAX_CYCLE; cycle++) {
            cache[sid][cycle] = malloc(sizeof(struct flexray_cache));
            cache[sid][cycle]->is_clear = true;
        }
    }


    while (true) {
        if ((listen(fd, 5)) != 0) {
            fprintf(stderr, "Failed to listen on socket: %s", strerror(errno));
            return -1;
        }

        unsigned int len = sizeof(cli);
        int acceptfd = accept(fd, (struct sockaddr *)&cli, &len);
        if (acceptfd < 0) {
            fprintf(stderr, "Failed to accept on socket: %s", strerror(errno));
            return -1;
        }

        while (true) {
            struct flexray_frame frame, frame2;
            struct flexray_compressed_frame *comp_frame = (struct flexray_compressed_frame *)&frame2;

            int n = read(fr, &frame, sizeof(frame));
            if (n != sizeof(frame)) {
                fprintf(stderr, "Got partial frame - %d bytes. Dropping it\n", n);
                continue;
            }


            if (frame.frhead.fid < MAX_SID && frame.frhead.rcc < MAX_CYCLE) {

                if (!cache[frame.frhead.fid][frame.frhead.rcc]->is_clear &&
                    memcmp(frame.data, cache[frame.frhead.fid][frame.frhead.rcc]->frame.data, frame.frhead.plr) == 0) {
#ifdef DEBUG
                    printf("Cache hit: %d %d\n", frame.frhead.fid, frame.frhead.rcc);
#endif
                    continue;
                }

#ifdef DEBUG
                printf("Sending sid: %d cycle: %d - %d bytes%s - ",
                       frame.frhead.fid, frame.frhead.rcc, frame.frhead.plr,
                       cache[frame.frhead.fid][frame.frhead.rcc]->is_clear ? "Initial packet": "");

                for (int i = 0; i < frame.frhead.plr; i++) {
                    printf("%02x ", frame.data[i]);
                }
                printf("\n");
#endif

                cache[frame.frhead.fid][frame.frhead.rcc]->is_clear = false;
                memcpy(&cache[frame.frhead.fid][frame.frhead.rcc]->frame, &frame, sizeof(struct flexray_frame));
            }

            comp_frame->magic = MAGIC;
            comp_frame->flags = frame.frhead.flags;
            comp_frame->cycle = frame.frhead.rcc;
            comp_frame->sid = frame.frhead.fid;
            comp_frame->data_size = frame.frhead.plr;
            memcpy(comp_frame->data, frame.data, frame.frhead.plr);

            n = write(acceptfd, comp_frame, sizeof(struct flexray_compressed_frame) + frame.frhead.plr);
            if (n == -1) {
                close(acceptfd);
                break;
            }
        }
        for (int sid = 0; sid < MAX_SID; sid++) {
            for (int cycle = 0; cycle < MAX_CYCLE; cycle++) {
                cache[sid][cycle]->is_clear = true;
            }
        }
    }
    return 0;
}
