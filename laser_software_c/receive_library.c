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
#include "receive_library.h"
// #include "send_library.h"

static char **decoded_packets;
static uint32_t num_packets;
static uint32_t len_final_packet;
static queue_t error_queue;

void initialize_decode (uint32_t num_packs, uint32_t len_final) {
    decoded_packets = calloc(num_packs, sizeof(char *));
    error_queue = queue_new();
    num_packets = num_packs;
    len_final_packet = len_final;
}


bool sixteen_eleven_hamming_decode (char *data, char *buffer, size_t start) {
    uint8_t *data_bits = malloc(16*sizeof(char));
    uint8_t parity_bit = 0;
    uint8_t one_bit = 0;
    uint8_t two_bit = 0;
    uint8_t four_bit = 0;
    uint8_t eight_bit = 0;
    uint8_t combined = 0;

    for (size_t i = 0; i < BITS_PER_HAM; i++) {
        data_bits[i] = get_ith_bit(&data[i > 7], i%8);
        parity_bit ^= data_bits[i];
        one_bit = (i & 1) ? one_bit ^ data_bits[i] : one_bit;
        two_bit = ((i >> 1) & 1) ? two_bit ^ data_bits[i] : two_bit;
        four_bit = ((i >> 2) & 1) ? four_bit ^ data_bits[i] : four_bit;
        eight_bit= ((i >> 3) & 1) ? eight_bit ^ data_bits[i] : eight_bit;
    }

    combined |= one_bit | (two_bit << 1) | (four_bit << 2) | (eight_bit << 3);

    if (combined && !parity_bit) {
        free(data_bits);
        return false;
    }
    

    data_bits[combined] ^= 1;
    size_t char_index = start;
    size_t buffer_index = 0;

    for (size_t j = 0; j < BITS_PER_HAM; j++) {
        if (j & (j - 1)) {
            set_ith_bit(&buffer[buffer_index], data_bits[j], char_index);
            if (char_index == 7) {
                char_index = 0;
                buffer_index++;
            } else {
                char_index++;
            }
        }
    }

    free(data_bits);
    return true;
}

// ham_data is 1024 byte subset of data that was hamming encoded
// buffer is 693 bytes and contains transmitted, decoded data
void decode_packet (char *ham_data) {
    char *buffer = malloc(BYTES_PER_PACKET*sizeof(char));
    size_t buffer_index = 0;
    size_t char_index = 0;
    uint32_t *ham_32 = (uint32_t *) ham_data;
    size_t tagID = ham_32[1];
    for (size_t i = 0; i < NUM_HAM; i++) {
        if (!sixteen_eleven_hamming_decode(&ham_data[2*i + 8], &buffer[buffer_index], char_index)) {
            enqueue(error_queue, tagID);
            free(buffer);
            return;
        }
        buffer_index += (char_index > 4) + 1;
        char_index = (char_index + 11) % 8;
    }
    decoded_packets[tagID] = buffer;
}

void decode_full (char *file) {
    size_t file_len = (num_packets - 1) * BYTES_PER_PACKET + len_final_packet;
    char *reconstructed_data = malloc(file_len * sizeof(char));
    size_t recon_ind = 0;
    for (size_t i = 0; i < num_packets; i++) {
        if (i == num_packets - 1) {
            memcpy(&reconstructed_data[recon_ind], decoded_packets[i], len_final_packet);
        } else {
            memcpy(&reconstructed_data[recon_ind], decoded_packets[i], BYTES_PER_PACKET);
        }
        recon_ind += BYTES_PER_PACKET;
    } 
    FILE *fptr = fopen(file, "wb");
    fwrite(reconstructed_data, sizeof(char), file_len, fptr);
    fclose(fptr);
    free(reconstructed_data);
}

char *get_packet_receiver(uint32_t tagID) {
    return decoded_packets[tagID];
}

size_t peek_error_queue () {
    return peek(error_queue);
}

void free_resources_receiver () {
    queue_free(error_queue);
    for (size_t i = 0; i < num_packets; i++) {
        if (decoded_packets[i] != NULL) {
            free(decoded_packets[i]);
        }
    }
    free(decoded_packets);
}