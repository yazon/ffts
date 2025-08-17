set architecture aarch64
set pagination off
set disassemble-next-line on
target remote :12345
# Set up catchpoints for all EE BRK instructions
catch signal SIGTRAP
condition 1 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0xEE00
commands 1
printf "=== EE_ENTRY ===\n"
printf "Entry params: x0=%#llx x2=%#llx x11=%#llx x12=%#llx\n", (unsigned long long)$x0, (unsigned long long)$x2, (unsigned long long)$x11, (unsigned long long)$x12
printf "Stream ptrs: x3=%#llx x4=%#llx x5=%#llx x6=%#llx\n", (unsigned long long)$x3, (unsigned long long)$x4, (unsigned long long)$x5, (unsigned long long)$x6
printf "Stream ptrs: x7=%#llx x8=%#llx x9=%#llx x10=%#llx\n", (unsigned long long)$x7, (unsigned long long)$x8, (unsigned long long)$x9, (unsigned long long)$x10
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 2 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0xEE01
commands 2
printf "=== EE_ENTRY_PARAMS ===\n"
printf "Check pointers validity: x0=%#llx x2=%#llx x12=%#llx\n", (unsigned long long)$x0, (unsigned long long)$x2, (unsigned long long)$x12
printf "Loop counter x11=%#llx\n", (unsigned long long)$x11
set $pc = $pc + 4
continue
end

catch signal SIGTRAP  
condition 3 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0xEE02
commands 3
printf "=== EE_TWIDDLES_LOADED ===\n"
printf "Twiddle v16.d: %f %f\n", $v16.d.f[0], $v16.d.f[1]
printf "Twiddle v17.d: %f %f\n", $v17.d.f[0], $v17.d.f[1]
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 4 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0xEE03
commands 4
printf "=== EE_LOOP_START (iter) ===\n"
printf "Loop counter x11=%#llx\n", (unsigned long long)$x11
printf "Stream pointers after increment check:\n"
printf "x3=%#llx x4=%#llx x5=%#llx x6=%#llx\n", (unsigned long long)$x3, (unsigned long long)$x4, (unsigned long long)$x5, (unsigned long long)$x6
printf "x7=%#llx x8=%#llx x9=%#llx x10=%#llx\n", (unsigned long long)$x7, (unsigned long long)$x8, (unsigned long long)$x9, (unsigned long long)$x10
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 5 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0xEE04
commands 5
printf "=== EE_DATA_LOADED ===\n"
printf "Sample loaded data v30.2s: %f %f\n", $v30.s.f[0], $v30.s.f[1]
printf "Sample loaded data v31.2s: %f %f\n", $v31.s.f[0], $v31.s.f[1]
printf "Decremented x11=%#llx\n", (unsigned long long)$x11
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 6 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0xEE06
commands 6
printf "=== EE_OFFSET1_LOADED ===\n"
printf "First offset w2=%#x (hex) %d (dec)\n", (unsigned int)$w2, (int)$w2
printf "Offset pointer x12=%#llx\n", (unsigned long long)$x12
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 7 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0xEE07
commands 7
printf "=== EE_OFFSET2_LOADED ===\n"
printf "Second offset w16=%#x (hex) %d (dec)\n", (unsigned int)$w16, (int)$w16
printf "Offset pointer x12=%#llx\n", (unsigned long long)$x12
set $pc = $pc + 4
continue
end

# EE_ADDR1_CALC (brk 0xEE08)
catch signal SIGTRAP
condition 8 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0xEE08)
commands 8
printf "=== EE_ADDR1_CALC ===\n"
set $off2_1 = ((unsigned long long)$x2 - (unsigned long long)$x0) >> 2
printf "Base x0=%#llx, x2=%#llx => off2_1=%llu\n", (unsigned long long)$x0, (unsigned long long)$x2, (unsigned long long)$off2_1
printf "Address validity check: "
x/8bx $x2
set $pc = $pc + 4
continue
end

# EE_ADDR2_CALC (brk 0xEE09)
catch signal SIGTRAP
condition 9 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0xEE09)
commands 9
printf "=== EE_ADDR2_CALC ===\n"
set $off2_2 = ((unsigned long long)$x16 - (unsigned long long)$x0) >> 2
printf "Base x0=%#llx, x16=%#llx => off2_2=%llu\n", (unsigned long long)$x0, (unsigned long long)$x16, (unsigned long long)$off2_2
printf "Address validity check: "
x/8bx $x16
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 10 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0xEE0A
commands 10
printf "=== EE_STORE1 ===\n"
printf "About to store to x2=%#llx x16=%#llx\n", (unsigned long long)$x2, (unsigned long long)$x16
printf "Sample store data v0: %f %f %f %f\n", $v0.s.f[0], $v0.s.f[1], $v0.s.f[2], $v0.s.f[3]
printf "Sample store data v1: %f %f %f %f\n", $v1.s.f[0], $v1.s.f[1], $v1.s.f[2], $v1.s.f[3]
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 11 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0xEE0B
commands 11
printf "=== EE_STORE2 ===\n"
printf "Storing final results to x2=%#llx x16=%#llx\n", (unsigned long long)$x2, (unsigned long long)$x16
printf "Final x2 after stores=%#llx x16 after stores=%#llx\n", (unsigned long long)$x2, (unsigned long long)$x16
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 12 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0xEE0C
commands 12
printf "=== EE_LOOP_EXIT ===\n"
printf "Loop counter x11=%#llx\n", (unsigned long long)$x11
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 13 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0xEE0D
commands 13
printf "=== EE_FUNCTION_EXIT ===\n"
printf "Final state - all pointers:\n"
printf "x0=%#llx x2=%#llx x12=%#llx\n", (unsigned long long)$x0, (unsigned long long)$x2, (unsigned long long)$x12
printf "Stream ptrs: x3=%#llx x4=%#llx x5=%#llx x6=%#llx\n", (unsigned long long)$x3, (unsigned long long)$x4, (unsigned long long)$x5, (unsigned long long)$x6
printf "Stream ptrs: x7=%#llx x8=%#llx x9=%#llx x10=%#llx\n", (unsigned long long)$x7, (unsigned long long)$x8, (unsigned long long)$x9, (unsigned long long)$x10
set $pc = $pc + 4
continue
end

# OE Function breakpoints
catch signal SIGTRAP
condition 14 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0E00
commands 14
printf "=== OE_ENTRY ===\n"
printf "Entry params: x0=%#llx x1=%#llx x2=%#llx\n", (unsigned long long)$x0, (unsigned long long)$x1, (unsigned long long)$x2
printf "Stream ptrs: x3=%#llx x4=%#llx x5=%#llx x6=%#llx\n", (unsigned long long)$x3, (unsigned long long)$x4, (unsigned long long)$x5, (unsigned long long)$x6
printf "Stream ptrs: x7=%#llx x8=%#llx x9=%#llx x10=%#llx\n", (unsigned long long)$x7, (unsigned long long)$x8, (unsigned long long)$x9, (unsigned long long)$x10
printf "x11=%#llx x12=%#llx\n", (unsigned long long)$x11, (unsigned long long)$x12
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 15 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0E01
commands 15
printf "=== OE_ENTRY_PARAMS ===\n"
printf "Verify pointer ranges and validity\n"
printf "Input base x0=%#llx, twiddle x11=%#llx, offsets x12=%#llx\n", (unsigned long long)$x0, (unsigned long long)$x11, (unsigned long long)$x12
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 16 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0E02
commands 16
printf "=== OE_INITIAL_LOADS ===\n"
printf "Sample loaded data v30.2s: %f %f\n", $v30.s.f[0], $v30.s.f[1]
printf "Sample loaded data v31.2s: %f %f\n", $v31.s.f[0], $v31.s.f[1]
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 17 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0E10
commands 17
printf "=== OE_OFF2_LOADED ===\n"
printf "Second offset w14=%#x (hex) %d (dec)\n", (unsigned int)$w14, (int)$w14
printf "Offset pointer x12=%#llx\n", (unsigned long long)$x12
set $pc = $pc + 4
continue
end

# OE_ADDRS_READY (brk 0x0E11)
catch signal SIGTRAP
condition 18 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0E11)
commands 18
printf "=== OE_ADDRS_READY ===\n"
set $off2_a = ((unsigned long long)$x2  - (unsigned long long)$x0) >> 2
set $off2_b = ((unsigned long long)$x14 - (unsigned long long)$x0) >> 2
printf "x2=%#llx x14=%#llx => off2_a=%llu off2_b=%llu\n", (unsigned long long)$x2, (unsigned long long)$x14, (unsigned long long)$off2_a, (unsigned long long)$off2_b
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 19 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0E14
commands 19
printf "=== OE_FIRST_STORE ===\n"
printf "First store to x2=%#llx\n", (unsigned long long)$x2
printf "Sample store data v0: %f %f %f %f\n", $v0.s.f[0], $v0.s.f[1], $v0.s.f[2], $v0.s.f[3]
printf "Sample store data v1: %f %f %f %f\n", $v1.s.f, $v1.s.f[1], $v1.s.f[2], $v1.s.f[3]
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 20 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0E15
commands 20
printf "=== OE_FINAL_STORES ===\n"
printf "Final stores to x14=%#llx\n", (unsigned long long)$x14
printf "Final data q4: %f %f %f %f\n", $v4.s.f[0], $v4.s.f[1], $v4.s.f[2], $v4.s.f[3]
printf "Final data q7: %f %f %f %f\n", $v7.s.f[0], $v7.s.f[1], $v7.s.f[2], $v7.s.f[3]

set $pc = $pc + 4
continue
end

# X8T_ENTRY
catch signal SIGTRAP
condition 21 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x8D00)
commands 21
printf "=== X8T_ENTRY ===\n"
# Compute per-stream bounds for N=32 (x0 is base, stride=x1)
set $c0 = (unsigned long long)$x0
set $c1 = (unsigned long long)($x0 + $x1)
set $c2 = (unsigned long long)($x0 + 2*$x1)
set $c3 = (unsigned long long)($x0 + 3*$x1)
set $c4 = (unsigned long long)($x0 + 4*$x1)
set $c5 = (unsigned long long)($x0 + 5*$x1)
set $c6 = (unsigned long long)($x0 + 6*$x1)
set $c7 = (unsigned long long)($x0 + 7*$x1)
set $span = (unsigned long long)$x1
printf "Entry params: x0=%#llx x1=%#llx x2=%#llx lr=%#llx sp=%#llx\n", (unsigned long long)$x0, (unsigned long long)$x1, (unsigned long long)$x2, (unsigned long long)$x30, (unsigned long long)$sp
printf "STREAM bounds: c0=[%#llx,%#llx) c1=[%#llx,%#llx) c2=[%#llx,%#llx) c3=[%#llx,%#llx)\n", $c0, $c0+$span, $c1, $c1+$span, $c2, $c2+$span, $c3, $c3+$span
printf "STREAM bounds: c4=[%#llx,%#llx) c5=[%#llx,%#llx) c6=[%#llx,%#llx) c7=[%#llx,%#llx)\n", $c4, $c4+$span, $c5, $c5+$span, $c6, $c6+$span, $c7, $c7+$span
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 22 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0x8D02
commands 22
printf "=== X8T_ENTRY_PARAMS ===\n"
printf "Verify x8_t parameters and initial setup\n"
printf "Data ptr x0=%#llx, stride x1=%#llx, LUT x2=%#llx\n", (unsigned long long)$x0, (unsigned long long)$x1, (unsigned long long)$x2
printf "Loop counter x11=%#llx\n", (unsigned long long)$x11
printf "Streams: x3=%#llx x4=%#llx x5=%#llx x6=%#llx x7=%#llx x8=%#llx x9=%#llx x10=%#llx\n", (unsigned long long)$x3,(unsigned long long)$x4,(unsigned long long)$x5,(unsigned long long)$x6,(unsigned long long)$x7,(unsigned long long)$x8,(unsigned long long)$x9,(unsigned long long)$x10
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 23 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0x8D03
commands 23
printf "=== X8T_LOOP_START ===\n"
printf "Loop iteration, counter x11=%#llx\n", (unsigned long long)$x11
printf "Stream pointers: x3=%#llx x4=%#llx x5=%#llx x6=%#llx\n", (unsigned long long)$x3, (unsigned long long)$x4, (unsigned long long)$x5, (unsigned long long)$x6
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 24 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0x8D04
commands 24
printf "=== X8T_LOOP_CHECK ===\n"
printf "Before loop check, x11=%#llx\n", (unsigned long long)$x11
set $pc = $pc + 4
continue
end

# X8T_EXIT
catch signal SIGTRAP
condition 25 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x8D05)
commands 25
printf "=== X8T_EXIT ===\n"
printf "lr=%#llx sp=%#llx\n", (unsigned long long)$x30, (unsigned long long)$sp
x/4gx $sp
# do NOT advance past more than the BRK (we still skip just the BRK)
set $pc = $pc + 4
continue
end

# X8_ENTRY (BRK_X8_LUT_PTR)
catch signal SIGTRAP
condition 26 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x8C00)
commands 26
printf "=== X8_ENTRY ===\n"
printf "x0=%#llx x1=%#llx x2=%#llx x12=%#llx x11=%#llx lr=%#llx sp=%#llx\n", (unsigned long long)$x0,(unsigned long long)$x1,(unsigned long long)$x2,(unsigned long long)$x12,(unsigned long long)$x11,(unsigned long long)$x30,(unsigned long long)$sp
printf "streams x3..x10: %llx %llx %llx %llx %llx %llx %llx %llx\n", (unsigned long long)$x3,(unsigned long long)$x4,(unsigned long long)$x5,(unsigned long long)$x6,(unsigned long long)$x7,(unsigned long long)$x8,(unsigned long long)$x9,(unsigned long long)$x10
set $pc = $pc + 4
continue
end

# X8_LOOP_SETUP (shared immediate 0x0810, used here after neg/lsr)
catch signal SIGTRAP
condition 27 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0810)
commands 27
printf "=== X8_LOOP_SETUP ===\n"
printf "x11=%#llx\n", (unsigned long long)$x11
set $pc = $pc + 4
continue
end

# X8 LUT loads
catch signal SIGTRAP
condition 28 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x8C10)
commands 28
printf "=== X8_PRE_LUT0 ===\n"
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 29 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x8C11)
commands 29
printf "=== X8_POST_LUT0 ===\n"
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 30 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x8C12)
commands 30
printf "=== X8_PRE_LUT1 ===\n"
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 31 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x8C13)
commands 31
printf "=== X8_POST_LUT1 ===\n"
set $pc = $pc + 4
continue
end

# X8 pre-store checkpoints (0,2,4,6)
catch signal SIGTRAP
condition 32 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x8C20)
commands 32
printf "=== X8_PRE_ST_DATA0 === x3=%#llx\n", (unsigned long long)$x3
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 33 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x8C22)
commands 33
printf "=== X8_PRE_ST_DATA2 === x5=%#llx\n", (unsigned long long)$x5
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 34 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x8C24)
commands 34
printf "=== X8_PRE_ST_DATA4 === x7=%#llx\n", (unsigned long long)$x7
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 35 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x8C26)
commands 35
printf "=== X8_PRE_ST_DATA6 === x9=%#llx\n", (unsigned long long)$x9
set $pc = $pc + 4
continue
end


catch signal SIGTRAP
condition 36 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x8D20)
commands 36
printf "=== X8T_PRE_ST_I1 === x4=%#llx INB=%d\n", (unsigned long long)$x4, ( ((unsigned long long)$x4)>= $c1 ) && ( ((unsigned long long)$x4 + 32) <= ($c1 + $span) )
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 37 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x8D21)
commands 37
printf "=== X8T_PRE_ST_I3 === x6=%#llx INB=%d\n", (unsigned long long)$x6, ( ((unsigned long long)$x6)>= $c3 ) && ( ((unsigned long long)$x6 + 32) <= ($c3 + $span) )
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 38 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x8D30)
commands 38
printf "=== X8T_PRE_ST_F0 === x3=%#llx INB=%d\n", (unsigned long long)$x3, ( ((unsigned long long)$x3)>= $c0 ) && ( ((unsigned long long)$x3 + 32) <= ($c0 + $span) )
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 39 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x8D31)
commands 39
printf "=== X8T_PRE_ST_F2 === x5=%#llx INB=%d\n", (unsigned long long)$x5, ( ((unsigned long long)$x5)>= $c2 ) && ( ((unsigned long long)$x5 + 32) <= ($c2 + $span) )
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 40 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x8D32)
commands 40
printf "=== X8T_PRE_ST_F4 === x7=%#llx INB=%d\n", (unsigned long long)$x7, ( ((unsigned long long)$x7)>= $c4 ) && ( ((unsigned long long)$x7 + 32) <= ($c4 + $span) )
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 41 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x8D33)
commands 41
printf "=== X8T_PRE_ST_F6 === x9=%#llx INB=%d\n", (unsigned long long)$x9, ( ((unsigned long long)$x9)>= $c6 ) && ( ((unsigned long long)$x9 + 32) <= ($c6 + $span) )
set $pc = $pc + 4
continue
end

catch signal SIGSEGV
commands
printf "=== SIGSEGV ===\n"
printf "pc=%#llx lr=%#llx sp=%#llx\n", (unsigned long long)$pc, (unsigned long long)$x30, (unsigned long long)$sp
x/8i $pc-16
x/8gx $sp
bt
end
