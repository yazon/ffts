# ARM64 FFT Implementation Debug Plan

## 🎯 Objective
Line-by-line verification between ARM32 (`neon_static.s`) and ARM64 (`neon64_static.s`) implementations to identify and fix all issues causing segfaults and computational errors for ARM64.

## 📊 Current Status
- ✅ **Infrastructure Fixed**: Struct offsets, macros, data types
- ❌ **N=16 fails**: Wrong results (x4 function issues)  
- ❌ **N=32 segfaults**: Memory access violations (x8_t function issues)

## 🔍 Investigation Strategy
For each function, compare ARM32 vs ARM64:
1. **Function signatures** and parameter handling
2. **Register allocation** and data flow
3. **Memory access patterns** (loads/stores)
4. **FFT butterfly algorithms** (mathematical correctness)
5. **Loop structures** and control flow

---

## 📋 Task Breakdown

### Task 1: Function Signature Verification
**Status**: 🔄 TODO  
**Target**: Verify all functions have correct signatures and parameter handling

#### Subtasks:
- [ ] 1.1: Compare neon_static_e_f/i signatures (ARM32 vs ARM64)
- [ ] 1.2: Compare neon_static_o_f/i signatures (ARM32 vs ARM64)  
- [ ] 1.3: Compare neon_static_x4_f/i signatures (ARM32 vs ARM64)
- [ ] 1.4: Compare neon_static_x8_f/i signatures (ARM32 vs ARM64)
- [ ] 1.5: Compare neon_static_x8_t_f/i signatures (ARM32 vs ARM64)

**Findings**: 
- 

**Actions Taken**:
- 

---

### Task 2: neon_static_x4 Function Analysis  
**Status**: 🔄 TODO  
**Target**: Fix N=16 computational errors

#### Subtasks:
- [ ] 2.1: Compare ARM32 vs ARM64 x4 algorithm structure
- [ ] 2.2: Verify 4-point FFT butterfly mathematics  
- [ ] 2.3: Check twiddle factor loading and usage
- [ ] 2.4: Verify memory load/store patterns
- [ ] 2.5: Test isolated x4 function with known inputs

**Findings**:
- 

**Actions Taken**:
- 

---

### Task 3: neon_static_x8_t Function Analysis
**Status**: 🔄 TODO  
**Target**: Fix N=32 segfaults

#### Subtasks:  
- [ ] 3.1: Compare ARM32 vs ARM64 x8_t algorithm structure
- [ ] 3.2: Verify 8-point transposed FFT mathematics
- [ ] 3.3: Check memory pointer calculations and bounds
- [ ] 3.4: Verify loop counter and iteration logic
- [ ] 3.5: Test with segfault debugging tools

**Findings**:
- 

**Actions Taken**:
- 

---

### Task 4: neon_static_e/o Function Analysis  
**Status**: 🔄 TODO  
**Target**: Verify main transform functions work correctly

#### Subtasks:
- [ ] 4.1: Compare ARM32 vs ARM64 e/o function structure
- [ ] 4.2: Verify recursive FFT algorithm logic
- [ ] 4.3: Check struct member access (p->N, p->i0, etc.)
- [ ] 4.4: Verify function call patterns to x4/x8 functions
- [ ] 4.5: Test e/o functions independently

**Findings**:
- 

**Actions Taken**:
- 

---

### Task 5: Integration Testing & Validation
**Status**: 🔄 TODO  
**Target**: Verify complete pipeline works correctly

#### Subtasks:
- [ ] 5.1: Test individual functions in isolation
- [ ] 5.2: Test N=16 pipeline (should use x4 functions)
- [ ] 5.3: Test N=32 pipeline (should use x8_t functions) 
- [ ] 5.4: Compare outputs with reference implementation
- [ ] 5.5: Performance benchmarking vs ARM32

**Findings**:
- 

**Actions Taken**:
- 

---

## 🧰 Debug Tools & Methods

### Comparison Tools:
- Side-by-side ARM32/ARM64 source analysis
- Register usage mapping (r0-r12 → x0-x30)
- Memory layout verification tools

### Testing Tools:
- Unit tests with known FFT inputs/outputs
- GDB debugging in qemu-aarch64
- Memory access tracking
- Computational accuracy verification

### Reference Materials:
- ARM32 neon_static.s (working implementation)
- ARM64 NEON instruction reference
- Radix-4/8 FFT algorithms documentation

---

## 📝 Progress Log

### Session 1: [Current]
- **Started**: Task 1 - Function signature verification
- **Status**: Setting up systematic debugging approach
- **Next**: Begin line-by-line comparison of function signatures

---

*This plan will be updated after each task completion with findings and fixes applied.* 