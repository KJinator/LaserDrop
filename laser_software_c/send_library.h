#ifndef SEND_LIBRARY_H
#define SEND_LIBRARY_H
#include <stdlib.h>
#include <stdbool.h>
#include <stdio.h>
#include "queue.h"

#define PACKET_SIZE 1024
#define BYTES_PER_PACKET 693
#define NUM_HAM 504
#define DATA_BITS_PER_HAM 11
#define BITS_PER_HAM 16

uint8_t get_ith_bit (char *data, size_t i);

void set_ith_bit (char *data, uint8_t bit, size_t i);

void sixteen_eleven_hamming (char *data, char *buffer);

void full_packet_encoding (char *RAW, char *buffer);

void encode_file (char *file);

// void group_128 (size_t num, bool normal, uint32_t start, char *buffer);

char *get_packet_sender(uint32_t tagID);

uint32_t get_num_packets ();

uint32_t get_len_final_packet ();

void free_resources_sender ();

void init_error_queue ();

void append_error_queue (uint32_t tagID);

char *dequeue_error_queue ();

size_t get_error_queue_len ();

#endif