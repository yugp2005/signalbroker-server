
#include <stdio.h>
#include <stdbool.h>

#include "flexray.h"

int main(int argc, char **argv)
{

    FILE *f = fopen(argv[1], "rb");

    if (f == NULL) {
            fprintf(stderr, "No such file %s.\n", argv[1]);
            return 1;

    }

    while (true) {
            struct flexray_frame frame;

            int n = fread(&frame, sizeof(frame), 1, f);
            if (n != 1) {
                    break;
            }

            printf("seq: %d timestamp: %llu flags: 0x%x fid: %d, plr: %d crc: 0x%x rcc: %d rawdata: ",
                   frame.seq, frame.timestamp, frame.frhead.flags,frame.frhead.fid, frame.frhead.plr,
                   frame.frhead.crc, frame.frhead.rcc);
            for (int i = 0; i < frame.frhead.plr; i++) {
                    printf("%02x ", frame.data[i]);
            }
            printf("\n");

    }
    fclose(f);
    return 0;
}
