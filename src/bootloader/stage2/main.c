#include "stdint.h"
#include "stdio.h"
#include "disk.h"

void far* g_data = (void far*)0x00500200;

void _cdecl cstart_(uint16_t bootDrive)
{
    DISK disk;
    uint8_t driveNumber = 0;  // Assuming primary hard drive or floppy

    printf("Initializing disk...\n");
    if (!DISK_Initialize(&disk, driveNumber)) {
        printf("Failed to initialize disk %d\n", driveNumber);
        return;
    }

    printf("Disk initialized: Cylinders: %d, Heads: %d, Sectors: %d\n", disk.cylinders, disk.heads, disk.sectors);

    // Test LBA to CHS conversion
    uint32_t testLBA = 0;  // Example LBA sector
    uint16_t cylinder, sector, head;

    DISK_LBA2CHS(&disk, testLBA, &cylinder, &sector, &head);
    printf("LBA %d -> Cylinder: %d, Head: %d, Sector: %d\n", testLBA, cylinder, head, sector);

    // Test reading a sector
    uint8_t buffer[512];  // One sector buffer
    DISK_ReadSectors(&disk, 19, 1, *g_data);

    printf("%s\n", g_data);

    return;

}
