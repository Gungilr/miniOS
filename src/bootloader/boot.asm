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
    ;setup data segements
    mov ax, 0                                       ; can't set ds/es directly
    mov ds, ax
    mov es, ax

    mov ss, ax
    mov sp, 0x7c00                                  ;stack grow down from where we are in memory

    ;some BIOS might start from 07C0:0000 instead of 0000:7C00 
    ;makes sure we're in the right location
    push es
    push word .after
    retf
.after:
    ; read something from floppy
    ; BIOS should set DL to 1
    mov [ebr_drive_number], dl

    ;loading mesage
    mov si, msg_hello
    call puts

    ; read drive parameters
    push es
    mov ah, 08h
    int 13h
    jc floppy_error
    pop es

    and cl, 0x3F                                    ; remove top 2 bits
    xor ch, ch
    mov [bdb_sectors_per_track], cx                 ; sector count

    inc dh
    mov [bdb_heads], dh                             ; head count

    ; Compute LBA of root directory = reserved + fats * sectors_per_fat
    mov ax, [bdb_sectors_per_fat]                   
    mov bl, [bdb_fat_count]                
    xor bh, bh
    mul bx                                          ; ax = (fats * sectors_per_fat)
    add ax, [bdb_reserved_sectors]                  ; ax = LBA of root directory
    push ax

    ; compute size of the root directory = (32 * number_of_sectors)
    mov ax, [bdb_sectors_per_fat]
    shl ax, 5                                       ; ax * 32
    xor dx, dx                                      ; dx = 0 for remiander
    div word [bdb_bytes_per_sector]                 ; does divison 

    test dx, dx                                     ; checks if remainder is 0 or 1
    jz root_dir_after
    inc ax                                          ; rounds up the divison\


.root_dir_after:

    ; read root directory
    mov cl, al                                      ; cl = number of sectors to read = size of the root directory
    pop ax                                          ; al = LBA of the root directory
    mov dl, [ebr_drive_number]                      ; dl = dirve number
    mov bx, buffer                                  ; es:bx = buffer
    call disk_read

    ; search for kernel.bin
    xor bx, bx
    mov di, buffer

.serach_kernel:
    mov si, file_kernel_bin
    mov cx, 11                                      ; comapre up to 11 chars
    push di
    repe cmpsb                                      ; compares si:di to es:di auto inc both 
    pop di
    je .found_kernel

    add di, 32
    inc, bx
    cmp bx, [bdb_dir_entires_count]
    jl .serach_kernel
    jmp kernel_not_found_error:

.found_kernel:

    ; di should have the entry address
    mov ax, [di + 26]                               ; first logical cluster field
    mov [kernel_cluster], ax

    ; load FAT from disk to memory
    mov ax, [bdb_reserved_sectors]
    mov bx, buffer
    mov cl, [bdb_sectors_per_fat]
    mov dl, [ebr_drive_number]
    call disk_read

    ; read kernel process FAT Chain
    mov bx, KERNERL_LOAD_SEGEMENT
    mov es, bx
    mov bx, KERNERL_LOAD_OFFEST

.load_kernel_loop:

    ; read next cluster
    mov ax, [kernel_cluster]

    cli
    hlt
;
; Error Handlers
;
floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

kernel_not_found_error:
    mov si, msg_kernel_not_found
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



msg_loading:                db 'Loading.... ', ENDL, 0
msg_read_failed:            db 'Read from disk failed', ENDL, 0
msg_kernel_not_found:       db 'Kernel bin not found', ENDL, 0
file_kernel_bin:            db 'KERNEL  BIN', ENDL, 0
kernel_cluster:             dw 0

KERNERL_LOAD_SEGEMENT:      equ 0x2000
KERNERL_LOAD_OFFEST:        equ 0

times 510-($-$$) db 0
dw 0AA55h

buffer: