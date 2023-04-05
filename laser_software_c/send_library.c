// 1024 byte packages:
//      - 4 byte start
//      - 4 byte tag
//      - 1008 bytes of Hamming coded data
//          - 693 bytes of actual data
//          - 315 bytes of hamming bits
//      - 8 bytes padding

#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <stddef.h>
#include <string.h>
#include <strings.h>
#include "send_library.h"

static uint32_t start_bytes = 0xC1C2C3C4;
static uint32_t len_final_packet;
uint32_t num_packets;
static char **packet_array;

// In 8 bit string, get ith bit
uint8_t get_ith_bit (char *data, size_t i) {
    return ((uint8_t) (*data >> (7 - i))) & 1;
}

void set_ith_bit (char *data, uint8_t bit, size_t i) {
    *data &= (uint8_t) ~((1 << (7 - i)));
    *data |= (uint8_t) ((bit << (7 - i)));
}

// Only first 11 bits of data are used
void sixteen_eleven_hamming (char *data, char *buffer) {
    // Only LSB will be used
    uint8_t parity_bit = 0;
    uint8_t one_bit = 0;
    uint8_t two_bit = 0;
    uint8_t four_bit = 0;
    uint8_t eight_bit = 0;

    uint8_t bit = 0;

    size_t index = 0;

    for (size_t i = 0; i < BITS_PER_HAM; i++) {
        // Not a parity bit
        if (i & (i - 1)) {
            bit = get_ith_bit(&data[index > 7], index % 8);
            set_ith_bit(&buffer[i > 7], bit, i % 8);
            parity_bit ^= bit;
            one_bit = (i & 1) ? one_bit ^ bit : one_bit;
            two_bit = ((i >> 1) & 1) ? two_bit ^ bit : two_bit;
            four_bit = ((i >> 2) & 1) ? four_bit ^ bit : four_bit;
            eight_bit= ((i >> 3) & 1) ? eight_bit ^ bit : eight_bit;

            index++;
        }
    }

    set_ith_bit(buffer, one_bit, 1);
    set_ith_bit(buffer, two_bit, 2);
    set_ith_bit(buffer, four_bit, 4);
    set_ith_bit(&buffer[1], eight_bit, 0);

    parity_bit ^= one_bit ^ two_bit ^ four_bit ^ eight_bit;

    set_ith_bit(buffer, parity_bit, 0);
}


// RAW is raw data (693 bytes)
// buffer is the 1008 byte subsection of the full 1024 buffer to be filled with hamming encoded data
void full_packet_encoding (char *RAW, char *buffer) {
    size_t RAW_index = 0; // character within the RAW data array
    size_t char_index = 0; // number bit within the character from the RAW data array
    size_t buffer_index = 0;

    char data [2];
    data[0] = 0;
    data[1] = 0;

    for (size_t i = 0; i < NUM_HAM; i++) {
        for (size_t j = 0; j < DATA_BITS_PER_HAM; j++) {
            set_ith_bit(&data[j > 7], get_ith_bit(&RAW[RAW_index], char_index), j%8);
            if (char_index == 7) {
                char_index = 0;
                RAW_index++;
            } else {
                char_index++;
            }
        }
        sixteen_eleven_hamming(data, &buffer[buffer_index]);
        buffer_index += 2;
    }
}

void encode_file (char *file) {
    char *RAW;
    char *buffer;
    size_t file_len;
    uint32_t tagID = 0;

    FILE *fptr = fopen(file, "rb");

    fseek(fptr, 0, SEEK_END);          // Jump to the end of the file
    file_len = ftell(fptr);             // Get the current byte offset in the file
    rewind(fptr);                      // Jump back to the beginning of the file


    RAW = malloc(file_len * sizeof(char)); // Enough memory for the file
    fread(RAW, file_len, 1, fptr); // Read in the entire file
    fclose(fptr); // Close the file

    len_final_packet = file_len % BYTES_PER_PACKET;
    num_packets = (len_final_packet != 0) + (file_len / BYTES_PER_PACKET);

    packet_array = malloc(num_packets * sizeof(char *));

    for (size_t i = 0; i < num_packets; i++) {
        buffer = calloc(PACKET_SIZE, sizeof(char));
        uint32_t *buffer_32 = (uint32_t *) buffer;
        buffer_32[0] = start_bytes;
        buffer_32[1] = tagID;
        if ((i == num_packets - 1) && len_final_packet != 0) {
            char *raw = calloc(BYTES_PER_PACKET, sizeof(char));
            memcpy(raw, &RAW[i * BYTES_PER_PACKET], len_final_packet);
            full_packet_encoding(raw, &buffer[8]);
            free(raw);
        } else {
            full_packet_encoding(&RAW[i * BYTES_PER_PACKET], &buffer[8]);
        }
        packet_array[tagID++] = buffer;
    }
    free(RAW);
}

char *get_packet_sender(uint32_t tagID) {
    return packet_array[tagID];
}

uint32_t get_num_packets () {
    return num_packets;
}

uint32_t get_len_final_packet () {
    return len_final_packet;
}

void free_resources_sender () {
    for (size_t i = 0; i < num_packets; i++) {
        free(packet_array[i]);
    }
    free(packet_array);
}