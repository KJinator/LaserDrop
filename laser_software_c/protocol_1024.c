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
static const uint32_t ERROR_REQ = 0x54535251;
static const uint32_t START_REC = 0xC4C3C2C1;

void print_fterror(FT_STATUS status) {
    switch(status) {
        case 0:
            printf("Error code: FT_OK\n");
            break;
        case 1:
            printf("Error code: FT_INVALID_HANDLE\n");
            break;
        case 2:
            printf("Error code: FT_DEVICE_NOT_FOUND\n");
            break;
        case 3:
            printf("Error code: FT_DEVICE_NOT_OPENED\n");
            break;
        case 4:
            printf("Error code: FT_IO_ERROR\n");
            break;
        case 5:
            printf("Error code: FT_INSUFFICIENT_RESOURCES\n");
            break;
        case 6:
            printf("Error code: FT_INVALID_PARAMETER\n");
            break;
        case 7:
            printf("Error code: FT_INVALID_BAUDRATE\n");
            break;
        case 8:
            printf("Error code: FT_DEVICE_NOT_OPENED_FOR_ERASE\n");
            break;
        case 9:
            printf("Error code: FT_DEVICE_NOT_OPENED_FOR_WRITE\n");
            break;
        case 10:
            printf("Error code: FT_FAILED_TO_WRITE_DEVICE_ID\n");
            break;
        case 11:
            printf("Error code: FT_EEPROM_READ_FAILED\n");
            break;
        case 12:
            printf("Error code: FT_EEPROM_WRITE_FAILED\n");
            break;
        case 13:
            printf("Error code: FT_EEPROM_ERASE_FAILED\n");
            break;
        case 14:
            printf("Error code: FT_EEPROM_NOT_PRESENT\n");
            break;
        case 15:
            printf("Error code: FT_EEPROM_NOT_PROGRAMMED\n");
            break;
        case 16:
            printf("Error code: FT_INVALID_ARGS\n");
            break;
        case 17:
            printf("Error code: FT_NOT_SUPPORTED\n");
            break;
        case 18:
            printf("Error code: FT_OTHER_ERROR\n");
            break;
    }
}

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

    memcpy(&buffer[8], file, sizeof(file));

    full_packet_encoding(buffer, &TxBuffer_start[8]);

    ftStatus = FT_OpenEx("LaserDrop White", FT_OPEN_BY_DESCRIPTION, &ftHandle);

    if(ftStatus != FT_OK) {
        printf("Open Error\n\n");
        print_fterror(ftStatus);
        free_resources_sender();
        return;
    }

    ftStatus = FT_SetBaudRate(ftHandle, 7000000);
    if(ftStatus != FT_OK) {
        printf("Baudrate Error\n\n");
        print_fterror(ftStatus);
        free_resources_sender();
        return;
    }

    FT_SetTimeouts(ftHandle,1000,1000);

    ftStatus = FT_Read(ftHandle, RxBuffer, sizeof(RxBuffer), &BytesRecieved);

    uint32_t help = 0;

    while (RxBuffer_int[0] != ACK) {
        RxBuffer_int[0] = 0;
        if (help == 0 || RxBuffer_int[0] != ACK) {
            ftStatus = FT_Write(ftHandle, TxBuffer_start, 1024, &BytesWritten);
            if (ftStatus != FT_OK) {
                printf("Write Error\n\n");
                print_fterror(ftStatus);
                ftStatus = FT_Close(ftHandle);
                if (ftStatus != FT_OK) {
                    printf("Close Error \n\n");
                    print_fterror(ftStatus);
                }
                free_resources_sender();
                return;
            }
        }

        help++;

        ftStatus = FT_Read(ftHandle, RxBuffer, 1024, &BytesRecieved);
        if (ftStatus != FT_OK) {
            printf("Read Error\n\n");
            print_fterror(ftStatus);
            ftStatus = FT_Close(ftHandle);
            if (ftStatus != FT_OK) {
                printf("Close Error \n\n");
                print_fterror(ftStatus);
            }
            free_resources_sender();
            return;
        }
    }

    RxBuffer_int[0] = 0;

    size_t num_packets = get_num_packets();
    TxBuffer[0] = 0xD1;
    TxBuffer[1] = 0xD2;
    TxBuffer[2] = 0xD3;
    TxBuffer[3] = 0xD4;

    for (uint32_t i = 0; i < num_packets; i++) {
        char *RawPacket = get_packet_sender(i);
        memcpy(TxBuffer, RawPacket, 1024);

        ftStatus = FT_Write(ftHandle, TxBuffer, 1024, &BytesWritten);

        if (ftStatus != FT_OK) {
            printf("Write Error\n\n");
            print_fterror(ftStatus);
            ftStatus = FT_Close(ftHandle);
            if (ftStatus != FT_OK) {
                printf("Close Error \n\n");
                print_fterror(ftStatus);
            }
            free_resources_sender();
            return;
        }

        if ((i != 0 && i % 128 == 127) ||  i == num_packets - 1) {
            do {
                ftStatus = FT_Read(ftHandle, RxBuffer, 1024, &BytesRecieved);
                if (ftStatus != FT_OK) {
                    printf("Read Error\n\n");
                    print_fterror(ftStatus);
                    ftStatus = FT_Close(ftHandle);
                    if (ftStatus != FT_OK) {
                        printf("Close Error \n\n");
                        print_fterror(ftStatus);
                    }
                    free_resources_sender();
                    return;
                }


                errorBuffer = decode_packet_no_queue(RxBuffer);

                if(RxBuffer_int[0] == ERROR_REQ && errorBuffer != NULL) {
                    uint32_t *errorBuffer_int = (uint32_t *) errorBuffer;
                    for (size_t i = 0; i < RxBuffer_int[1]; i++) {
                        append_error_queue(errorBuffer_int[i+2]);
                    }
                    free(errorBuffer);
                    TxBuffer[0] = 0xB1;
                    TxBuffer[1] = 0xB2;
                    TxBuffer[2] = 0xB3;
                    TxBuffer[3] = 0xB4;
                    ftStatus = FT_Write(ftHandle, TxBuffer, 1024, &BytesWritten);
                    if (ftStatus != FT_OK) {
                        printf("Read Error\n\n");
                        print_fterror(ftStatus);
                        ftStatus = FT_Close(ftHandle);
                        if (ftStatus != FT_OK) {
                            printf("Close Error \n\n");
                            print_fterror(ftStatus);
                        }
                        free_resources_sender();
                        return;
                    }
                }

                if(RxBuffer_int[0] == ERROR_REQ && errorBuffer == NULL) {
                    TxBuffer[0] = 0x51;
                    TxBuffer[1] = 0x52;
                    TxBuffer[2] = 0x53;
                    TxBuffer[3] = 0x54;
                    ftStatus = FT_Write(ftHandle, TxBuffer, 1024, &BytesWritten);
                    if (ftStatus != FT_OK) {
                        printf("Read Error\n\n");
                        print_fterror(ftStatus);
                        ftStatus = FT_Close(ftHandle);
                        if (ftStatus != FT_OK) {
                            printf("Close Error \n\n");
                            print_fterror(ftStatus);
                        }
                        free_resources_sender();
                        return;
                    }
                }

                if (RxBuffer_int[0] == DONE_REV && errorBuffer != NULL) {
                    free(errorBuffer);
                }
            } while ((RxBuffer_int[0] != DONE_REV && RxBuffer_int[0] != ERROR_REQ) || (RxBuffer_int[0] == ERROR_REQ && errorBuffer == NULL));
        }

    }

    uint32_t error_count = 0;

    while (get_error_queue_len() && RxBuffer_int[0] != DONE_REV) {
        if(RxBuffer_int[0] == DONE_REV)
        {
            break;
        }
        char *RawPacket1 = dequeue_error_queue();
        memcpy(TxBuffer, RawPacket1, 1024);

        ftStatus = FT_Write(ftHandle, TxBuffer, 1024, &BytesWritten);

        if (ftStatus != FT_OK) {
            printf("Write Error\n\n");
            print_fterror(ftStatus);
            ftStatus = FT_Close(ftHandle);
            if (ftStatus != FT_OK) {
                printf("Close Error \n\n");
                print_fterror(ftStatus);
            }
            free_resources_sender();
            return;
        }

        error_count++;

        if ((error_count != 0 && error_count % 128 == 0) || !get_error_queue_len()) {
            do {
                ftStatus = FT_Read(ftHandle, RxBuffer, 1024, &BytesRecieved);
                if (ftStatus != FT_OK) {
                    printf("Read Error\n\n");
                    print_fterror(ftStatus);
                    ftStatus = FT_Close(ftHandle);
                    if (ftStatus != FT_OK) {
                        printf("Close Error \n\n");
                        print_fterror(ftStatus);
                    }
                    free_resources_sender();
                    return;
                }


                errorBuffer = decode_packet_no_queue(RxBuffer);

                if(RxBuffer_int[0] == ERROR_REQ && errorBuffer != NULL) {
                    uint32_t *errorBuffer_int = (uint32_t *) errorBuffer;
                    for (size_t i = 0; i < RxBuffer_int[1]; i++) {
                        append_error_queue(errorBuffer_int[i+2]);
                    }
                    free(errorBuffer);
                    TxBuffer[0] = 0xB1;
                    TxBuffer[1] = 0xB2;
                    TxBuffer[2] = 0xB3;
                    TxBuffer[3] = 0xB4;
                    ftStatus = FT_Write(ftHandle, TxBuffer, 1024, &BytesWritten);
                    if (ftStatus != FT_OK) {
                        printf("Read Error\n\n");
                        print_fterror(ftStatus);
                        ftStatus = FT_Close(ftHandle);
                        if (ftStatus != FT_OK) {
                            printf("Close Error \n\n");
                            print_fterror(ftStatus);
                        }
                        free_resources_sender();
                        return;
                    }
                }

                if(RxBuffer_int[0] == ERROR_REQ && errorBuffer == NULL) {
                    TxBuffer[0] = 0x51;
                    TxBuffer[1] = 0x52;
                    TxBuffer[2] = 0x53;
                    TxBuffer[3] = 0x54;
                    ftStatus = FT_Write(ftHandle, TxBuffer, 1024, &BytesWritten);
                    if (ftStatus != FT_OK) {
                        printf("Read Error\n\n");
                        print_fterror(ftStatus);
                        ftStatus = FT_Close(ftHandle);
                        if (ftStatus != FT_OK) {
                            printf("Close Error \n\n");
                            print_fterror(ftStatus);
                        }
                        free_resources_sender();
                        return;
                    }
                }

                if (RxBuffer_int[0] == DONE_REV && errorBuffer != NULL) {
                    free(errorBuffer);
                }
            } while (BytesRecieved != 1024 || (RxBuffer_int[0] != DONE_REV && RxBuffer_int[0] != ERROR_REQ) || (RxBuffer_int[0] == ERROR_REQ && errorBuffer == NULL));
        }
    }

    free_resources_sender();

    ftStatus = FT_Close(ftHandle);
    if (ftStatus != FT_OK) {
        printf("Close Error \n\n");
        print_fterror(ftStatus);
    }
    printf("Transmission Complete\n");
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
    char *decoded;

    memset(buffer, 0, sizeof(buffer));
    memset(TxBuffer, 0, sizeof(TxBuffer));
    memset(RxBuffer, 0, sizeof(RxBuffer));

    ftStatus = FT_OpenEx("LaserDrop Black", FT_OPEN_BY_DESCRIPTION, &ftHandle);

    if(ftStatus != FT_OK) {
        printf("Open Error\n\n");
        print_fterror(ftStatus);
        return;
    }

    ftStatus = FT_SetBaudRate(ftHandle, 7000000);
    if(ftStatus != FT_OK) {
        printf("Baudrate Error\n\n");
        print_fterror(ftStatus);
        return;
    }

    FT_SetTimeouts(ftHandle,1000,1000);

    ftStatus = FT_Read(ftHandle, RxBuffer, sizeof(RxBuffer), &BytesRecieved);

    do {
        ftStatus = FT_Read(ftHandle, RxBuffer, 1024, &BytesRecieved);
        if (ftStatus != FT_OK) {
            printf("Read Error\n\n");
            print_fterror(ftStatus);
            ftStatus = FT_Close(ftHandle);
            if (ftStatus != FT_OK) {
                printf("Close Error \n\n");
                print_fterror(ftStatus);
            }
            free_resources_receiver();
            return;
        }
        decoded = decode_packet_no_queue(RxBuffer);
        if (RxBuffer_int[0] == START_REC) {
            if (decoded == NULL) {
                printf("Transmitted Error\n\n");
                TxBuffer_int[0] = ERROR_REQ;
                ftStatus = FT_Write(ftHandle, TxBuffer, 1024, &BytesWritten);
                if (ftStatus != FT_OK) {
                    printf("Write Error\n\n");
                    print_fterror(ftStatus);
                    ftStatus = FT_Close(ftHandle);
                    if (ftStatus != FT_OK) {
                        printf("Close Error \n\n");
                        print_fterror(ftStatus);
                    }
                    free_resources_receiver();
                    return;
                }
            }
        }

        if (RxBuffer_int[0] != START_REC && decoded != NULL) {
            free(decoded);
        }

        if (RxBuffer_int[0] != START_REC && BytesRecieved != 0) {
            TxBuffer_int[0] = ERROR_REQ;
            ftStatus = FT_Write(ftHandle, TxBuffer, 1024, &BytesWritten);
            if (ftStatus != FT_OK) {
                printf("Write Error\n\n");
                print_fterror(ftStatus);
                ftStatus = FT_Close(ftHandle);
                if (ftStatus != FT_OK) {
                    printf("Close Error \n\n");
                    print_fterror(ftStatus);
                }
                free_resources_receiver();
                return;
            }
        }
    } while (RxBuffer_int[0] != START_REC || (RxBuffer_int[0] == START_REC && decoded == NULL));

    printf("Start Received!!\n");

    clock_t begin = clock();

    TxBuffer_int[0] = ACK;

    ftStatus = FT_Write(ftHandle, TxBuffer, 1024, &BytesWritten);

    if (ftStatus != FT_OK) {
        printf("Write Error\n\n");
        print_fterror(ftStatus);
        ftStatus = FT_Close(ftHandle);
        if (ftStatus != FT_OK) {
            printf("Close Error \n\n");
            print_fterror(ftStatus);
        }
        free_resources_receiver();
        return;
    }

    memcpy(buffer, decoded, 693);
    free(decoded);
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
            print_fterror(ftStatus);
            ftStatus = FT_Close(ftHandle);
            if (ftStatus != FT_OK) {
                printf("Close Error \n\n");
                print_fterror(ftStatus);
            }
            free_resources_receiver();
            return;
        }

        if (BytesRecieved != 1024) {
            printf("Too few bytes received\n");
            enq_error_queue(count++);
            continue;
        }

        decode_packet(RxBuffer);

        count++;

        if (count % 128 == 0 || (count == num_packets && !all_sent) || ((get_num_errors_left() == get_num_errors()) && all_packets_were_sent())) {

            if (count == num_packets && !all_sent) {
                all_sent = true;
                count = 0;
            }

            if(finished()) {
                TxBuffer_int[0] = DONE_REV;
                ftStatus = FT_Write(ftHandle, TxBuffer, 1024, &BytesWritten);

                if (ftStatus != FT_OK) {
                    printf("Write Error\n\n");
                    print_fterror(ftStatus);
                    ftStatus = FT_Close(ftHandle);
                    if (ftStatus != FT_OK) {
                        printf("Close Error \n\n");
                        print_fterror(ftStatus);
                    }
                    free_resources_receiver();
                    return;
                }
            } else {
                TxBuffer_int[0] = ERROR_REQ;
                TxBuffer_int[1] = get_num_errors_left();
                uint32_t i = 2;

                for (; get_num_errors_left() > 0; decrement_num_errors_left()) {
                    buffer_int[i++] = deq_error_queue();
                }

                full_packet_encoding(buffer, &TxBuffer[8]);

                int help1 = 0;

                do {
                    if (help1 == 0 || RxBuffer_int[0] != ACK) {
                        ftStatus = FT_Write(ftHandle, TxBuffer, 1024, &BytesWritten);

                        if (ftStatus != FT_OK) {
                            printf("Write Error\n\n");
                            print_fterror(ftStatus);
                            ftStatus = FT_Close(ftHandle);
                            if (ftStatus != FT_OK) {
                                printf("Close Error \n\n");
                                print_fterror(ftStatus);
                            }
                            free_resources_receiver();
                            return;
                        }
                    }

                    help1++;

                    ftStatus = FT_Read(ftHandle, RxBuffer, 1024, &BytesWritten);

                    if (ftStatus != FT_OK) {
                        printf("Read Error\n\n");
                        print_fterror(ftStatus);
                        ftStatus = FT_Close(ftHandle);
                        if (ftStatus != FT_OK) {
                            printf("Close Error \n\n");
                            print_fterror(ftStatus);
                        }
                        free_resources_receiver();
                        return;
                    }
                } while (RxBuffer_int[0] != ACK);
            }
        }
    }

    clock_t end = clock();
    double time_spent = (double)(end - begin) / CLOCKS_PER_SEC * 2.0;
    printf("Receiving Complete\n");
    printf("Transmission time: %f seconds\n", time_spent);
    printf("Effective transmission speed: %lf Mbps\n", (((double)num_packets) * 8.0 * 693.0) / (time_spent * 1000000.0));

    decode_full(file);

    free_resources_receiver ();

    ftStatus = FT_Close(ftHandle);
    if (ftStatus != FT_OK) {
        printf("Close Error \n\n");
        print_fterror(ftStatus);
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

    free_resources_receiver();

    return 0;
}