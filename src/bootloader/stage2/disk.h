#pragma once

#include "stdint.h"

typedef struct {
    uint8_t id;
    uint16_t cylinders;
    uint16_t sectors;
    uint16_t heads;
} DISK;

bool DISK_Initialize(DISK* disk, uint8_t driveNumber);
void DISK_LBA2CHS(DISK* disk, uint32_t lba, uint16_t* cylinderOut, uint16_t* sectorOut, uint16_t* headOut);
bool DISK_ReadSectors(DISK* disk, uint32_t lba, uint8_t sectors, void far* dataOut);
