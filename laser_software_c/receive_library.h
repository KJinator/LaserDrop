#ifndef RECEIVE_LIBRARY_H
#define RECEIVE_LIBRARY_H
#include <stdlib.h>
#include <stdbool.h>
#include <stdio.h>
#include "send_library.h"
#include "queue.h"

void initialize_decode (uint32_t num_packs, uint32_t len_final);

bool sixteen_eleven_hamming_decode (char *data, char *buffer, size_t start);

bool no_decode (char *data, char *buffer, size_t start);

char *decode_packet (char *ham_data);

char *decode_packet2 (char *ham_data);

void no_decode_packet (char *ham_data);

void decode128 (char *data);

void decode_full (char *file);

char *get_packet_receiver (uint32_t tagID);

size_t peek_error_queue ();

void free_resources_receiver ();

uint32_t get_num_errors ();

uint32_t get_num_errors_left ();

void decrement_num_errors_left();

uint32_t get_num_packets_receiver ();

uint32_t get_len_final_packet_receiver ();

bool finished ();

bool all_packets_were_sent ();

uint32_t deq_error_queue ();

#endif