#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <stdbool.h>
#include "send_library.h"
#include "receive_library.h"
#include "ftd2xx.h"
#include <time.h>
#include <string.h>

static const uint32_t ACK = 0xB4B3B2B1;
static const uint32_t DONE = 0xA1A2A3A4;
static const uint32_t START = 0xC1C2C3C4;
static const uint32_t START_REC = 0xC4C3C2C1;

void sender_protocol () {
    FT_HANDLE ftHandle;
    FT_STATUS ftStatus;
    DWORD dwVID, dwPID;
    dwVID = 0x0403;
    dwPID = 0x6045;
    DWORD BytesWritten, BytesRecieved;
    char file [691];
    char buffer [693];
    char TxBuffer_start [1024];
    char RxBuffer[1024];
    char TxBuffer [1024*128];
    char *errorBuffer;
    // uint32_t tags [128];
    uint32_t *RxBuffer_int = (uint32_t *) RxBuffer;
    uint32_t *TxBuffer_int = (uint32_t *) TxBuffer;
    uint32_t *buffer_int = (uint32_t *) buffer;
    memset(buffer, 0, sizeof(buffer));
    memset(TxBuffer_start, 0, sizeof(TxBuffer_start));
    memset(RxBuffer, 0, sizeof(RxBuffer));

    memset(file, 0, sizeof(file));

    while (access(file, F_OK) != 0) {
        printf("Enter File Name: ");
        scanf("  %s", &file);
    }

    encode_file(file);

    for (size_t i = 1; i < 5; i++) {
        // TxBuffer_start[i-1] = 0x30 + i;
        TxBuffer_start[i-1] = 0xC0 + i;
    }

    buffer_int[0] = get_num_packets();
    buffer_int[1] = get_len_final_packet();
    memcpy(buffer, file, sizeof(file));

    memset(&TxBuffer_start[4], 0x00, 4);

    full_packet_encoding(buffer, &TxBuffer_start[8]);
    /*for(int i = 0; i < 1024; i++)
    {
        printf("%hhx, ", TxBuffer_start[i]);
    }
    printf("\n");*/

    ftStatus = FT_OpenEx("LaserDrop White", FT_OPEN_BY_DESCRIPTION, &ftHandle);

    if(ftStatus != FT_OK) {
        printf("Open Error\n\n");
        return;
    }

    ftStatus = FT_SetBaudRate(ftHandle, 3000000);
    if(ftStatus != FT_OK) {
        printf("Baudrate Error\n\n");
        return;
    }

    printf("Sender Open!!\n\n");

    FT_SetTimeouts(ftHandle,2000,0);

    // ftStatus = FT_Read(ftHandle, RxBuffer, sizeof(RxBuffer), &BytesRecieved);

    printf("Flush Success\n\n");

    while (RxBuffer_int[0] != ACK) {
        ftStatus = FT_Write(ftHandle, TxBuffer_start, sizeof(TxBuffer_start), &BytesWritten);
        if (ftStatus != FT_OK) {
            printf("Write Error\n\n");
            ftStatus = FT_Close(ftHandle);
            if (ftStatus != FT_OK) {
                printf("Close Error \n\n");
            }
            return;
        }

        printf("Start sent: %u, %x %x %x %x\n\n", BytesWritten, TxBuffer_start[0], TxBuffer_start[1], TxBuffer_start[2], TxBuffer_start[3]);

        ftStatus = FT_Read(ftHandle, RxBuffer, 1024, &BytesRecieved);
        if (ftStatus != FT_OK) {
            printf("Read Error\n\n");
            ftStatus = FT_Close(ftHandle);
            if (ftStatus != FT_OK) {
                printf("Close Error \n\n");
            }
            return;
        }
    }

    printf("Start Success\n\n");
    RxBuffer_int[0] = 0;

    size_t num_packets = get_num_packets();
    size_t num128 = (num_packets % 128 != 0) + (num_packets / 128);
    uint32_t start_count = 0;
    TxBuffer[0] = 0xD1;
    TxBuffer[1] = 0xD2;
    TxBuffer[2] = 0xD3;
    TxBuffer[3] = 0xD4;

    for (uint32_t i = 0; i < num_packets; i++) {
        printf("Sending Packet %u\n", i);

        char *RawPacket = get_packet_sender(i);
        memcpy(TxBuffer, RawPacket, 1024);
        TxBuffer[4] = i % 0xFF;
        TxBuffer[5] = (i >> 8) % 0xFF;
        TxBuffer[6] = (i >> 16) % 0xFF;
        TxBuffer[7] = (i >> 24) % 0xFF;

        ftStatus = FT_Write(ftHandle, TxBuffer, 1024, &BytesWritten);

        if (ftStatus != FT_OK) {
            printf("Write Error\n\n");
            ftStatus = FT_Close(ftHandle);
            if (ftStatus != FT_OK) {
                printf("Close Error \n\n");
            }
            return;
        }
        printf("Write Success: %u\n", BytesWritten);

        if (i % 128 == 0 || i == num_packets - 1) {
            printf("All packets sent\n\n");
            while (RxBuffer_int[0] != ACK) {
                ftStatus = FT_Read(ftHandle, RxBuffer, 1024, &BytesRecieved);
                if (ftStatus != FT_OK) {
                    printf("Read Error\n\n");
                    ftStatus = FT_Close(ftHandle);
                    if (ftStatus != FT_OK) {
                        printf("Close Error \n\n");
                    }
                    return;
                }
            }
            errorBuffer = decode_packet2(RxBuffer);
            uint32_t *errorBuffer_int = (uint32_t *) errorBuffer;
            for (size_t i = 0; i < RxBuffer_int[1]; i++) {
                append_error_queue(errorBuffer_int[i]);
            }
            free(errorBuffer);
        }

        sleep(1);
    }

    printf("ACK Received\n");

    size_t num128_error;
    uint32_t start_count_error;
    size_t total_send_error;

    while (get_error_queue_len() && RxBuffer_int[0] != DONE) {
        printf("Error Queue Emptying\n");
        num128_error = (get_error_queue_len() % 128 != 0) + (get_error_queue_len() / 128);
        uint32_t start_count_error = 0;

        if (num128_error != 0) {
            for (uint32_t i = 0; i < num128_error; i++) {
                total_send_error = ((num128_error == 1 && get_error_queue_len() % 128 == 0) || (i < num128_error - 1)) ? 128 : (get_error_queue_len() % 128);
                group_128(total_send_error, false, start_count_error, TxBuffer);
                ftStatus = FT_Write(ftHandle, TxBuffer, 1024*128, &BytesWritten);

                if (ftStatus != FT_OK) {
                    printf("Write Error\n\n");
                    ftStatus = FT_Close(ftHandle);
                    if (ftStatus != FT_OK) {
                        printf("Close Error \n\n");
                    }
                    return;
                }

                // read_state_sender(ftHandle);
            }
        } else {
            ftStatus = FT_Read(ftHandle, RxBuffer, 1024, &BytesRecieved);
            if (ftStatus != FT_OK) {
                printf("Read Error\n\n");
                ftStatus = FT_Close(ftHandle);
                if (ftStatus != FT_OK) {
                    printf("Close Error \n\n");
                }
                return;
            }
        }
    }

    free_resources_sender();
}

void receiver_protocol () {
    FT_HANDLE ftHandle;
    FT_STATUS ftStatus;
    DWORD BytesWritten, BytesRecieved;
    char file [691];
    char buffer [693];
    char TxBuffer_start [1024];
    char RxBuffer[1024*128];
    char TxBuffer [1024];
    // uint32_t tags [128];
    uint32_t *RxBuffer_int = (uint32_t *) RxBuffer;
    uint32_t *TxBuffer_int = (uint32_t *) TxBuffer;
    uint32_t *buffer_int = (uint32_t *) buffer;

    ftStatus = FT_OpenEx("LaserDrop Black", FT_OPEN_BY_DESCRIPTION, &ftHandle);

    if(ftStatus != FT_OK) {
        printf("Open Error\n\n");
        return;
    }

    ftStatus = FT_SetBaudRate(ftHandle, 3000000);
    if(ftStatus != FT_OK) {
        printf("Baudrate Error\n\n");
        return;
    }

    printf("Receiver Open!!\n\n");

    FT_SetTimeouts(ftHandle,200,0);

    // ftStatus = FT_Read(ftHandle, RxBuffer, sizeof(RxBuffer), &BytesRecieved);

    printf("Flush success!\n\n");

    do {
        ftStatus = FT_Read(ftHandle, RxBuffer, 1024, &BytesRecieved);
        if (ftStatus != FT_OK) {
            printf("Read Error\n\n");
            ftStatus = FT_Close(ftHandle);
            if (ftStatus != FT_OK) {
                printf("Close Error \n\n");
            }
            return;
        }
        printf("Start received? %u, %x %x\n\n", BytesRecieved, RxBuffer_int[0], START);
    } while (RxBuffer_int[0] != START_REC);

    printf("Start Received!!\n\n");

    TxBuffer_int[0] = ACK;

    ftStatus = FT_Write(ftHandle, TxBuffer, 1024, &BytesWritten);

    initialize_decode(buffer_int[0], buffer_int[1]);
    memcpy(buffer, decode_packet2(RxBuffer), 693);

    file[0] = 'A';
    memcpy(&file[1], &buffer[8], 690);

    size_t num_packets = get_num_packets_receiver();
    size_t num128 = (num_packets % 128 != 0) + (num_packets / 128);
    uint32_t start_count = 0;
    uint32_t count = 0;

    while (!finished() || get_num_errors_left() > 0) {
        // size_t total_send = ((num128 == 1 && num_packets % 128 == 0) || (i < num128 - 1)) ? 128 : (num_packets % 128);
        // group_128(total_send, true, start_count, TxBuffer);
        ftStatus = FT_Read(ftHandle, RxBuffer, 1024, &BytesRecieved);

        if (ftStatus != FT_OK) {
            printf("Read Error\n\n");
            ftStatus = FT_Close(ftHandle);
            if (ftStatus != FT_OK) {
                printf("Close Error \n\n");
            }
            return;
        }

        printf("Packet Read, BytesReceived = %u\n\n", BytesRecieved);

        if (BytesRecieved != 1024) {
            continue;
        }

        decode_packet(RxBuffer);
        TxBuffer_int[0] = ACK;

        ftStatus = FT_Write(ftHandle, TxBuffer, 1024, &BytesWritten);

        if (ftStatus != FT_OK) {
            printf("Write Error\n\n");
            ftStatus = FT_Close(ftHandle);
            if (ftStatus != FT_OK) {
                printf("Close Error \n\n");
            }
            return;
        }

        count++;

        if (count % 128 != 0 && count != num_packets) {
            continue;
        }

        // TxBuffer_int[1] = get_num_errors_left();
        size_t i = 0;

        for (; get_num_errors_left() > 0; decrement_num_errors_left()) {
            buffer_int[i++] = deq_error_queue();
        }

        full_packet_encoding(buffer, TxBuffer);

        ftStatus = FT_Write(ftHandle, TxBuffer, 1024, &BytesWritten);

        if (ftStatus != FT_OK) {
            printf("Write Error\n\n");
            ftStatus = FT_Close(ftHandle);
            if (ftStatus != FT_OK) {
                printf("Close Error \n\n");
            }
            return;
        }
        // read_state_sender(ftHandle);
    }

    decode_full(file);

    TxBuffer_int[0] = DONE;

    ftStatus = FT_Write(ftHandle, TxBuffer, 1024, &BytesWritten);

    if (ftStatus != FT_OK) {
        printf("Write Error\n\n");
        ftStatus = FT_Close(ftHandle);
        if (ftStatus != FT_OK) {
            printf("Close Error \n\n");
        }
        return;
    }
    free_resources_receiver ();
}

int main() {

    char send_or_receive = '\0';

    while (true) {
        while (send_or_receive != 'S' && send_or_receive != 'R') {
            printf("Sender (S) or Receiver (R)? [S/R]: ");
            scanf("  %c", &send_or_receive);
        }

        if (send_or_receive == 'S') {
            sender_protocol();
        } else {
            receiver_protocol();
        }
        send_or_receive = '\0';
    }

    return 0;
}