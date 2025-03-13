bits 16

section _TEXT class=CODE

;
; void _cdecl x86_div64_32(uint64_t dividend, uint32_t divisor, uint64_t* quotientOut, uint32_t* remainderOut);
;
global _x86_div64_32
_x86_div64_32:

    ; make new call frame
    push bp             ; save old call frame
    mov bp, sp          ; initialize new call frame

    push bx

    ; divide upper 32 bits
    mov eax, [bp + 8]   ; eax <- upper 32 bits of dividend
    mov ecx, [bp + 12]  ; ecx <- divisor
    xor edx, edx
    div ecx             ; eax - quot, edx - remainder

    ; store upper 32 bits of quotient
    mov bx, [bp + 16]
    mov [bx + 4], eax

    ; divide lower 32 bits
    mov eax, [bp + 4]   ; eax <- lower 32 bits of dividend
                        ; edx <- old remainder
    div ecx

    ; store results
    mov [bx], eax
    mov bx, [bp + 18]
    mov [bx], edx

    pop bx

    ; restore old call frame
    mov sp, bp
    pop bp
    ret

;
; int 10h ah=0Eh
; args: character, page
;
global _x86_Video_WriteCharTeletype
_x86_Video_WriteCharTeletype:
    
    ; make new call frame
    push bp             ; save old call frame
    mov bp, sp          ; initialize new call frame

    ; save bx
    push bx

    ; [bp + 0] - old call frame
    ; [bp + 2] - return address (small memory model => 2 bytes)
    ; [bp + 4] - first argument (character)
    ; [bp + 6] - second argument (page)
    ; note: bytes are converted to words (you can't push a single byte on the stack)
    mov ah, 0Eh
    mov al, [bp + 4]
    mov bh, [bp + 6]

    int 10h

    ; restore bx
    pop bx

    ; restore old call frame
    mov sp, bp
    pop bp
    ret

;
;bool _cdecl x86_Disk_Reset(uint8_t drive);
;
global x86_Disk_Reset
_x86_Disk_Reset:

    ; make new call frame
    push bp             ; save old call frame
    mov bp, sp          ; initialize new call frame

    mov ah, 0
    mov dl, [bp + 4]    ; dl = drive number
    stc 
    int 13h

    mov ax, 1
    sbb ax, 0           ; 1 = true, 0 = false


    ; restore old call frame
    mov sp, bp
    pop bp
    ret

;
;bool _cdecl x86_Disk_Read(uint8_t drive,
;                          uint16_t cylinder,
;                          uint16_t head,
;                          uint16_t sector,
;                          uint8_t count,
;                          uint8_t far* dataOut);
;
global x86_Disk_Read
x86_Disk_Read:

    ; make new call frame
    push bp             ; save old call frame
    mov bp, sp          ; initialize new call frame

    push bx
    push es

    mov al, [bp + 4]    ; dl - drive number

    mov ch, [bp + 6]    ; ch - clyinder number (lower 8 bits)
    mov cl, [bp + 7]    ; cl - clyinder to bits 6-7
    shl cl, 6
    
    mov dh, [bp + 8]

    mov al, [bp + 10]
    and al, 3Fh
    or cl, al           ; sector to bits 0 - 5

    mov al, [bp + 12]

    mov bx, [bp + 16]
    mov es, bx
    mov bx, [bp + 14]

    mov ah, 02h
    stc 
    int 13h

    mov ax, 1
    sbb ax, 0           ; 1 = true, 0 = false

    pop es
    pop bx


    ; restore old call frame
    mov sp, bp
    pop bp
    ret


;bool _cdecl x86_Disk_GetDriveParams(uint8_t drive,
;                                    uint8_t* driveTypeOut,
;                                    uint16_t* clyindersOut,
;                                    uint16_t* sectorsOut,
;                                    uint16_t* headsOut);
;
global x86_Disk_GetDriveParams
_x86_Disk_GetDriveParams:
        ; make new call frame
    push bp             ; save old call frame
    mov bp, sp          ; initialize new call frame
    
    ; save registers
    push es
    push bx
    push si
    push di

    mov dl, [bp + 4]
    mov ah, 08h
    mov di, 0
    mov es, di
    stc
    int 13h

    mov ax, 1
    sbb ax, 0           ; 1 = true, 0 = false

    ; out params
    mov si, [bp + 6]    ; drive type from bl
    mov [si], bl

    mov bl, ch          ; cylinders - lower bits in ch
    mov bh, cl          ; cylinders - upper bits in cl (6-7)
    shr bh, 6
    mov si, [bp + 8]
    mov [si], bx

    xor ch, ch          ; sectors - lower 5 bits in cl
    and cl, 3Fh
    mov si, [bp + 10]
    mov [si], cx

    mov cl, dh          ; heads - dh
    mov si, [bp + 12]
    mov [si], cx

    ; load registers
    pop di
    pop si
    pop bx
    pop es

    ; restore old call frame
    mov sp, bp
    pop bp
    ret