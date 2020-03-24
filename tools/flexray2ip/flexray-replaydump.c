
/* Replays flexray dumps from the Host Mobility MX-4 T30 hardware */

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

#if __has_include (<linux/flexray.h>)
#include <linux/flexray.h>
#else
#include "flexray.h"
#endif

#define MAX_SID 65
#define MAX_CYCLE 65

#define PORT 51111
#define MAGIC 0x2018

struct flexray_cache {
    bool occupied;
    struct flexray_frame frame;
};

struct flexray_compressed_frame {
    uint16_t magic;
    uint32_t flags;
    uint8_t sid;
    uint8_t cycle;
    uint8_t data_size;
    uint8_t reserved;
    uint8_t data[0]; /* Beware! */
} __attribute__((__packed__));

int main(int argc, char **argv)
{
    struct flexray_cache *cache[MAX_SID][MAX_CYCLE];

    FILE *f = fopen(argv[1], "rb");

    if (f == NULL) {
            fprintf(stderr, "No such file %s.\n", argv[1]);
            return 1;

    }

    for (int sid = 0; sid < MAX_SID; sid++) {
        for (int cycle = 0; cycle < MAX_CYCLE; cycle++) {
            cache[sid][cycle] = malloc(sizeof(struct flexray_cache));
            cache[sid][cycle]->occupied = false;
        }
    }

    bool start = false;

    while (true) {
        struct flexray_frame frame;

        int n = fread(&frame, sizeof(frame), 1, f);
        if (n != 1) {
            fprintf(stderr, "Dump is too short to do a replay\n");
            return 1;
        }
        if (!start) {
            if (frame.frhead.rcc == 0) {
                start = true;
            } else {
                continue;
            }
        }

        if (cache[frame.frhead.fid][frame.frhead.rcc]->occupied) {
            break;
        }

        cache[frame.frhead.fid][frame.frhead.rcc]->occupied = true;

        memcpy(&cache[frame.frhead.fid][frame.frhead.rcc]->frame, &frame, sizeof(frame));

        printf("seq: %d timestamp: %llu flags: 0x%x fid: %d, plr: %d crc: 0x%x rcc: %d\n",
               frame.seq, frame.timestamp, frame.frhead.flags,frame.frhead.fid, frame.frhead.plr,
               frame.frhead.crc, frame.frhead.rcc);
    }
    fclose(f);

    struct sockaddr_in servaddr = {
        .sin_family = AF_INET,
        .sin_addr.s_addr = htonl(INADDR_ANY),
        .sin_port = htons(PORT),
    };

    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd == -1) {
        fprintf(stderr, "Failed to open socket: %s", strerror(errno));
        return 1;
    }

    int enable = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(int));

    if ((bind(fd, (struct sockaddr *)&servaddr, sizeof(servaddr))) != 0) {
        fprintf(stderr, "Failed to bind socket: %s", strerror(errno));
        return 1;
    }

    signal(SIGPIPE, SIG_IGN);

    while (true) {
        struct sockaddr_in cli = {0};

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
        bool connected = true;
        while (connected) {
            struct flexray_frame *frame;
            struct flexray_frame frame2;
            struct flexray_compressed_frame *comp_frame = (struct flexray_compressed_frame *)&frame2;

            for (int sid = 0; sid < MAX_SID; sid++) {
                for (int cycle = 0; cycle < MAX_CYCLE; cycle++) {
                    if (!cache[sid][cycle]->occupied) {
                        continue;
                    }

                    frame = &cache[sid][cycle]->frame;

                    comp_frame->magic = MAGIC;
                    comp_frame->flags = frame->frhead.flags;
                    comp_frame->cycle = frame->frhead.rcc;
                    comp_frame->sid = frame->frhead.fid;
                    comp_frame->data_size = frame->frhead.plr;
                    memcpy(comp_frame->data, frame->data, frame->frhead.plr);
                    int n = write(acceptfd, comp_frame, 
                                  sizeof(struct flexray_compressed_frame) + frame->frhead.plr);
                    if (n == -1) {
                        close(acceptfd);
                        connected = false;
                        break;
                    }
                }
                if (!connected) {
                    break;
                }
                /* Simulate the timing somewhat - one cycle takes 1 ms */
                usleep(1000);
            }
        }
    }

    return 0;
}
