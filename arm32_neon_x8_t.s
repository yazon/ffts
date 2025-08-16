  .align 4
#ifdef __APPLE__
  .globl  _neon_x8_t
_neon_x8_t:
#else
  .globl  neon_x8_t
neon_x8_t:
#endif
  mov      r11, #0
  add      r3, r0, #0           @ data0
  add      r5, r0, r1, lsl #1   @ data2
  add      r4, r0, r1           @ data1
  add      r7, r5, r1, lsl #1   @ data4
  add      r6, r5, r1           @ data3
  add      r9, r7, r1, lsl #1   @ data6
  add      r8, r7, r1           @ data5
  add      r10, r9, r1          @ data7
  add      r12, r2, #0          @ LUT

  sub      r11, r11, r1, lsr #5
1:
  vld1.32  {q2,  q3},  [r12, :64]!
  vld1.32  {q14, q15}, [r6, :64]
  vld1.32  {q10, q11}, [r5, :64]
  adds     r11, r11, #1
  vmul.f32 q12, q15, q2
  vmul.f32 q8,  q14, q3
  vmul.f32 q13, q14, q2
  vmul.f32 q9,  q10, q3
  vmul.f32 q1,  q10, q2
  vmul.f32 q0,  q11, q2
  vmul.f32 q14, q11, q3
  vmul.f32 q15, q15, q3
  vld1.32  {q2,  q3},  [r12, :64]!
  vsub.f32 q10, q12, q8
  vadd.f32 q11, q0,  q9
  vadd.f32 q8,  q15, q13
  vld1.32  {q12, q13}, [r4, :64]
  vsub.f32 q9,  q1,  q14
  vsub.f32 q15, q11, q10
  vsub.f32 q14, q9,  q8
  vsub.f32 q4,  q12, q15
  vadd.f32 q6,  q12, q15
  vadd.f32 q5,  q13, q14
  vsub.f32 q7,  q13, q14
  vld1.32  {q14, q15}, [r9, :64]
  vld1.32  {q12, q13}, [r7, :64]
  vmul.f32 q1,  q14, q2
  vmul.f32 q0,  q14, q3
  vst1.32  {q4,  q5},  [r4, :64]
  vmul.f32 q14, q15, q3
  vmul.f32 q4,  q15, q2
  vadd.f32 q15, q9,  q8
  vst1.32  {q6,  q7},  [r6, :64]
  vmul.f32 q8,  q12, q3
  vmul.f32 q5,  q13, q3
  vmul.f32 q12, q12, q2
  vmul.f32 q9,  q13, q2
  vadd.f32 q14, q14, q1
  vsub.f32 q13, q4,  q0
  vadd.f32 q0,  q9,  q8
  vld1.32  {q8,  q9},  [r3, :64]
  vadd.f32 q1,  q11, q10
  vsub.f32 q12, q12, q5
  vadd.f32 q11, q8,  q15
  vsub.f32 q8,  q8,  q15
  vadd.f32 q2,  q12, q14
  vsub.f32 q10, q0,  q13
  vadd.f32 q15, q0,  q13
  vadd.f32 q13, q9,  q1
  vsub.f32 q9,  q9,  q1
  vsub.f32 q12, q12, q14
  vadd.f32 q0,  q11, q2
  vadd.f32 q1,  q13, q15
  vsub.f32 q4,  q11, q2
  vsub.f32 q2,  q8,  q10
  vadd.f32 q3,  q9,  q12
  vst2.32  {q0,  q1},  [r3, :64]!
  vsub.f32 q5,  q13, q15
  vld1.32  {q14, q15}, [r10, :64]
  vsub.f32 q7,  q9,  q12
  vld1.32  {q12, q13}, [r8, :64]
  vst2.32  {q2,  q3},  [r5, :64]!
  vld1.32  {q2,  q3},  [r12, :64]!
  vadd.f32 q6,  q8,  q10
  vmul.f32 q8,  q14, q2
  vst2.32  {q4,  q5},  [r7, :64]!
  vmul.f32 q10, q15, q3
  vmul.f32 q9,  q13, q3
  vmul.f32 q11, q12, q2
  vmul.f32 q14, q14, q3
  vst2.32  {q6,  q7},  [r9, :64]!
  vmul.f32 q15, q15, q2
  vmul.f32 q12, q12, q3
  vmul.f32 q13, q13, q2
  vadd.f32 q10, q10, q8
  vsub.f32 q11, q11, q9
  vld1.32  {q8,  q9},  [r4, :64]
  vsub.f32 q14, q15, q14
  vadd.f32 q15, q13, q12
  vadd.f32 q13, q11, q10
  vadd.f32 q12, q15, q14
  vsub.f32 q15, q15, q14
  vsub.f32 q14, q11, q10
  vld1.32  {q10, q11}, [r6, :64]
  vadd.f32 q0,  q8,  q13
  vadd.f32 q1,  q9,  q12
  vsub.f32 q2,  q10, q15
  vadd.f32 q3,  q11, q14
  vsub.f32 q4,  q8,  q13
  vst2.32  {q0,  q1},  [r4, :64]!
  vsub.f32 q5,  q9,  q12
  vadd.f32 q6,  q10, q15
  vst2.32  {q2,  q3},  [r6, :64]!
  vsub.f32 q7,  q11, q14
  vst2.32  {q4,  q5},  [r8, :64]!
  vst2.32  {q6,  q7},  [r10, :64]!
  bne      1b