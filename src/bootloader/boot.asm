org 0x7c00
bits 16

%define ENDL 0x0D, 0x0A


; FAT12 Header
;
jmp short start
nop


;
; obtained from the FAT 12 WIKI HEADER
;
bdb_oem:                    db 'MSWIN4.1'           ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entires_count:      dw 0E0h
bdb_total_sectors:          dw 2880                 ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0F0h                 ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:        dw 9                    ; 9 sector fa
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot record
ebr_drive_number:           db 0                    ; 0x00 floppy, 0x80 hdd, useless
                            db 0                    ; reserved
ebr_signiture:              db 29h
ebr_volume_id:              db 12h, 34h, 69h, 10h   ; serial number, value do what you want
ebr_volumn_label:           db 'NANOBYTE OS'        ; 11 BYTespadd
ebr_system_id:              db 'FAT12   '           ; 8 bytes pad it

start:
    jmp main

;
; Prints string to screen
; Params
;   - ds:si points to string
;
puts:
    ; save modified buffers
    push si
    push ax
    push bx

.loop:
    lodsb                                           ; loads first byte of string into ax then increments
    or al, al
    jz .done
    mov ah, 0x0e
    mov bh, 0x0
    int 0x10
    jmp .loop

.done:
    pop bx
    pop ax
    pop si    
    ret

main:
    ;setup data segements
    mov ax, 0                                       ; can't set ds/es directly
    mov ds, ax
    mov es, ax

    mov ss, ax
    mov sp, 0x7c00                                  ;stack grow down from where we are in memory

    ; read something from floppy
    ; BIOS should set DL to 1
    mov [ebr_drive_number], dl

    mov ax, 1                                       ; LBA = 1, set to read from head 2
    mov cl, 1                                       ; 1 sector to read
    mov bx, 0x7E00                                  ; data should be after booloader
    call disk_read

    mov si, msg_hello
    call puts

    cli
    hlt
;
; Error Handlers
;
floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16                                          ; wait for input
    jmp 0FFFFh:0

.halt:
    cli                                             ; disables interrupts, so CPU can't exit the halt state
    hlt

;
; Disk Rountines
;

;
; converts an LBA address to and CHS address
; Parameters:
;   - ax: LBA address
; Returns
;   - cx[bits 0-5]: sector number
;   - cx[bits 6-15]: cylinder
;   - dh: head
;
lba_to_chs:

    push ax
    push dx

    xor dx, dx                              ; dx = 0
    div word [bdb_sectors_per_track]        ; ax = LBA / SectorsPerTrack
                                            ; dx = LBA % SectorsPerTrack

    inc dx                                  ; dx = (LBA % SectorsPerTrack + 1) = sector
    mov cx, dx

    xor dx, dx                              ; dx = 0
    div word [bdb_heads]                    ; ax = (LBA / SectorsPerTrack) / Heads = cylinder
                                            ; dx = (LBA / SectorsPerTrack) % Heads = head
    mov dh, dl                              ; dl = head
    mov ch, al                              ; ch = cylinder
    shl ah, 6   
    or cl, ah                               ; puts upper 2 bits into cl

    pop ax
    mov dl, al                              ; restores dl
    pop ax
    ret

;
; Reads Sectors from a disk
; Parameters:
;   - ax: LBA address
;   - cl: number of sectors to read (up to 128)
;   - dl: drive number
;   - es:bx memory address where to store and read
;
disk_read:
    push ax                                 ; save the modified registers
    push bx
    push cx
    push dx
    push di

    push cx                                 ; temporarily save CL (number of sectors to read)
    call lba_to_chs                         ; compute CHS
    pop ax                                  ; AL number of sectors to read

    mov ah, 02h
    mov di, 03                              ; try 3 times

.retry:
    pusha                                   ; saves all registers since we don't know what might change
    stc                                     ; sets carry flags
    int 13h
    jnc .done                               ; jmp if not carry set

    ; read failed
    popa
    call disk_reset
    dec di
    test di, di
    jnz .retry

.fail:
    ; all attempts are exhausted
    jmp floppy_error

.done:

    popa

    pop di                                  ; restore modified registers
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;
; Resets disk controller
; Parameters:
;   - dl: drive number
;
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc  floppy_error
    popa
    ret



msg_hello: db 'Hello world!', ENDL, 0
msg_read_failed: db 'Read from disk failed', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h