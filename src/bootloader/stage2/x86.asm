bits 16

section _TEXT class=CODE

global _x86_Video_WriteCharTeletype

;
; int 10h ah=0Eh
; args: character, page
;
_x86_Video_WriteCharTeletype:

    ;make new callstack frame
    push bp                     ; save old frame
    mov bp, sp                  ; initalize new call stack frame

    ; save bx
    push bx

    ; [bp + 0] - old call frame
    ; [bp + 2] - return address
    ; [bp + 4] - first argument (character)
    ; [bp + 6] - second argument (page)
    ; note: bytes are converted to words(you can't push a single byte onto the stack)
    mov ah, 0Eh
    mov al, [bp + 4]
    mov bh, [bp + 6]

    int 10h

    ; restore bx
    pop bx

    ;restore the frame
    mov sp, bp
    pop bp
    ret
