set architecture arm
set pagination off
set disassemble-next-line on
target remote :12346

# EE_ENTRY (0xEE00)
catch signal SIGTRAP
condition 1 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0xEE00)
commands 1
  silent
  printf "=== EE_ENTRY ===\n"
  printf "Entry params: r0=%#lx r2=%#lx r11=%#lx r12=%#lx\n", (unsigned long)$r0, (unsigned long)$r2, (unsigned long)$r11, (unsigned long)$r12
  printf "Stream ptrs: r3=%#lx r4=%#lx r5=%#lx r6=%#lx\n", (unsigned long)$r3, (unsigned long)$r4, (unsigned long)$r5, (unsigned long)$r6
  printf "Stream ptrs: r7=%#lx r8=%#lx r9=%#lx r10=%#lx\n", (unsigned long)$r7, (unsigned long)$r8, (unsigned long)$r9, (unsigned long)$r10
  set $pc = $pc + 4
  continue
end

# EE_AFTER_LD2_X8 (0xEE16)
catch signal SIGTRAP
condition 2 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0xEE16)
commands 2
  silent
  printf "=== EE_AFTER_LD2_X8 ===\n"
  printf "r8 (post-increment)=%#lx\n", (unsigned long)$r8
  set $pre = (unsigned long)$r8 - 32
  printf "Memory [r8-32 .. r8):\n"
  x/8wx $pre
  printf "q13 (d26,d27) = %g %g\n", (double)$d26, (double)$d27
  set $pc = $pc + 4
  continue
end

# EE_TWIDDLES_LOADED (0xEE02)
catch signal SIGTRAP
condition 3 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0xEE02)
commands 3
  silent
  printf "=== EE_TWIDDLES_LOADED ===\n"
  printf "Twiddle q8 lanes (s16..s19): %f %f %f %f\n", $s16, $s17, $s18, $s19
  printf "Twiddle scalars (re,im): %f %f\n", $s16, $s18
  set $pc = $pc + 4
  continue
end

# EE_LOOP_START (0xEE03)
catch signal SIGTRAP
condition 4 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0xEE03)
commands 4
  silent
  printf "=== EE_LOOP_START (iter) ===\n"
  printf "Loop counter r11=%#lx\n", (unsigned long)$r11
  printf "Stream pointers: r3=%#lx r4=%#lx r5=%#lx r6=%#lx r7=%#lx r8=%#lx r9=%#lx r10=%#lx\n", (unsigned long)$r3, (unsigned long)$r4, (unsigned long)$r5, (unsigned long)$r6, (unsigned long)$r7, (unsigned long)$r8, (unsigned long)$r9, (unsigned long)$r10
  set $pc = $pc + 4
  continue
end

# EE_DATA_LOADED (0xEE04)
catch signal SIGTRAP
condition 5 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0xEE04)
commands 5
  silent
  printf "=== EE_DATA_LOADED ===\n"
  printf "Decremented r11=%#lx\n", (unsigned long)$r11
  # Mirror AArch64 data visibility: show deinterleaved loads
  # q15 (from r10), q13 (from r8), q14 (from r7)
  printf "q15 (d30,d31): %f %f  q13 (d26,d27): %f %f  q14 (d28,d29): %f %f\n", (double)$d30, (double)$d31, (double)$d26, (double)$d27, (double)$d28, (double)$d29
  # q9 (from r4), q10 (from r3), q11 (from r6), q12 (from r5)
  printf "q9(d18,d19): %f %f  q10(d20,d21): %f %f  q11(d22,d23): %f %f  q12(d24,d25): %f %f\n", (double)$d18, (double)$d19, (double)$d20, (double)$d21, (double)$d22, (double)$d23, (double)$d24, (double)$d25
  set $pc = $pc + 4
  continue
end

# EE_OFFSET1_LOADED (0xEE06)
catch signal SIGTRAP
condition 6 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0xEE06)
commands 6
  silent
  printf "=== EE_OFFSET1_LOADED ===\n"
  printf "First offset r2=%#lx (%lu)\n", (unsigned long)$r2, (unsigned long)$r2
  printf "r12=%#lx\n", (unsigned long)$r12
  set $pc = $pc + 4
  continue
end

# EE_OFFSET2_LOADED (0xEE07)
catch signal SIGTRAP
condition 7 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0xEE07)
commands 7
  silent
  printf "=== EE_OFFSET2_LOADED ===\n"
  printf "Second offset lr=%#lx (%lu)\n", (unsigned long)$lr, (unsigned long)$lr
  printf "r12=%#lx\n", (unsigned long)$r12
  set $pc = $pc + 4
  continue
end

# EE_ADDR1_CALC (0xEE08)
catch signal SIGTRAP
condition 8 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0xEE08)
commands 8
  silent
  printf "=== EE_ADDR1_CALC ===\n"
  set $off2_1 = ((unsigned long)$r2 - (unsigned long)$r0) >> 2
  printf "Base r0=%#lx, r2=%#lx => off2_1=%lu\n", (unsigned long)$r0, (unsigned long)$r2, (unsigned long)$off2_1
  x/8wx $r2
  set $pc = $pc + 4
  continue
end

# EE_ADDR2_CALC (0xEE09)
catch signal SIGTRAP
condition 9 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0xEE09)
commands 9
  silent
  printf "=== EE_ADDR2_CALC ===\n"
  set $off2_2 = ((unsigned long)$lr - (unsigned long)$r0) >> 2
  printf "Base r0=%#lx, lr=%#lx => off2_2=%lu\n", (unsigned long)$r0, (unsigned long)$lr, (unsigned long)$off2_2
  x/8wx $lr
  set $pc = $pc + 4
  continue
end

# EE_STORE1 (0xEE0A)
catch signal SIGTRAP
condition 10 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0xEE0A)
commands 10
  silent
  printf "=== EE_STORE1 ===\n"
  printf "About to store to r2=%#lx lr=%#lx\n", (unsigned long)$r2, (unsigned long)$lr
  printf "q0 (4 floats): %f %f %f %f\n", $s0, $s1, $s2, $s3
  printf "q1 (4 floats): %f %f %f %f\n", $s4, $s5, $s6, $s7
  # Show memory windows around first destination like AArch64 script
  set $r2_prev = (unsigned long)$r2 - 32
  printf "mem[r2-32 .. r2):\n"
  x/8wx $r2_prev
  printf "mem[r2 .. r2+32):\n"
  x/8wx $r2
  set $pc = $pc + 4
  continue
end

# EE_STORE2 (0xEE0B)
catch signal SIGTRAP
condition 11 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0xEE0B)
commands 11
  silent
  printf "=== EE_STORE2 ===\n"
  printf "Storing final to r2=%#lx lr=%#lx\n", (unsigned long)$r2, (unsigned long)$lr
  set $lr_prev = (unsigned long)$lr - 64
  printf "mem[lr-64 .. lr):\n"
  x/16wx $lr_prev
  set $pc = $pc + 4
  continue
end


# EE_FUNCTION_EXIT (0xEE0D)
catch signal SIGTRAP
condition 12 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0xEE0D)
commands 12
  silent
  printf "=== EE_FUNCTION_EXIT ===\n"
  printf "Final state r0=%#lx r2=%#lx r12=%#lx\n", (unsigned long)$r0, (unsigned long)$r2, (unsigned long)$r12
  printf "Streams r3=%#lx r4=%#lx r5=%#lx r6=%#lx r7=%#lx r8=%#lx r9=%#lx r10=%#lx\n", (unsigned long)$r3,(unsigned long)$r4,(unsigned long)$r5,(unsigned long)$r6,(unsigned long)$r7,(unsigned long)$r8,(unsigned long)$r9,(unsigned long)$r10
  printf "Loop counter r11=%#lx\n", (unsigned long)$r11
  set $pc = $pc + 4
  continue
end

# EE_Q1_BUILT (0xEE10)
catch signal SIGTRAP
condition 13 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0xEE10)
commands 13
  silent
  printf "=== EE_Q1_BUILT ===\n"
  printf "q1 (4 floats): %f %f %f %f\n", $s4, $s5, $s6, $s7
  set $pc = $pc + 4
  continue
end

# EE_Q0_LOADED (0xEE11)
catch signal SIGTRAP
condition 14 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0xEE11)
commands 14
  silent
  printf "=== EE_Q0_LOADED ===\n"
  printf "q0 (4 floats): %f %f %f %f\n", $s0, $s1, $s2, $s3
  set $pc = $pc + 4
  continue
end

# EE_Q0Q2_UPDATED (0xEE12)
catch signal SIGTRAP
condition 15 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0xEE12)
commands 15
  silent
  printf "=== EE_Q0Q2_UPDATED ===\n"
  printf "q0 (4 floats): %f %f %f %f\n", $s0, $s1, $s2, $s3
  printf "q1 (4 floats): %f %f %f %f\n", $s4, $s5, $s6, $s7
  printf "q2 (4 floats): %f %f %f %f\n", $s8, $s9, $s10, $s11
  set $pc = $pc + 4
  continue
end

# EE_DLANE_PARTIALS (0xEE13)
catch signal SIGTRAP
condition 16 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0xEE13)
commands 16
  silent
  printf "=== EE_DLANE_PARTIALS ===\n"
  printf "q0 (4 floats): %f %f %f %f\n", $s0, $s1, $s2, $s3
  printf "q1 (4 floats): %f %f %f %f\n", $s4, $s5, $s6, $s7
  printf "q2 (4 floats): %f %f %f %f\n", $s8, $s9, $s10, $s11
  printf "q3 (4 floats): %f %f %f %f\n", $s12, $s13, $s14, $s15
  # Also expose intermediate d-lane temporaries to match AArch64 visibility
  printf "d10=%f d11=%f d12=%f d13=%f\n", (double)$d10, (double)$d11, (double)$d12, (double)$d13
  set $pc = $pc + 4
  continue
end

# EE_BFLY2_DONE (0xEE14)
catch signal SIGTRAP
condition 17 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0xEE14)
commands 17
  silent
  printf "=== EE_BFLY2_DONE ===\n"
  printf "q4  (4 floats): %f %f %f %f\n",  $s16, $s17, $s18, $s19
  printf "q11 %f %f\n", $d22, $d23
  printf "q12 %f %f\n", $d24, $d25
  set $pc = $pc + 4
  continue
end

# =============================
# OE (neon_oe) BRK handlers
# =============================

# OE_ENTRY (0x0E00)
catch signal SIGTRAP
condition 18 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0x0E00)
commands 18
  silent
  printf "=== OE_ENTRY ===\n"
  printf "Entry params: r0=%#lx r11=%#lx r12=%#lx\n", (unsigned long)$r0, (unsigned long)$r11, (unsigned long)$r12
  printf "Stream ptrs: r3=%#lx r4=%#lx r5=%#lx r6=%#lx r7=%#lx r8=%#lx r9=%#lx r10=%#lx\n", (unsigned long)$r3,(unsigned long)$r4,(unsigned long)$r5,(unsigned long)$r6,(unsigned long)$r7,(unsigned long)$r8,(unsigned long)$r9,(unsigned long)$r10
  set $pc = $pc + 4
  continue
end

# OE_FINAL_STORES (0x0E15)
catch signal SIGTRAP
condition 19 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0x0E15)
commands 19
  silent
  printf "=== OE_FINAL_STORES ===\n"
  printf "Final stores to lr=%#lx\n", (unsigned long)$lr
  printf "q4 (s16..s19): %f %f %f %f\n", $s16, $s17, $s18, $s19
  printf "q5 (s20..s23): %f %f %f %f\n", $s20, $s21, $s22, $s23
  printf "q6 (s24..s27): %f %f %f %f\n", $s24, $s25, $s26, $s27
  printf "q7 (s28..s31): %f %f %f %f\n", $s28, $s29, $s30, $s31
  set $pre14 = (unsigned long)$lr - 64
  printf "mem[lr-64 .. lr):\n"
  x/16wx $pre14
  set $pc = $pc + 4
  continue
end

# OE_INITIAL_LOADS (0x0E02)
catch signal SIGTRAP
condition 20 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0x0E02)
commands 20
  silent
  printf "=== OE_INITIAL_LOADS ===\n"
  printf "q8(d16,d17)=%016llx %016llx q10(d20,d21)=%016llx %016llx\n", (unsigned long long)$d16,(unsigned long long)$d17,(unsigned long long)$d20,(unsigned long long)$d21
  printf "q11(d22,d23)=%016llx %016llx q13(d26,d27)=%016llx %016llx q15(d30,d31)=%016llx %016llx\n", (unsigned long long)$d22,(unsigned long long)$d23,(unsigned long long)$d26,(unsigned long long)$d27,(unsigned long long)$d30,(unsigned long long)$d31
  printf "q8  (s16..s19): %f %f %f %f\n",  $s16, $s17, $s18, $s19
  printf "q10 (s20..s23): %f %f %f %f\n",  $s20, $s21, $s22, $s23
  printf "q11 (d22,d23):  %f %f\n",       $d22, $d23
  printf "q13 (d26,d27):  %f %f\n",       $d26, $d27
  printf "q15 (d30,d31):  %f %f\n",       $d30, $d31
  set $pc = $pc + 4
  continue
end

# OE_OFF2_LOADED (0x0E90)
catch signal SIGTRAP
condition 21 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0x0E90)
commands 21
  silent
  printf "=== OE_OFF2_LOADED ===\n"
  printf "First offset r2=%#lx (%lu) r12=%#lx\n", (unsigned long)$r2, (unsigned long)$r2, (unsigned long)$r12
  set $pc = $pc + 4
  continue
end

# OE_ADDRS_READY (0x0E17)
catch signal SIGTRAP
condition 22 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0x0E17)
commands 22
  silent
  printf "=== OE_ADDRS_READY ===\n"
  set $off2_a = ((unsigned long)$r2  - (unsigned long)$r0) >> 2
  set $off2_b = ((unsigned long)$lr  - (unsigned long)$r0) >> 2
  printf "r2=%#lx lr=%#lx => off2_a=%lu off2_b=%lu\n", (unsigned long)$r2, (unsigned long)$lr, (unsigned long)$off2_a, (unsigned long)$off2_b
  printf "mem[r2..r2+32):\n"
  x/8wx $r2
  printf "mem[lr..lr+32):\n"
  x/8wx $lr
  set $pc = $pc + 4
  continue
end

# OE_PRE_TRN_Q0Q12 (0x0E20)
catch signal SIGTRAP
condition 23 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0x0E20)
commands 23
  silent
  printf "=== OE_PRE_TRN_Q0Q12 ===\n"
  printf "q0(d0,d1)=%016llx %016llx q12(d24,d25)=%016llx %016llx\n", (unsigned long long)$d0,(unsigned long long)$d1,(unsigned long long)$d24,(unsigned long long)$d25
  printf "q0  (s0..s3):   %f %f %f %f\n", $s0, $s1, $s2, $s3
  printf "q12 (d24,d25):  %f %f\n",      $d24, $d25
  set $pc = $pc + 4
  continue
end

# OE_PRE_TRN_Q1Q13 (0x0E26)
catch signal SIGTRAP
condition 24 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0x0E26E26)
commands 24
  silent
  printf "=== OE_PRE_TRN_Q1Q13 ===\n"
  printf "q1(d2,d3)=%016llx %016llx q13(d26,d27)=%016llx %016llx\n", (unsigned long long)$d2,(unsigned long long)$d3,(unsigned long long)$d26,(unsigned long long)$d27
  printf "q1  (s4..s7):   %f %f %f %f\n", $s4, $s5, $s6, $s7
  printf "q13 (d26,d27):  %f %f\n",      $d26, $d27
  set $pc = $pc + 4
  continue
end

# OE_TWIDDLES (0x0E23)
catch signal SIGTRAP
condition 25 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0x0E23)
commands 25
  silent
  printf "=== OE_TWIDDLES ===\n"
  printf "d24(re)=%016llx d25(im)=%016llx\n", (unsigned long long)$d24, (unsigned long long)$d25
  printf "tw_re(d24)=%f tw_im(d25)=%f\n", $d24, $d25
  set $pc = $pc + 4
  continue
end

# OE_PRE_STORE_Q01 (0x0E12)
catch signal SIGTRAP
condition 26 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0x0E12)
commands 26
  silent
  printf "=== OE_PRE_STORE_Q01 ===\n"
  printf "r2=%#lx q0: %f %f %f %f q1: %f %f %f %f\n", (unsigned long)$r2, $s0,$s1,$s2,$s3, $s4,$s5,$s6,$s7
  x/8wx $r2
  set $pc = $pc + 4
  continue
end

# OE_FIRST_STORE (0x0E14)
catch signal SIGTRAP
condition 27 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0x0E14)
commands 27
  silent
  printf "=== OE_FIRST_STORE ===\n"
  printf "First store to r2=%#lx\n", (unsigned long)$r2
  set $r2_prev = (unsigned long)$r2 - 32
  x/8wx $r2_prev
  x/8wx $r2
  set $pc = $pc + 4
  continue
end

# OE_SECOND_LOADS_A (0x0E1B)
catch signal SIGTRAP
condition 28 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0x0E1B)
commands 28
  silent
  printf "=== OE_SECOND_LOADS_A (r9) ===\n"
  printf "q0: %f %f %f %f q1: %f %f %f %f\n", $s0,$s1,$s2,$s3, $s4,$s5,$s6,$s7
  set $pc = $pc + 4
  continue
end

# OE_SECOND_LOADS_B (0x0E1C)
catch signal SIGTRAP
condition 29 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0x0E1C)
commands 29
  silent
  printf "=== OE_SECOND_LOADS_B (r8) ===\n"
  printf "q13(d26,d27)=%016llx %016llx\n", (unsigned long long)$d26,(unsigned long long)$d27
  printf "q13 (d26,d27): %f %f\n", $d26, $d27
  set $pc = $pc + 4
  continue
end

# OE_SECOND_LOADS_C (0x0E1D)
catch signal SIGTRAP
condition 30 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0x0E1D)
commands 30
  silent
  printf "=== OE_SECOND_LOADS_C (r7) ===\n"
  printf "q14(d28,d29)=%016llx %016llx\n", (unsigned long long)$d28,(unsigned long long)$d29
  printf "q14 (d28,d29): %f %f\n", $d28, $d29
  set $pc = $pc + 4
  continue
end

# OE_PRE_TRN_Q2Q14 (0x0E22)
catch signal SIGTRAP
condition 31 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0x0E22)
commands 31
  silent
  printf "=== OE_PRE_TRN_Q2Q14 ===\n"
  printf "q2(d4,d5)=%016llx %016llx q14(d28,d29)=%016llx %016llx\n", (unsigned long long)$d4,(unsigned long long)$d5,(unsigned long long)$d28,(unsigned long long)$d29
  printf "q2  (s8..s11):  %f %f %f %f\n", $s8, $s9, $s10, $s11
  printf "q14 (d28,d29):  %f %f\n",      $d28, $d29
  set $pc = $pc + 4
  continue
end

# OE_PRE_STORE_Q23 (0x0E13)
catch signal SIGTRAP
condition 32 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0x0E13)
commands 32
  silent
  printf "=== OE_PRE_STORE_Q23 ===\n"
  printf "r2=%#lx q2: %f %f %f %f q3: %f %f %f %f\n", (unsigned long)$r2, $s8,$s9,$s10,$s11, $s12,$s13,$s14,$s15
  x/8wx $r2
  set $pc = $pc + 4
  continue
end

# OE_PRE_TWIDDLE (0x0E1E)
catch signal SIGTRAP
condition 33 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0x0E1E)
commands 33
  silent
  printf "=== OE_PRE_TWIDDLE ===\n"
  printf "q4: %f %f %f %f q5: %f %f %f %f q6: %f %f %f %f q7: %f %f %f %f\n", $s16,$s17,$s18,$s19, $s20,$s21,$s22,$s23, $s24,$s25,$s26,$s27, $s28,$s29,$s30,$s31
  printf "q11(d22,d23)=%016llx %016llx q9(d18,d19)=%016llx %016llx q10(d20,d21)=%016llx %016llx q8(d16,d17)=%016llx %016llx\n", (unsigned long long)$d22,(unsigned long long)$d23,(unsigned long long)$d18,(unsigned long long)$d19,(unsigned long long)$d20,(unsigned long long)$d21,(unsigned long long)$d16,(unsigned long long)$d17
  printf "q11: %f %f  q9: %f %f  q10: %f %f  q8: %f %f\n", $d22, $d23, $d18, $d19, $d20, $d21, $d16, $d17
  set $pc = $pc + 4
  continue
end

# OE_PRE_FINAL_STORES (0x0E16)
catch signal SIGTRAP
condition 34 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0x0E16)
commands 34
  silent
  printf "=== OE_PRE_FINAL_STORES ===\n"
  printf "lr=%#lx\n", (unsigned long)$lr
  printf "q4: %f %f %f %f q5: %f %f %f %f q6: %f %f %f %f q7: %f %f %f %f\n", $s16,$s17,$s18,$s19, $s20,$s21,$s22,$s23, $s24,$s25,$s26,$s27, $s28,$s29,$s30,$s31
  set $pc = $pc + 4
  continue
end

# SIGSEGV catcher for convenience
catch signal SIGSEGV
commands
  printf "=== SIGSEGV ===\n"
  printf "pc=%#lx lr=%#lx sp=%#lx\n", (unsigned long)$pc, (unsigned long)$lr, (unsigned long)$sp
  x/8i $pc-16
  x/8wx $sp
  bt
end
