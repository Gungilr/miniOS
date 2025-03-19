#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef uint8_t bool;
#define true 1
#define false 0

typedef struct 
{
    uint8_t BootJumpInstruction[3];
    uint8_t OemIdentifier[8];
    uint16_t BytesPerSector;
    uint8_t SectorsPerCluster;
    uint16_t ReservedSectors;
    uint8_t FatCount;
    uint16_t DirEntryCount;
    uint16_t TotalSectors;
    uint8_t MediaDescriptorType;
    uint16_t SectorsPerFat;
    uint16_t SectorsPerTrack;
    uint16_t Heads;
    uint32_t HiddenSectors;
    uint32_t LargeSectorCount;

    // extended boot record
    uint8_t DriveNumber;
    uint8_t _Reserved;
    uint8_t Signature;
    uint32_t VolumeId;          // serial number, value doesn't matter
    uint8_t VolumeLabel[11];    // 11 bytes, padded with spaces
    uint8_t SystemId[8];

    // ... we don't care about code ...

} __attribute__((packed)) BootSector;

typedef struct 
{
    uint8_t Name[11];
    uint8_t Attributes;
    uint8_t _Reserved;
    uint8_t CreatedTimeTenths;
    uint16_t CreatedTime;
    uint16_t CreatedDate;
    uint16_t AccessedDate;
    uint16_t FirstClusterHigh;
    uint16_t ModifiedTime;
    uint16_t ModifiedDate;
    uint16_t FirstClusterLow;
    uint32_t Size;
} __attribute__((packed)) DirectoryEntry;

BootSector g_BootSector;
uint8_t* g_Fat = NULL;
DirectoryEntry* g_RootDirectory = NULL;
uint32_t g_RootDirectoryEnd;

bool readBootSector(FILE* disk)
{
    return fread(&g_BootSector, sizeof(g_BootSector), 1, disk) > 0;
}

bool readSectors(FILE* disk, uint32_t lba, uint32_t count, void* bufferOut)
{
    bool ok = true;
    ok = ok && (fseek(disk, lba * g_BootSector.BytesPerSector, SEEK_SET) == 0);
    ok = ok && (fread(bufferOut, g_BootSector.BytesPerSector, count, disk) == count);
    return ok;
}

bool readFAT(FILE* disk)
{
    g_Fat = (uint8_t*) malloc(g_BootSector.SectorsPerFat * g_BootSector.BytesPerSector);
    return readSectors(disk, g_BootSector.ReservedSectors, g_BootSector.SectorsPerFat, g_Fat);
}

bool readRootDirectory(FILE* disk)
{
    uint32_t lba = g_BootSector.ReservedSectors + g_BootSector.SectorsPerFat * g_BootSector.FatCount;
    uint32_t size = sizeof(DirectoryEntry) * g_BootSector.DirEntryCount;
    uint32_t sectors = (size / g_BootSector.BytesPerSector);
    if (size % g_BootSector.BytesPerSector > 0)
        sectors++;

    g_RootDirectoryEnd = lba + sectors;
    g_RootDirectory = (DirectoryEntry*) malloc(sectors * g_BootSector.BytesPerSector);
    return readSectors(disk, lba, sectors, g_RootDirectory);
}


DirectoryEntry* findFile(const char* name)
{
    for (uint32_t i = 0; i < g_BootSector.DirEntryCount; i++)
    {
        if (memcmp(name, g_RootDirectory[i].Name, 11) == 0)
            return &g_RootDirectory[i];
    }

    return NULL;
}

bool readFile(DirectoryEntry* FileEntry, FILE* disk, uint8_t* outputBuffer) 
{
    bool ok = true;
    uint16_t currentCluster = FileEntry->FirstClusterLow;
    uint32_t bytesRemaining = FileEntry->Size;

    do {
        uint32_t lba = g_RootDirectoryEnd + (currentCluster - 2) * g_BootSector.SectorsPerCluster;
        fprintf(stdout, "%d\n", &lba);

        // Read only what's necessary
        uint32_t bytesToRead = g_BootSector.SectorsPerCluster * g_BootSector.BytesPerSector;
        if (bytesToRead > bytesRemaining)  // Prevent over-read
            bytesToRead = bytesRemaining;

        //ok = ok && readSectors(disk, lba, g_BootSector.SectorsPerCluster, outputBuffer); // this line is breaking
        ok = ok && readSectors(disk, lba, (bytesToRead + g_BootSector.BytesPerSector - 1) / g_BootSector.BytesPerSector, outputBuffer);
        outputBuffer += bytesToRead;
        bytesRemaining -= bytesToRead;
        

        uint32_t fatIndex = currentCluster * 3 / 2;
        if (currentCluster % 2  == 0) {
            currentCluster = (*(uint16_t*)(g_Fat + fatIndex)) && 0xFFF;
        } else {
            currentCluster = (*(uint16_t*)(g_Fat + fatIndex)) >> 4;
        }
    } while(ok && currentCluster < 0xFF8);
}

int main(int argc, char** argv) {
    if (argc < 3) {
        printf("Syntax: %s <disk image> <file name>\n");
        return -1;
    }

    FILE* disk = fopen(argv[1], "rb");
    
    if(!disk) {
        fprintf(stderr, "Cannot open disk image %s!\n", argv[1]);
        return -1;
    }

    if(!readBootSector(disk)) {
        fprintf(stderr, "Could not read boot sector\n", argv[1]);
        return -2;
    }

    if(!readFAT(disk)) {
        fprintf(stderr, "Could not read FAT!\n");
        free(g_Fat);
        return -3;
    }

    if(!readRootDirectory(disk)) {
        fprintf(stderr, "Could not read Root Directory!\n");
        free(g_Fat);
        free(g_RootDirectory);
        return -4;
    }

    DirectoryEntry* fileEntry = findFile(argv[2]);
    if (!fileEntry) {
        fprintf(stderr, "Could not find file %s!\n", argv[2]);
        free(g_Fat);
        free(g_RootDirectory);
        return -5;
    }

    uint8_t* buffer = (uint8_t*) malloc(fileEntry->Size + g_BootSector.BytesPerSector);

    
    if (!readFile(fileEntry, disk, buffer)) {
        fprintf(stderr, "Could not read file", argv[2]);
        free(g_Fat);
        free(g_RootDirectory);
        free(buffer);
        return -5;
    }

    for (size_t i = 0; i < fileEntry->Size; i++) {
        if (isprint(buffer[i]))
            fputc(buffer[i], stdout);
        else
            printf("<%02x>", buffer);
    }
    printf("\n");

    free(g_Fat);
    free(g_RootDirectory);
    return 0; 
}