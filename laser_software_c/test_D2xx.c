#include <stdlib.h>
#include <stdio.h>
#include "send_library.h"
#include "ftd2xx.h"
#include <time.h>
#include <string.h>

int main() {
    FT_HANDLE ftHandle;
    FT_STATUS ftStatus;
    // DWORD numDevs;
    DWORD dwVID, dwPID;
    DWORD BytesWritten, BytesRecieved;
    dwVID = 0x0403;
    dwPID = 0x6045;

    char TxBuffer1[512];
    char TxBuffer2[1024];
    char TxBuffer3[128*1024];
    char RxBuffer[1024];

    memset(TxBuffer1, 0, sizeof(TxBuffer1));
    memset(TxBuffer2, 0, sizeof(TxBuffer2));
    memset(RxBuffer, 0, sizeof(RxBuffer));

    TxBuffer1[0] = 0xC1;
    TxBuffer1[1] = 0xC2;
    TxBuffer1[2] = 0xC3;
    TxBuffer1[3] = 0xC4;
    TxBuffer1[511] = 0xA1;

    TxBuffer2[0] = 0xC1;
    TxBuffer2[1] = 0xC2;
    TxBuffer2[2] = 0xC3;
    TxBuffer2[3] = 0xC4;
    TxBuffer2[1023] = 0xB2;

    TxBuffer3[0] = 0xC1;
    TxBuffer3[1] = 0xC2;
    TxBuffer3[2] = 0xC3;
    TxBuffer3[3] = 0xC4;
    TxBuffer3[1023] = 0x37;
    TxBuffer3[1024] = 0xC1;
    TxBuffer3[1025] = 0xC2;
    TxBuffer3[1026] = 0xC3;
    TxBuffer3[1027] = 0xC4;
    TxBuffer3[2047] = 0x55;
    TxBuffer3[2048] = 0xC1;
    TxBuffer3[2049] = 0xC2;
    TxBuffer3[2050] = 0xC3;
    TxBuffer3[2051] = 0xC4;
    TxBuffer3[3071] = 0x7C;
    TxBuffer3[3072] = 0xC1;
    TxBuffer3[3073] = 0xC2;
    TxBuffer3[3074] = 0xC3;
    TxBuffer3[3075] = 0xC4;

    for (size_t x = 4; x < 128; x++) {
        for (size_t y = 0; y < 4; y++) {
            TxBuffer3[x*1024 + y] = (unsigned short) (0xC0 + y + 0x1);
        }
    }

    TxBuffer3[128*1024 - 1] = 0xD4;

    for (size_t i = 4; i < 20; i++) {
        TxBuffer2[i] = 2*i;
    }

    ftStatus = FT_SetVIDPID(dwVID, dwPID);
    
    if (ftStatus != FT_OK) {
        printf("Darn\n\n");
        return 0;
    }

    printf("Device VID = %x; Device PID = %x\n\n", dwVID, dwPID);
    
    // ftStatus = FT_OpenEx("USB <-> Serial Converter", FT_OPEN_BY_DESCRIPTION, &ftHandle);
    ftStatus = FT_OpenEx("FT7SF9VH", FT_OPEN_BY_SERIAL_NUMBER, &ftHandle);

    if(ftStatus != FT_OK) {
        printf("Open Error\n\n");
        return 0;
    }

    FT_SetTimeouts(ftHandle,10000,0);

    /*

    ftStatus = FT_Write(ftHandle, TxBuffer1, 512, &BytesWritten);
    if (ftStatus != FT_OK) {
        printf("Write Error\n\n");
        ftStatus = FT_Close(ftHandle);
        if (ftStatus != FT_OK) {
            printf("Close Error \n\n");
        }
        return 0;
    }

    printf("BytesWritten (1) = %u\n\n", BytesWritten);

    ftStatus = FT_Write(ftHandle, TxBuffer2, 1024, &BytesWritten);
    if (ftStatus != FT_OK) {
        printf("Write Error\n\n");
        ftStatus = FT_Close(ftHandle);
        if (ftStatus != FT_OK) {
            printf("Close Error \n\n");
        }
        return 0;
    }
    printf("BytesWritten (2) = %u\n\n", BytesWritten);

    // printf("Incomplete packet test: RxBuffer[512-516] = %d %d %d %d %d\n\n", RxBuffer[512], RxBuffer[513], RxBuffer[514], RxBuffer[515], RxBuffer[516]);

    memset(RxBuffer, 0, sizeof(RxBuffer));

    sleep(2);

    ftStatus = FT_Write(ftHandle, TxBuffer1, 512, &BytesWritten);
    if (ftStatus != FT_OK) {
        printf("Write Error\n\n");
        ftStatus = FT_Close(ftHandle);
        if (ftStatus != FT_OK) {
            printf("Close Error \n\n");
        }
        return 0;
    }
    printf("BytesWritten (3) = %u\n\n", BytesWritten);

    sleep(2);

    */

    ftStatus = FT_Write(ftHandle, TxBuffer3, 1024*128, &BytesWritten);
    if (ftStatus != FT_OK) {
        printf("Write Error\n\n");
        ftStatus = FT_Close(ftHandle);
        if (ftStatus != FT_OK) {
            printf("Close Error \n\n");
        }
        return 0;
    }
    printf("BytesWritten (4) = %u\n\n", BytesWritten);

    // printf("Undefined Behavior Test: RxBuffer[512-516] = %d %d %d %d %d\n\n", RxBuffer[512], RxBuffer[513], RxBuffer[514], RxBuffer[515], RxBuffer[516]);

    ftStatus = FT_Close(ftHandle);
    if (ftStatus != FT_OK) {
        printf("Close Error \n\n");
    }

    return 0;
}