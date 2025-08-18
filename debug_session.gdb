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
printf "Twiddle v16.4s: %f %f %f %f\n", $v16.s.f[0], $v16.s.f[1], $v16.s.f[2], $v16.s.f[3]
printf "Twiddle v17.4s: %f %f %f %f\n", $v17.s.f[0], $v17.s.f[1], $v17.s.f[2], $v17.s.f[3]
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
printf "v30: %f %f %f %f\n", $v30.s.f[0], $v30.s.f[1], $v30.s.f[2], $v30.s.f[3]
printf "v31: %f %f %f %f\n", $v31.s.f[0], $v31.s.f[1], $v31.s.f[2], $v31.s.f[3]
printf "v26: %f %f %f %f\n", $v26.s.f[0], $v26.s.f[1], $v26.s.f[2], $v26.s.f[3]
printf "v27: %f %f %f %f\n", $v27.s.f[0], $v27.s.f[1], $v27.s.f[2], $v27.s.f[3]
printf "v28: %f %f %f %f\n", $v28.s.f[0], $v28.s.f[1], $v28.s.f[2], $v28.s.f[3]
printf "v29: %f %f %f %f\n", $v29.s.f[0], $v29.s.f[1], $v29.s.f[2], $v29.s.f[3]
printf "v18: %f %f %f %f\n", $v18.s.f[0], $v18.s.f[1], $v18.s.f[2], $v18.s.f[3]
printf "v19: %f %f %f %f\n", $v19.s.f[0], $v19.s.f[1], $v19.s.f[2], $v19.s.f[3]
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
printf "=== OE_STREAM_PTRS ===\n"
printf "x3=%#llx x4=%#llx x5=%#llx x6=%#llx x7=%#llx x8=%#llx x9=%#llx x10=%#llx\n", (unsigned long long)$x3,(unsigned long long)$x4,(unsigned long long)$x5,(unsigned long long)$x6,(unsigned long long)$x7,(unsigned long long)$x8,(unsigned long long)$x9,(unsigned long long)$x10
printf "deltas: x4-x3=%lld x5-x3=%lld x6-x3=%lld x7-x3=%lld x8-x3=%lld x9-x3=%lld x10-x3=%lld\n", (long long)($x4-$x3),(long long)($x5-$x3),(long long)($x6-$x3),(long long)($x7-$x3),(long long)($x8-$x3),(long long)($x9-$x3),(long long)($x10-$x3)
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 16 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0E02
commands 16
printf "=== OE_INITIAL_LOADS ===\n"
printf "Regs: v8 v10 v22 v23 v26 v27 v30 v31\n"
printf "v8:  %f %f %f %f\n",  $v8.s.f[0],  $v8.s.f[1],  $v8.s.f[2],  $v8.s.f[3]
printf "v10: %f %f %f %f\n",  $v10.s.f[0], $v10.s.f[1], $v10.s.f[2], $v10.s.f[3]
printf "v22: %f %f %f %f\n",  $v22.s.f[0], $v22.s.f[1], $v22.s.f[2], $v22.s.f[3]
printf "v23: %f %f %f %f\n",  $v23.s.f[0], $v23.s.f[1], $v23.s.f[2], $v23.s.f[3]
printf "v26: %f %f %f %f\n",  $v26.s.f[0], $v26.s.f[1], $v26.s.f[2], $v26.s.f[3]
printf "v27: %f %f %f %f\n",  $v27.s.f[0], $v27.s.f[1], $v27.s.f[2], $v27.s.f[3]
printf "v30: %f %f %f %f\n",  $v30.s.f[0], $v30.s.f[1], $v30.s.f[2], $v30.s.f[3]
printf "v31: %f %f %f %f\n",  $v31.s.f[0], $v31.s.f[1], $v31.s.f[2], $v31.s.f[3]
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 17 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0E10
commands 17
printf "=== OE_OFF2_LOADED ===\n"
printf "Second offset w14=%#x (hex) %d (dec)\n", (unsigned int)$w14, (int)$w14
printf "w2=%u x12=%#llx\n", (unsigned int)$w2, (unsigned long long)$x12
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
printf "x0=%#llx x2=%#llx x14=%#llx\n", (unsigned long long)$x0, (unsigned long long)$x2, (unsigned long long)$x14
printf "mem[x2..x2+64):\n"
x/8gx $x2
printf "mem[x14..x14+64):\n"
x/8gx $x14
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 19 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0E14
commands 19
printf "=== OE_FIRST_STORE ===\n"
printf "First store to x2=%#llx\n", (unsigned long long)$x2
printf "x2(now)=%#llx next store window mem[x2..]:\n", (unsigned long long)$x2
x/8gx $x2
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 20 (*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000 && ((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0E15
commands 20
printf "=== OE_FINAL_STORES ===\n"
printf "Final stores to x14=%#llx\n", (unsigned long long)$x14
printf "q4_re(v8): %f %f %f %f\n", $v8.s.f[0], $v8.s.f[1], $v8.s.f[2], $v8.s.f[3]
printf "q4_im(v9): %f %f %f %f\n", $v9.s.f[0], $v9.s.f[1], $v9.s.f[2], $v9.s.f[3]
printf "q5_re(v11): %f %f %f %f\n", $v11.s.f[0], $v11.s.f[1], $v11.s.f[2], $v11.s.f[3]
printf "q5_im(v10): %f %f %f %f\n", $v10.s.f[0], $v10.s.f[1], $v10.s.f[2], $v10.s.f[3]
printf "q6_re(v12): %f %f %f %f\n", $v12.s.f[0], $v12.s.f[1], $v12.s.f[2], $v12.s.f[3]
printf "q6_im(v13): %f %f %f %f\n", $v13.s.f[0], $v13.s.f[1], $v13.s.f[2], $v13.s.f[3]
printf "q7_re(v15): %f %f %f %f\n", $v15.s.f[0], $v15.s.f[1], $v15.s.f[2], $v15.s.f[3]
printf "q7_im(v14): %f %f %f %f\n", $v14.s.f[0], $v14.s.f[1], $v14.s.f[2], $v14.s.f[3]
set $pre14 = (unsigned long long)$x14 - 64
printf "mem[x14-64 .. x14):\n"
x/16gx $pre14

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

# EE_PRE_STORE_A (brk 0xEE0E)
catch signal SIGTRAP
condition 42 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0xEE0E)
commands 42
printf "=== EE_PRE_STORE_A ===\n"
printf "x2=%#llx x16=%#llx\n", (unsigned long long)$x2, (unsigned long long)$x16
printf "v0: %f %f %f %f\n", $v0.s.f[0], $v0.s.f[1], $v0.s.f[2], $v0.s.f[3]
printf "v1: %f %f %f %f\n", $v1.s.f[0], $v1.s.f[1], $v1.s.f[2], $v1.s.f[3]
printf "v2: %f %f %f %f\n", $v2.s.f[0], $v2.s.f[1], $v2.s.f[2], $v2.s.f[3]
printf "v3: %f %f %f %f\n", $v3.s.f[0], $v3.s.f[1], $v3.s.f[2], $v3.s.f[3]
set $pc = $pc + 4
continue
end

# EE_PRE_STORE_B (brk 0xEE0F)
catch signal SIGTRAP
condition 43 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0xEE0F)
commands 43
printf "=== EE_PRE_STORE_B ===\n"
printf "x2=%#llx x16=%#llx\n", (unsigned long long)$x2, (unsigned long long)$x16
printf "v14: %f %f %f %f\n", $v14.s.f[0], $v14.s.f[1], $v14.s.f[2], $v14.s.f[3]
printf "v15: %f %f %f %f\n", $v15.s.f[0], $v15.s.f[1], $v15.s.f[2], $v15.s.f[3]
printf "v10: %f %f %f %f\n", $v10.s.f[0], $v10.s.f[1], $v10.s.f[2], $v10.s.f[3]
printf "v11: %f %f %f %f\n", $v11.s.f[0], $v11.s.f[1], $v11.s.f[2], $v11.s.f[3]
printf "v8: %f %f %f %f\n", $v8.s.f[0], $v8.s.f[1], $v8.s.f[2], $v8.s.f[3]
printf "v9: %f %f %f %f\n", $v9.s.f[0], $v9.s.f[1], $v9.s.f[2], $v9.s.f[3]
printf "v28: %f %f %f %f\n", $v28.s.f[0], $v28.s.f[1], $v28.s.f[2], $v28.s.f[3]
printf "v29: %f %f %f %f\n", $v29.s.f[0], $v29.s.f[1], $v29.s.f[2], $v29.s.f[3]
set $pc = $pc + 4
continue
end

# OE_PRE_STORE_Q01 (brk 0x0E12)
catch signal SIGTRAP
condition 44 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0E12)
commands 44
printf "=== OE_PRE_STORE_Q01 ===\n"
printf "x2=%#llx\n", (unsigned long long)$x2
printf "q0: %f %f %f %f\n", $v0.s.f[0], $v0.s.f[1], $v0.s.f[2], $v0.s.f[3]
printf "q1: %f %f %f %f\n", $v1.s.f[0], $v1.s.f[1], $v1.s.f[2], $v1.s.f[3]
set $pc = $pc + 4
continue
end

# OE_PRE_STORE_Q23 (brk 0x0E13)
catch signal SIGTRAP
condition 45 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0E13)
commands 45
printf "=== OE_PRE_STORE_Q23 ===\n"
printf "x2=%#llx\n", (unsigned long long)$x2
printf "q2: %f %f %f %f\n", $v2.s.f[0], $v2.s.f[1], $v2.s.f[2], $v2.s.f[3]
printf "q3: %f %f %f %f\n", $v3.s.f[0], $v3.s.f[1], $v3.s.f[2], $v3.s.f[3]
set $pc = $pc + 4
continue
end



# EE_Q1_BUILT (brk 0xEE10)
catch signal SIGTRAP
condition 46 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0xEE10)
commands 46
printf "=== EE_Q1_BUILT ===\n"
printf "q1 re v2: %f %f %f %f\n", $v2.s.f[0], $v2.s.f[1], $v2.s.f[2], $v2.s.f[3]
printf "q1 im v3: %f %f %f %f\n", $v3.s.f[0], $v3.s.f[1], $v3.s.f[2], $v3.s.f[3]
set $pc = $pc + 4
continue
end

# EE_Q0_LOADED (brk 0xEE11)
catch signal SIGTRAP
condition 47 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0xEE11)
commands 47
printf "=== EE_Q0_LOADED ===\n"
printf "q0 re v0: %f %f %f %f\n", $v0.s.f[0], $v0.s.f[1], $v0.s.f[2], $v0.s.f[3]
printf "q0 im v1: %f %f %f %f\n", $v1.s.f[0], $v1.s.f[1], $v1.s.f[2], $v1.s.f[3]
set $pc = $pc + 4
continue
end

# EE_Q0Q2_UPDATED (brk 0xEE12)
catch signal SIGTRAP
condition 48 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0xEE12)
commands 48
printf "=== EE_Q0Q2_UPDATED ===\n"
printf "q0: %f %f %f %f\n", $v0.s.f[0], $v0.s.f[1], $v0.s.f[2], $v0.s.f[3]
printf "q1: %f %f %f %f\n", $v2.s.f[0], $v2.s.f[1], $v2.s.f[2], $v2.s.f[3]
printf "q2: %f %f %f %f\n", $v4.s.f[0], $v4.s.f[1], $v4.s.f[2], $v4.s.f[3]
printf "q3: %f %f %f %f\n", $v6.s.f[0], $v6.s.f[1], $v6.s.f[2], $v6.s.f[3]
set $pc = $pc + 4
continue
end

# EE_DLANE_PARTIALS (brk 0xEE13)
catch signal SIGTRAP
condition 49 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0xEE13)
commands 49
printf "=== EE_DLANE_PARTIALS ===\n"
printf "q0_re(v0): %f %f %f %f\n", $v0.s.f[0], $v0.s.f[1], $v0.s.f[2], $v0.s.f[3]
printf "q0_im(v1): %f %f %f %f\n", $v1.s.f[0], $v1.s.f[1], $v1.s.f[2], $v1.s.f[3]
printf "q1_re(v2): %f %f %f %f\n", $v2.s.f[0], $v2.s.f[1], $v2.s.f[2], $v2.s.f[3]
printf "q1_im(v3): %f %f %f %f\n", $v3.s.f[0], $v3.s.f[1], $v3.s.f[2], $v3.s.f[3]
printf "q2_re(v4): %f %f %f %f\n", $v4.s.f[0], $v4.s.f[1], $v4.s.f[2], $v4.s.f[3]
printf "q2_im(v5): %f %f %f %f\n", $v5.s.f[0], $v5.s.f[1], $v5.s.f[2], $v5.s.f[3]
printf "v6: %f %f %f %f\n", $v6.s.f[0], $v6.s.f[1], $v6.s.f[2], $v6.s.f[3]
printf "v10: %f %f %f %f\n", $v10.s.f[0], $v10.s.f[1], $v10.s.f[2], $v10.s.f[3]
printf "v12: %f %f %f %f\n", $v12.s.f[0], $v12.s.f[1], $v12.s.f[2], $v12.s.f[3]
set $pc = $pc + 4
continue
end

# EE_BFLY2_DONE (brk 0xEE14)
catch signal SIGTRAP
condition 50 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0xEE14)
commands 50
printf "=== EE_BFLY2_DONE ===\n"
printf "q4_re(v14): %f %f %f %f\n", $v14.s.f[0], $v14.s.f[1], $v14.s.f[2], $v14.s.f[3]
printf "q4_im(v15): %f %f %f %f\n", $v15.s.f[0], $v15.s.f[1], $v15.s.f[2], $v15.s.f[3]
printf "q11_re(v22): %f %f %f %f\n", $v22.s.f[0], $v22.s.f[1], $v22.s.f[2], $v22.s.f[3]
printf "q11_im(v23): %f %f %f %f\n", $v23.s.f[0], $v23.s.f[1], $v23.s.f[2], $v23.s.f[3]
printf "q12_re(v24): %f %f %f %f\n", $v24.s.f[0], $v24.s.f[1], $v24.s.f[2], $v24.s.f[3]
printf "q12_im(v25): %f %f %f %f\n", $v25.s.f[0], $v25.s.f[1], $v25.s.f[2], $v25.s.f[3]
set $pc = $pc + 4
continue
end

# EE_AFTER_LD2_X8 (brk 0xEE16)
catch signal SIGTRAP
condition 51 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0xEE16)
commands 51
printf "=== EE_AFTER_LD2_X8 ===\n"
printf "x8 (post-increment)=%#llx\n", (unsigned long long)$x8
set $pre = (unsigned long long)$x8 - 32
printf "Memory [x8-32 .. x8):\n"
x/8gx $pre
printf "v26: %f %f %f %f\n", $v26.s.f[0], $v26.s.f[1], $v26.s.f[2], $v26.s.f[3]
printf "v27: %f %f %f %f\n", $v27.s.f[0], $v27.s.f[1], $v27.s.f[2], $v27.s.f[3]
set $pc = $pc + 4
continue
end

# OE_SECOND_LOADS_A/B/C
catch signal SIGTRAP
condition 52 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0E1B)
commands 52
printf "=== OE_SECOND_LOADS_A (x9) ===\n"
printf "v0: %f %f %f %f\n", $v0.s.f[0], $v0.s.f[1], $v0.s.f[2], $v0.s.f[3]
printf "v1: %f %f %f %f\n", $v1.s.f[0], $v1.s.f[1], $v1.s.f[2], $v1.s.f[3]
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 53 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0E1C)
commands 53
printf "=== OE_SECOND_LOADS_B (x8) ===\n"
printf "v26: %f %f %f %f\n", $v26.s.f[0], $v26.s.f[1], $v26.s.f[2], $v26.s.f[3]
printf "v27: %f %f %f %f\n", $v27.s.f[0], $v27.s.f[1], $v27.s.f[2], $v27.s.f[3]
set $pc = $pc + 4
continue
end

catch signal SIGTRAP
condition 54 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0E1D)
commands 54
printf "=== OE_SECOND_LOADS_C (x7) ===\n"
printf "v28: %f %f %f %f\n", $v28.s.f[0], $v28.s.f[1], $v28.s.f[2], $v28.s.f[3]
printf "v29: %f %f %f %f\n", $v29.s.f[0], $v29.s.f[1], $v29.s.f[2], $v29.s.f[3]
set $pc = $pc + 4
continue
end

# OE_PRE_TWIDDLE (brk 0x0E1E)
catch signal SIGTRAP
condition 55 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0E1E)
commands 55
printf "=== OE_PRE_TWIDDLE ===\n"
printf "v4: %f %f %f %f\n", $v4.s.f[0], $v4.s.f[1], $v4.s.f[2], $v4.s.f[3]
printf "v5: %f %f %f %f\n", $v5.s.f[0], $v5.s.f[1], $v5.s.f[2], $v5.s.f[3]
printf "v6: %f %f %f %f\n", $v6.s.f[0], $v6.s.f[1], $v6.s.f[2], $v6.s.f[3]
printf "v7: %f %f %f %f\n", $v7.s.f[0], $v7.s.f[1], $v7.s.f[2], $v7.s.f[3]
set $pc = $pc + 4
continue
end

# OE_PRE_TRN_Q0Q12 (brk 0x0E20)
catch signal SIGTRAP
condition 56 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0E20)
commands 56
printf "=== OE_PRE_TRN_Q0Q12 ===\n"
printf "v12 (from d24,d25): %f %f %f %f\n", $v12.s.f[0], $v12.s.f[1], $v12.s.f[2], $v12.s.f[3]
printf "v0: %f %f %f %f\n", $v0.s.f[0], $v0.s.f[1], $v0.s.f[2], $v0.s.f[3]
set $pc = $pc + 4
continue
end

# OE_PRE_TRN_Q1Q13 (brk 0x0E21)
catch signal SIGTRAP
condition 57 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0E21)
commands 57
printf "=== OE_PRE_TRN_Q1Q13 ===\n"
printf "v13 (from d26,d27): %f %f %f %f\n", $v13.s.f[0], $v13.s.f[1], $v13.s.f[2], $v13.s.f[3]
printf "v1: %f %f %f %f\n", $v1.s.f[0], $v1.s.f[1], $v1.s.f[2], $v1.s.f[3]
set $pc = $pc + 4
continue
end

# OE_PRE_TRN_Q2Q14 (brk 0x0E22)
catch signal SIGTRAP
condition 58 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0E22)
commands 58
printf "=== OE_PRE_TRN_Q2Q14 ===\n"
printf "v14 (from d28,d29): %f %f %f %f\n", $v14.s.f[0], $v14.s.f[1], $v14.s.f[2], $v14.s.f[3]
printf "v4: %f %f %f %f\n", $v4.s.f[0], $v4.s.f[1], $v4.s.f[2], $v4.s.f[3]
set $pc = $pc + 4
continue
end

# OE_TWIDDLES (brk 0x0E23)
catch signal SIGTRAP
condition 59 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0E23)
commands 59
printf "=== OE_TWIDDLES ===\n"
printf "v24 (tw_re): %f %f %f %f\n", $v24.s.f[0], $v24.s.f[1], $v24.s.f[2], $v24.s.f[3]
printf "v25 (tw_im): %f %f %f %f\n", $v25.s.f[0], $v25.s.f[1], $v25.s.f[2], $v25.s.f[3]
set $pc = $pc + 4
continue
end

# OE_PRE_TWIDDLE_TRANSPOSE (brk 0x0E24)
catch signal SIGTRAP
condition 60 ((*(unsigned int*)$pc & 0xffe0001f) == 0xd4200000) && (((*(unsigned int*)$pc >> 5) & 0xffff) == 0x0E24)
commands 60
printf "=== OE_PRE_TWIDDLE_TRANSPOSE ===\n"
printf "q11_re(v22): %f %f %f %f\n", $v22.s.f[0], $v22.s.f[1], $v22.s.f[2], $v22.s.f[3]
printf "q11_im(v23): %f %f %f %f\n", $v23.s.f[0], $v23.s.f[1], $v23.s.f[2], $v23.s.f[3]
printf "q9_re(v18): %f %f %f %f\n", $v18.s.f[0], $v18.s.f[1], $v18.s.f[2], $v18.s.f[3]
printf "q9_im(v19): %f %f %f %f\n", $v19.s.f[0], $v19.s.f[1], $v19.s.f[2], $v19.s.f[3]
printf "q10_re(v20): %f %f %f %f\n", $v20.s.f[0], $v20.s.f[1], $v20.s.f[2], $v20.s.f[3]
printf "q10_im(v21): %f %f %f %f\n", $v21.s.f[0], $v21.s.f[1], $v21.s.f[2], $v21.s.f[3]
printf "q8_re(v16): %f %f %f %f\n", $v16.s.f[0], $v16.s.f[1], $v16.s.f[2], $v16.s.f[3]
printf "q8_im(v17): %f %f %f %f\n", $v17.s.f[0], $v17.s.f[1], $v17.s.f[2], $v17.s.f[3]
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
