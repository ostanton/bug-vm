_start:
    jmp_eq loop_start zero

loop_start:
    addi r0 r0 3         ; set r0 to the sum of r0 and 3
    addi r1 zero 3       ; set r1 to 3
    cmp r1 r0 r1         ; compare r0 and r1, storing the result in r1
    jmp_eq loop_start r1 ; if (r0 == r1) goto jump_target
    store 1 r0           ; store at address 0 the value of r0
    addi r0 zero 5
    addi r1 zero 8
    add r0 r0 r1
    load r1 1
    add r0 r0 r1
    call 1
    call 0
