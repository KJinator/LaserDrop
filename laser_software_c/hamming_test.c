#include <stdlib.h>
#include <stdio.h>
#include "send_library.h"


int main(int argc, char *argv[]) {

    char *file = "hamming_test.c";
    encode_file(file);
    printf("Number of Packets = %d, Length of Final Packet = %d\n\n", get_num_packets(), get_len_final_packet());
    char *packet0 = get_packet(2);
    uint32_t *packet0_32 = (uint32_t *) packet0;

    printf("%x %x\n\n", packet0_32[0], packet0_32[1]);

    char *test_raw = calloc(693, sizeof(char));
    // test_raw[0] = 0x80;
    test_raw[1] = 0x10;
    test_raw[2] = 0x03;
    test_raw[3] = 0x95;
    test_raw[4] = 0xF2;
    test_raw[5] = 0xB0;
    test_raw[691] = 0x2;
    test_raw[692] = 0x2F;

    char *test_buffer = malloc(1008*sizeof(char));

    char test [2];
    char ham [2];
    ham[0] = 0;
    ham[1] = 0;

    test[0] = (char) 51;
    test[1] = (char) 192;

    printf("%d%d%d%d%d%d%d%d\n", get_ith_bit(test, 0), get_ith_bit(test, 1), get_ith_bit(test, 2), get_ith_bit(test, 3), get_ith_bit(test, 4), get_ith_bit(test, 5), get_ith_bit(test, 6), get_ith_bit(test, 7));

    printf("%d%d%d%d%d%d%d%d\n\n", get_ith_bit(&test[1], 0), get_ith_bit(&test[1], 1), get_ith_bit(&test[1], 2), get_ith_bit(&test[1], 3), get_ith_bit(&test[1], 4), get_ith_bit(&test[1], 5), get_ith_bit(&test[1], 6), get_ith_bit(&test[1], 7));

    set_ith_bit(test, 0, 0);
    set_ith_bit(&test[1], 1, 0);

    printf("%d%d%d%d%d%d%d%d\n", get_ith_bit(test, 0), get_ith_bit(test, 1), get_ith_bit(test, 2), get_ith_bit(test, 3), get_ith_bit(test, 4), get_ith_bit(test, 5), get_ith_bit(test, 6), get_ith_bit(test, 7));

    printf("%d%d%d%d%d%d%d%d\n\n", get_ith_bit(&test[1], 0), get_ith_bit(&test[1], 1), get_ith_bit(&test[1], 2), get_ith_bit(&test[1], 3), get_ith_bit(&test[1], 4), get_ith_bit(&test[1], 5), get_ith_bit(&test[1], 6), get_ith_bit(&test[1], 7));

    sixteen_eleven_hamming(test, ham);

    printf("%d %d\n\n", ham[0], ham[1]);

    full_packet_encoding(test_raw, test_buffer);

    printf("(%hhu %hhu) (%hhu %hhu) (%hhu %hhu) (%hhu %hhu) (%hhu %hhu)\n\n", test_buffer[0], test_buffer[1], test_buffer[2], test_buffer[3], 
                                                test_buffer[4], test_buffer[5], test_buffer[6], test_buffer[7], test_buffer[1006], test_buffer[1007]);

    free(test_raw);
    free(test_buffer);
    free_resources();

    return 0;
}