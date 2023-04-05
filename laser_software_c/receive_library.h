#ifndef RECEIVE_LIBRARY_H
#define RECEIVE_LIBRARY_H
#include <stdlib.h>
#include <stdbool.h>
#include <stdio.h>
#include "send_library.h"
#include "queue.h"

void initialize_decode (uint32_t num_packs, uint32_t len_final);

bool sixteen_eleven_hamming_decode (char *data, char *buffer, size_t start);

void decode_packet (char *ham_data);

void decode_full (char *file);

char *get_packet_receiver (uint32_t tagID);

size_t peek_error_queue ();

void free_resources_receiver ();

#endif