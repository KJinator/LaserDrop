#include <stdlib.h>
#include <stdio.h>
#include "send_library.h"
#include "ftd2xx.h"
#include <time.h>

int main(int argc, char *argv[]) {
    FT_HANDLE ftHandle;
    FT_STATUS ftStatus;
    DWORD numDevs;
    DWORD dwVID, dwPID;
    DWORD BytesWritten, BytesRecieved;
    dwVID = 0x0403;
    dwPID = 0x6045;

    char TxBuffer[1024];
    char RxBuffer[1024];

    memset(TxBuffer, 0, sizeof(TxBuffer));

    /* TxBuffer[0] = 1;
    TxBuffer[1] = 2;
    TxBuffer[2] = 3;
    TxBuffer[3] = 4; */

    ftStatus = FT_SetVIDPID(dwVID, dwPID);
    
    if (ftStatus != FT_OK) {
        printf("Darn\n\n");
        return 0;
    }

    printf("Device VID = %x; Device PID = %x\n\n", dwVID, dwPID);
    
    ftStatus = FT_OpenEx("USB <-> Serial Converter", FT_OPEN_BY_DESCRIPTION, &ftHandle);

    if(ftStatus != FT_OK) {
        printf("Open Error\n\n");
        return 0;
    }

    FT_SetTimeouts(ftHandle,1000,0);

    ftStatus = FT_Read(ftHandle, RxBuffer, sizeof(RxBuffer), &BytesRecieved);

    if (ftStatus != FT_OK) {
        printf("Read Error\n\n");
        ftStatus = FT_Close(ftHandle);
        if (ftStatus != FT_OK) {
            printf("Close Error \n\n");
        }
    return 0;
        

        // printf("Bytes Read = %d, Bytes Written = %d\n\n", RxBuffer[0], TxBuffer[0]);
        printf("Bytes Read: %d%d%d%d, Bytes Written: %d%d%d%d\n\n", RxBuffer[0], RxBuffer[1], RxBuffer[2], RxBuffer[3], TxBuffer[0], TxBuffer[1], TxBuffer[2], TxBuffer[3]);
        // printf("Time = %lf\n\n", ((double)(time_end - time_start))/CLOCKS_PER_SEC);
        // printf("Time Write = %lf, Time Read = %lf\n\n", ((double)(time_write - time_start))/CLOCKS_PER_SEC, ((double)(time_end - time_write))/CLOCKS_PER_SEC);
    }

    ftStatus = FT_Close(ftHandle);
    if (ftStatus != FT_OK) {
        printf("Close Error \n\n");
    }


    return 0;
}