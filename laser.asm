;laser.asm
;Name: David Piatt
;Date 4/16/2017
;class: cse 2421 m/w 4:15
;this is lab8 or laser.asm
;it takes inputed binary, stores it in an array and prints out
;the corresponding characters
;then it encodes the binary in base 64 and prints that



section .data
message: times 128 db 0
;comment below was an attempt at a global array to index through to find the base 64 equivalent. I later found out that I have no idea how to make this array and nasm is giving poor feedback
;b64: .byte "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+-"

section .text
USE32
global _start
_start:
    call decode_message
    call print_message
    push '\n'
    call print_character
    add esp, 4
    ;comment below segfaults :(. Probably because I couldn't get the array and indexing to work
    ;call print_base64_message
    mov ebx, 0
    mov eax, 1
    int 80h


get_bit:
    push ebp                ;set up stack
    mov ebp, esp
    call read_character
    cmp eax, '0'            ;is the value 0?
    je return_zero          ;if so return 0, else 1
    jmp return_one
    return_zero:
        mov eax, 0
        jmp get_bit_done
    return_one:
        mov eax, 1
        jmp get_bit_done
    
    get_bit_done:
        leave
        ret

get_byte:       
    push ebp                    ;set up stack
    mov ebp, esp
    xor eax, eax
    sub esp, 4
    mov dword [ebp-4],0         ;put counter variable on stack
    
    get_byte_loop:
        cmp dword [ebp-4],8     ;we're iterating 8 times. 
        jge get_byte_done
        inc dword [ebp-4]
        push edx
        call get_bit            ;get_bit messes with edx
        pop edx
        shl dl, 1
        or dl, al
        jmp get_byte_loop
        
    get_byte_done:              ;finish up
        mov eax, 0
        mov al, dl
        leave
        ret
       
decode_message:                 ;set up stack
    push ebp
    mov ebp, esp
    sub esp, 4          
    mov dword [ebp-4], 0        ;initialize counter
    decode_loop:

        call get_byte
        lea edx, [message]      ;iterate through array
        mov ecx, [ebp-4]
        mov [edx+ecx*1], al     ;move what's in al to the array
        cmp eax, 0              ;if al is 0 then its the null byte
        je decode_done          
        inc dword [ebp-4]       ;increment counter
        jmp decode_loop

    decode_done:
        leave   
        ret

print_message:
                                ;set up stack
    push ebp    
    mov ebp, esp
    lea edx, [message]          ;get address of array
    mov ecx, 0                  ;initialize index
    print_message_loop:
        mov eax, [edx+ecx*1]    ;move element i into eax
        push ecx                ;push registers as they are changed
        push edx
        push eax
        call print_character    ;call function
        pop eax              
        pop edx                 ;get regs back
        pop ecx
        inc ecx                 ;increment counter
        cmp eax, 0              ;is the thing in eax null char?
        jz print_message_done
        jmp print_message_loop
    print_message_done:
        
        leave 
        ret
    
put_b64_char:
    push ebp                            ;set up stack
    mov ebp, esp
    mov eax, [ebp+8]                    ;get first arg
    push eax                            ;push it to stack
    ;here I would loop through the array to figure out what character it corresponds to.
    call print_character                ;print the character
    add esp, 4
    leave
    ret

print_base64_message:
    push ebp                            ;set up stack
    mov ebp, esp
    sub esp, 12                         ;we're storing 3 vars on stack
    xor ecx, ecx
    lea edx, [message]                  ;get beginning of array to iterate
    print_base_64_loop:
        mov eax, [edx+ecx*1]
        mov dword [ebp-4],eax           ;message[i]
        cmp dword [ebp-4], 0            ;are we at the last character
        je print_base_64_done           ;then exit
                                        ;else pull get next 2 chars
        inc ecx
        mov eax, [edx+ecx*1]
        mov dword [ebp-8], eax
        inc ecx 
        mov eax, [edx+ecx*1]
        mov [ebp-12], eax
        dec ecx                         ;get ecx back to original
        dec ecx
        mov eax, ecx
        inc ecx                         ;increment it for next round
        mov ebx, 3                      ;ecx % 3 to determine case
        div ebx         
        cmp edx, 1                      ;this is remainder
        jl case1                        ;rem < 1? go to case 1
        je case2                        ; rem == 1? go to case 2
        jg case3                        ; rem > 1? go to case 3
                


    case_loop:
        ;each case is for the problems that arise when truncating the 8 bits to 6 bits. While it doesn't work right this is the idea. It's a combination of the wikipedia article and some code from stack overflow. I'm not sure how to pull it all together, but I think I'm on the right track. 
        case1:  ;two remaining after truncation
            push ecx
            mov ecx, [ebp-4]
            mov eax, [ebp-8]  
            mov al, cl
            shr eax, 2
            shl ecx, 30
            shr ecx, 30
            push ecx
            call put_b64_char
            add esp, 4
            pop ecx
            jmp print_base_64_loop
        case2:  ;four remaining after truncation
            push ecx
            mov ecx, [ebp-4]
            mov eax, [ebp-8]
            mov edx, [ebp-12]
            mov dl, al
            shl ecx, 4
            shr eax, 4
            or ecx, eax
            shl edx, 28
            shr edx, 28
            push edx
            call put_b64_char
            add esp, 4
            pop ecx
            jmp print_base_64_loop
        case3:  ;first six bits from last two char's truncated bytes. 
            push ecx
            mov ecx, [ebp-4]
            mov eax, [ebp-8]
            mov edx, [ebp-12]
            mov cl, al
            shl ecx, 30
            shr ecx, 30
            shl edx, 2
            shr eax, 6
            push eax
            call put_b64_char
            add esp, 4
            pop ecx
            jmp print_base_64_loop
    

    
    print_base_64_done:
        leave
        ret            

print_character:    
    push ebp                    ;set up stack
    mov ebp, esp                ;save current stack frame
    
    push ebx                    ;save ebx
        
                                ;print character to std out
    mov eax, 4                  ;syscall 4 (write)
    mov ebx, 1                  ;file descriptor (stdout)
    lea ecx, [ebp+8]            ;pointer to data to write
    mov edx, 1                  ;byte count
    int 0x80                    ;issue system call
        
    pop ebx                     ;cleanup restore ebx
    leave                       ;restore stack
    ret

read_character:
    push ebp                    ;set up stack
    mov ebp, esp
    sub esp, 4                  ;space for one int
    push ebx                    ;save ebx
    
    mov eax, 3                  ;read in character form user
    mov ebx, 0                  ;file descriptor 
    lea ecx, [ebp-4]            ;pointer to data to save to
    mov edx, 1                  ;byte count 
    int 0x80                    ;issue system call

    mov eax, [ebp-4]            ;save final value in eax
    pop ebx                     ;cleanup
    add esp, 4
    leave 
    ret                         ;return to caller


