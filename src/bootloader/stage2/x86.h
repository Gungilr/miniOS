#include "stdint.h"

void _cdecl x86_div64_32(uint64_t divdend, uint32_t divsor, uint64_t* quotientOut, uint32_t* remainderOut);

void _cdecl x86_Video_WriteCharTeletype(char c, uint8_t page);

bool _cdecl x86_Disk_Reset(uint8_t drive);

bool _cdecl x86_Disk_Read(uint8_t drive,
                          uint16_t cylinder,
                          uint16_t head,
                          uint16_t sector,
                          uint8_t count,
                          uint8_t far* dataOut);

bool _cdecl x86_Disk_GetDriveParams(uint8_t drive,
                                    uint8_t* driveTypeOut,
                                    uint16_t* clyindersOut,
                                    uint16_t* sectorsOut,
                                    uint16_t* headsOut);