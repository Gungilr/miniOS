org 0x0
bits 16

%define ENDL 0x0D, 0x0A

start:

    mov si, msg_hello
    call puts

.halt:
    cli
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

msg_hello: db 'Hello From The Kernel!', ENDL, 0
