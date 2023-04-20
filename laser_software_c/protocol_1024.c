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
static const uint32_t DONE_REV = 0xA4A3A2A1;
static const uint32_t ERROR_REQ = 0xB4B3B2B1;
static const uint32_t START_REC = 0xC4C3C2C1;

void sender_protocol () {
    FT_HANDLE ftHandle;
    FT_STATUS ftStatus;
    DWORD dwVID, dwPID;
    dwVID = 0x0403;
    dwPID = 0x6045;
    DWORD BytesWritten, BytesRecieved;
    char file [685];
    char buffer [693];
    char TxBuffer_start [1024];
    char RxBuffer[1024];
    char TxBuffer [1024*128];
    char *errorBuffer;
    uint32_t *RxBuffer_int = (uint32_t *) RxBuffer;
    uint32_t *buffer_int = (uint32_t *) buffer;
    memset(buffer, 0, sizeof(buffer));
    memset(TxBuffer_start, 0, sizeof(TxBuffer_start));
    memset(RxBuffer, 0, sizeof(RxBuffer));
    memset(TxBuffer, 0, sizeof(RxBuffer));

    memset(file, 0, sizeof(file));

    init_error_queue ();

    while (access(file, F_OK) != 0) {
        printf("Enter File Name: ");
        scanf("  %s", &file);
    }

    encode_file(file);

    for (size_t i = 1; i < 5; i++) {
        TxBuffer_start[i-1] = 0xC0 + i;
    }

    buffer_int[0] = get_num_packets();
    buffer_int[1] = get_len_final_packet();
    /*char *filename_pointer = (char *)(&buffer_int[2]);
    strcpy(filename_pointer, file);*/

    memcpy(&buffer[8], file, sizeof(file));
    printf("%s\n\n", &buffer[8]);

    full_packet_encoding(buffer, &TxBuffer_start[8]);

    ftStatus = FT_OpenEx("LaserDrop White", FT_OPEN_BY_DESCRIPTION, &ftHandle);

    if(ftStatus != FT_OK) {
        printf("Open Error\n\n");
        return;
    }

    ftStatus = FT_SetBaudRate(ftHandle, 5000);
    if(ftStatus != FT_OK) {
        printf("Baudrate Error\n\n");
        return;
    }

    printf("Sender Open!!\n\n");

    FT_SetTimeouts(ftHandle,1000,1000);

    ftStatus = FT_Read(ftHandle, RxBuffer, sizeof(RxBuffer), &BytesRecieved);

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
    TxBuffer[0] = 0xD1;
    TxBuffer[1] = 0xD2;
    TxBuffer[2] = 0xD3;
    TxBuffer[3] = 0xD4;

    for (uint32_t i = 0; i < num_packets; i++) {
        printf("Sending Packet %u\n", i);

        char *RawPacket = get_packet_sender(i);
        memcpy(TxBuffer, RawPacket, 1024);

        /*if (i % 2 == 0) {
            TxBuffer[9] ^= 0x1;
        }
        else {
            TxBuffer[20] ^= 0x1;
            TxBuffer[21] ^= 0x2;
        }*/

        ftStatus = FT_Write(ftHandle, TxBuffer, 1024, &BytesWritten);

        if (ftStatus != FT_OK) {
            printf("Write Error\n\n");
            ftStatus = FT_Close(ftHandle);
            if (ftStatus != FT_OK) {
                printf("Close Error \n\n");
            }
            return;
        }

        if ((i != 0 && i % 128 == 127) ||  i == num_packets - 1) {
            RxBuffer_int[0] = 0;
            while (RxBuffer_int[0] != DONE_REV && RxBuffer_int[0] != ERROR_REQ) {
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
            if(RxBuffer_int[0] == ERROR_REQ)
            {
                errorBuffer = decode_packet_no_queue(RxBuffer);
                uint32_t *errorBuffer_int = (uint32_t *) errorBuffer;
                for (size_t i = 0; i < RxBuffer_int[1]; i++) {
                    append_error_queue(errorBuffer_int[i+2]);
                }
                free(errorBuffer);
            }
        }

    }

    printf("ACK Received\n");

    uint32_t error_count = 0;

    int kj = 0;

    while (get_error_queue_len() && RxBuffer_int[0] != DONE_REV) {
        if(RxBuffer_int[0] == DONE_REV)
        {
            break;
        }
        char *RawPacket1 = dequeue_error_queue();
        memcpy(TxBuffer, RawPacket1, 1024);
        /*if (kj < 5 && kj % 2 == 0) {
            TxBuffer[9] ^= 0x3;
        }
        kj++;*/

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

        error_count++;

        if ((error_count != 0 && error_count % 128 == 0) || !get_error_queue_len()) {
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
            } while (BytesRecieved != 1024 || (RxBuffer_int[0] != DONE_REV && RxBuffer_int[0] != ERROR_REQ));

            if(RxBuffer_int[0] == ERROR_REQ) {
                errorBuffer = decode_packet_no_queue(RxBuffer);
                uint32_t *errorBuffer_int = (uint32_t *) errorBuffer;
                for (size_t i = 2; i < RxBuffer_int[1] + 2; i++) {
                    append_error_queue(errorBuffer_int[i]);
                }
                free(errorBuffer);
            }
        }
    }

    free_resources_sender();

    ftStatus = FT_Close(ftHandle);
    if (ftStatus != FT_OK) {
        printf("Close Error \n\n");
    }
}

void receiver_protocol () {
    FT_HANDLE ftHandle;
    FT_STATUS ftStatus;
    DWORD BytesWritten, BytesRecieved;
    char file [690];
    char buffer [693];
    char RxBuffer[1024*128];
    char TxBuffer [1024];
    uint32_t *RxBuffer_int = (uint32_t *) RxBuffer;
    uint32_t *TxBuffer_int = (uint32_t *) TxBuffer;
    uint32_t *buffer_int = (uint32_t *) buffer;
    bool all_sent = false;

    memset(buffer, 0, sizeof(buffer));
    memset(TxBuffer, 0, sizeof(TxBuffer));
    memset(RxBuffer, 0, sizeof(RxBuffer));

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

    FT_SetTimeouts(ftHandle,1000,1000);

    ftStatus = FT_Read(ftHandle, RxBuffer, sizeof(RxBuffer), &BytesRecieved);

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
        printf("Start not received");
    } while (RxBuffer_int[0] != START_REC);

    printf("Start Received!!\n\n");

    TxBuffer_int[0] = ACK;

    ftStatus = FT_Write(ftHandle, TxBuffer, 1024, &BytesWritten);

    memcpy(buffer, decode_packet_no_queue(RxBuffer), 693);
    initialize_decode(buffer_int[0], buffer_int[1]);

    file[0] = 'c';
    file[1] = 'o';
    file[2] = 'p';
    file[3] = 'y';
    file[4] = '_';
    memcpy(&file[5], &buffer[8], 685);

    size_t num_packets = get_num_packets_receiver();

    uint32_t count = 0;

    while (!finished()) {
        ftStatus = FT_Read(ftHandle, RxBuffer, 1024, &BytesRecieved);

        if (ftStatus != FT_OK) {
            printf("Read Error\n\n");
            ftStatus = FT_Close(ftHandle);
            if (ftStatus != FT_OK) {
                printf("Close Error \n\n");
            }
            return;
        }

        if (BytesRecieved != 1024) {
            printf("Nothing received\n");
            continue;
        }
        else
        {
            printf("Packet %u Read, BytesReceived = %u\n", RxBuffer_int[1], BytesRecieved);
        }

        decode_packet(RxBuffer);

        count++;

        if (count % 128 == 0 || (count == num_packets && !all_sent) || ((get_num_errors_left() == get_num_errors()) && all_packets_were_sent())) {

            if (count == num_packets && !all_sent) {
                all_sent = true;
                count = 0;
            }

            if(finished())
            {
                printf("No Errors in Queue\n");
                TxBuffer_int[0] = DONE_REV;
                ftStatus = FT_Write(ftHandle, TxBuffer, 1024, &BytesWritten);

                if (ftStatus != FT_OK) {
                    printf("Write Error\n\n");
                    ftStatus = FT_Close(ftHandle);
                    if (ftStatus != FT_OK) {
                        printf("Close Error \n\n");
                    }
                    return;
                }
            } else {
                printf("Inside loop: get_num_errors_left() = %u\n\n", get_num_errors_left());
                TxBuffer_int[0] = ERROR_REQ;
                TxBuffer_int[1] = get_num_errors_left();
                uint32_t i = 2;

                for (; get_num_errors_left() > 0; decrement_num_errors_left()) {
                    buffer_int[i++] = deq_error_queue();
                }

                full_packet_encoding(buffer, &TxBuffer[8]);

                ftStatus = FT_Write(ftHandle, TxBuffer, 1024, &BytesWritten);

                if (ftStatus != FT_OK) {
                    printf("Write Error\n\n");
                    ftStatus = FT_Close(ftHandle);
                    if (ftStatus != FT_OK) {
                        printf("Close Error \n\n");
                    }
                    return;
                }
            }
        }
    }
    printf("Receiving Complete\n");

    decode_full(file);

    free_resources_receiver ();

    ftStatus = FT_Close(ftHandle);
    if (ftStatus != FT_OK) {
        printf("Close Error \n\n");
    }
}

int main() {

    char send_or_receive = '\0';

    while (send_or_receive != 'Q') {
        while (send_or_receive != 'S' && send_or_receive != 'R' && send_or_receive != 'Q') {
            printf("Sender (S) or Receiver (R) or Quit (Q)? [S/R/Q]: ");
            scanf("  %c", &send_or_receive);
        }

        if (send_or_receive == 'S') {
            sender_protocol();
            send_or_receive = '\0';
        } else if (send_or_receive == 'R') {
            receiver_protocol();
            send_or_receive = '\0';
        }
    }

    return 0;
}