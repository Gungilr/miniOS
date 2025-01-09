org 0x7c00
bits 16

%define ENDL 0x0D, 0x0A

#
# FAT12 Header
#
jmp short start
nop


#
# obtained from the FAT 12 WIKI HEADER
#
bdb_oem:                    db 'MSWIN4.1'           ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       db 1
bdb_fat_count:              db 2
bdb_dir_entires_count:      dw 0E0h
bdb_total_sectors:          dw 2880                 ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0F0h                 ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:        dw 9                    ; 9 sector floppy disk
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

# extended boot record
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
    lodsb  ; loads first byte of string into ax then increments
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
    mov ax, 0           ; can't set ds/es directly
    mov ds, ax
    mov es, ax

    mov ss, ax
    mov sp, 0x7c00 ;stack grow down from where we are in memory

    mov si, msg_hello
    call puts

    hlt

.halt:
    jmp .halt

msg_hello: db 'Hello world!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h