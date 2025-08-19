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
  printf "q13 (d26,d27) = %016llx %016llx\n", (unsigned long long)$d26, (unsigned long long)$d27
  set $pc = $pc + 4
  continue
end

# EE_TWIDDLES_LOADED (0xEE02)
catch signal SIGTRAP
condition 3 (((*(unsigned int*)$pc & 0xFFF000F0) == 0xE1200070) && (((*(unsigned int*)$pc >> 4) & 0xFFF0) | (*(unsigned int*)$pc & 0x0F)) == 0xEE02)
commands 3
  silent
  printf "=== EE_TWIDDLES_LOADED ===\n"
  printf "Twiddle q8 (d16,d17) = %016llx %016llx\n", (unsigned long long)$d16, (unsigned long long)$d17
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

# SIGSEGV catcher for convenience
catch signal SIGSEGV
commands
  printf "=== SIGSEGV ===\n"
  printf "pc=%#lx lr=%#lx sp=%#lx\n", (unsigned long)$pc, (unsigned long)$lr, (unsigned long)$sp
  x/8i $pc-16
  x/8wx $sp
  bt
end


