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
    char RxBuffer[1024];
    char RxBuffer2[128*1024];

    memset(TxBuffer1, 0, sizeof(TxBuffer1));
    memset(TxBuffer2, 0, sizeof(TxBuffer2));
    memset(RxBuffer, 0, sizeof(RxBuffer));

    TxBuffer1[0] = 1;
    TxBuffer1[1] = 2;
    TxBuffer1[2] = 3;
    TxBuffer1[3] = 4;

    for (size_t i = 0; i < 20; i++) {
        TxBuffer2[i] = 2*i;
    }

    ftStatus = FT_SetVIDPID(dwVID, dwPID);
    
    if (ftStatus != FT_OK) {
        printf("Darn\n\n");
        return 0;
    }

    printf("Device VID = %x; Device PID = %x\n\n", dwVID, dwPID);
    
    // ftStatus = FT_OpenEx("USB <-> Serial Converter", FT_OPEN_BY_DESCRIPTION, &ftHandle);
    ftStatus = FT_OpenEx("FT7RTCZO", FT_OPEN_BY_SERIAL_NUMBER, &ftHandle);

    if(ftStatus != FT_OK) {
        printf("Open Error\n\n");
        return 0;
    }

    printf("Open!\n\n");

    FT_SetTimeouts(ftHandle,10000,0);
/*
    ftStatus = FT_Read(ftHandle, RxBuffer, 1024, &BytesRecieved);
    if (ftStatus != FT_OK) {
        printf("Write Error\n\n");
        ftStatus = FT_Close(ftHandle);
        if (ftStatus != FT_OK) {
            printf("Close Error \n\n");
        }
        return 0;
    }

    printf("BytesReceived (1) = %u\n\n", BytesRecieved);

    printf("Incomplete packet test: RxBuffer[512-516] = %x %x %x %x %x\n\n", RxBuffer[512], RxBuffer[513], RxBuffer[514], RxBuffer[515], RxBuffer[516]);

    ftStatus = FT_Read(ftHandle, RxBuffer, 1024, &BytesRecieved);
    if (ftStatus != FT_OK) {
        printf("Write Error\n\n");
        ftStatus = FT_Close(ftHandle);
        if (ftStatus != FT_OK) {
            printf("Close Error \n\n");
        }
        return 0;
    }
    printf("BytesReceived (2) = %u\n\n", BytesRecieved);

    printf("Incomplete packet test: RxBuffer[512-516] = %x %x %x %x %x\n\n", RxBuffer[512], RxBuffer[513], RxBuffer[514], RxBuffer[515], RxBuffer[516]);

    memset(RxBuffer, 0, sizeof(RxBuffer));
    sleep(2);

    ftStatus = FT_Read(ftHandle, RxBuffer, 1024, &BytesRecieved);
    if (ftStatus != FT_OK) {
        printf("Write Error\n\n");
        ftStatus = FT_Close(ftHandle);
        if (ftStatus != FT_OK) {
            printf("Close Error \n\n");
        }
        return 0;
    }
    printf("BytesReceived (3) = %u\n\n", BytesRecieved);

    printf("Undefined Behavior Test: RxBuffer[512-516] = %x %x %x %x %x\n\n", RxBuffer[512], RxBuffer[513], RxBuffer[514], RxBuffer[515], RxBuffer[516]);

    

    ftStatus = FT_Read(ftHandle, RxBuffer2, 1024, &BytesRecieved);
    if (ftStatus != FT_OK) {
        printf("Write Error\n\n");
        ftStatus = FT_Close(ftHandle);
        if (ftStatus != FT_OK) {
            printf("Close Error \n\n");
        }
        return 0;
    }

    printf("Incomplete packet test: RxBuffer[0-3, 1023] = %x %x %x %x %x\n\n", RxBuffer2[0], RxBuffer2[1], RxBuffer2[2], RxBuffer2[3], RxBuffer2[1023]);

    printf("BytesReceived (4) = %u\n\n", BytesRecieved);

    ftStatus = FT_Read(ftHandle, &RxBuffer2[1024], 1024, &BytesRecieved);
    if (ftStatus != FT_OK) {
        printf("Write Error\n\n");
        ftStatus = FT_Close(ftHandle);
        if (ftStatus != FT_OK) {
            printf("Close Error \n\n");
        }
        return 0;
    }

    printf("Incomplete packet test: RxBuffer[0-3, 1023] = %x %x %x %x %x\n\n", RxBuffer2[1024], RxBuffer2[1025], RxBuffer2[1026], RxBuffer2[1027], RxBuffer2[2047]);

    printf("BytesReceived (4) = %u\n\n", BytesRecieved);



    ftStatus = FT_Read(ftHandle, &RxBuffer2[2048], 1024, &BytesRecieved);
    if (ftStatus != FT_OK) {
        printf("Write Error\n\n");
        ftStatus = FT_Close(ftHandle);
        if (ftStatus != FT_OK) {
            printf("Close Error \n\n");
        }
        return 0;
    }

    printf("Incomplete packet test: RxBuffer[0-3, 1023] = %x %x %x %x %x\n\n", RxBuffer2[2048], RxBuffer2[2049], RxBuffer2[2050], RxBuffer2[2051], RxBuffer2[3071]);

    */
   
    ftStatus = FT_Read(ftHandle, RxBuffer2, 1024, &BytesRecieved);
    if (ftStatus != FT_OK) {
        printf("Read Error\n\n");
        ftStatus = FT_Close(ftHandle);
        if (ftStatus != FT_OK) {
            printf("Close Error \n\n");
        }
        return 0;
    }

    printf("Port Open\n\n");
    
    /*
    ftStatus = FT_Read(ftHandle, RxBuffer2, 128*1024, &BytesRecieved);
    if (ftStatus != FT_OK) {
        printf("Read Error\n\n");
        ftStatus = FT_Close(ftHandle);
        if (ftStatus != FT_OK) {
            printf("Close Error \n\n");
        }
        return 0;
    }
    */


    printf("Incomplete packet test: RxBuffer[0-3, 1023] = %x %x %x %x %x\n\n", RxBuffer2[0], RxBuffer2[1], RxBuffer2[2], RxBuffer2[3], RxBuffer2[1023]);
    // printf("Incomplete packet test: RxBuffer[0-3, 1023] = %x %x %x %x %x\n\n", RxBuffer2[1024], RxBuffer2[1025], RxBuffer2[1026], RxBuffer2[1027], RxBuffer2[2047]);
    // printf("Incomplete packet test: RxBuffer[0-3, 1023] = %x %x %x %x %x\n\n", RxBuffer2[2048], RxBuffer2[2049], RxBuffer2[2050], RxBuffer2[2051], RxBuffer2[3071]);

    // printf("Incomplete packet test: RxBuffer[0-3, 1023] = %x %x %x %x %x\n\n", RxBuffer2[1024*7], RxBuffer2[1024*7+1], RxBuffer2[2], RxBuffer2[3], RxBuffer2[1023]);


    // for (size_t x = 0; x < 128; x += 16) {
        // printf("Incomplete packet test: RxBuffer[%zu]] = %x %x %x %x\n\n", x, RxBuffer2[x*1024], RxBuffer2[x*1024 + 1], RxBuffer2[x*1024 + 2], RxBuffer2[ x*1024 + 3]);
    // }

    printf("BytesReceived (4) = %u\n\n", BytesRecieved);


    ftStatus = FT_Close(ftHandle);
    if (ftStatus != FT_OK) {
        printf("Close Error \n\n");
    }

    return 0;
}