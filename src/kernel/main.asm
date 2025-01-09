org 0x7c00
bits 16

%define ENDL 0x0D, 0x0A

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