# ARM64 Merge Plan

This document tracks the step-by-step cherry-pick/merge process to enable **ARM64** builds on branch `arm64_support` without importing unrelated changes from `dev`.

---
## Legend
- `[ ]`  Task **not** started
- `[~]`  Task **in progress**
- `[x]`  Task **completed**

---
## Phase 0 – Safety Net
| Status | Task |
|:------:|------|
| [x] | Create working branch `arm64_build_enable` off `arm64_support`. |

---
## Phase 1 – Source-level Support
| Status | Task |
|:------:|------|
| [x] | Copy new ARM64 sources & headers from `dev`:<br/>&nbsp;&nbsp;• src/arch/arm64/arm64-codegen.c<br/>&nbsp;&nbsp;• src/arch/arm64/arm64-codegen.h (replace stub)<br/>&nbsp;&nbsp;• src/codegen_arm64.h<br/>&nbsp;&nbsp;• src/ffts_runtime_arm64.c<br/>&nbsp;&nbsp;• src/ffts_runtime_arm64.h<br/>&nbsp;&nbsp;• src/macros-neon64.h<br/>&nbsp;&nbsp;• src/neon64.s<br/>&nbsp;&nbsp;• src/neon64_static.s |
| [x] | Commit: **"Add ARM64 codegen & runtime sources"** |

---
## Phase 2 – Library Build Glue (Autotools)
| Status | Task |
|:------:|------|
| [x] | Add `src/arch/arm64/Makefile.am`. |
| [x] | Patch `src/Makefile.am` with HAVE_ARM64 logic & source list. |
| [ ] | Run `autoreconf -fi` to regenerate autotools files locally (will succeed after Phase 3 changes). |
| [x] | Commit: **"Add Makefile rules for ARM64"** |

---
## Phase 3 – Configure-time Switch
| Status | Task |
|:------:|------|
| [ ] | Apply minimal changes to `configure.ac`:<br/>&nbsp;&nbsp;• `AC_ARG_ENABLE(arm64 …)`<br/>&nbsp;&nbsp;• `AM_CONDITIONAL(HAVE_ARM64 …)`<br/>&nbsp;&nbsp;• host triplet case for `aarch64*`<br/>&nbsp;&nbsp;• `AC_DEFINE(HAVE_ARM64,1,…)` and related defines |
| [ ] | Run `autoreconf -fi`, then `./configure --enable-arm64` to verify. |
| [ ] | Commit: **"Introduce --enable-arm64 flag"** |

---
## Phase 4 – Helper Script
| Status | Task |
|:------:|------|
| [ ] | Bring in `build_arm64.sh`, ensure it has executable bit and correct paths. |
| [ ] | Commit. |

---
## Phase 5 – (OPTIONAL) CMake Path
| Status | Task |
|:------:|------|
| [ ] | Copy `cmake/arm64-toolchain.cmake`. |
| [ ] | Patch `CMakeLists.txt` only with ARM64-related hunks. |
| [ ] | Commit if applied. |

---
## Phase 6 – (OPTIONAL) Validation Tests
| Status | Task |
|:------:|------|
| [ ] | After successful build, cherry-pick test sources:<br/>&nbsp;&nbsp;• tests/test_arm64.c<br/>&nbsp;&nbsp;• tests/test_arm64_validation.c<br/>&nbsp;&nbsp;• tests/test_arm64_performance.c<br/>&nbsp;&nbsp;• scripts/validate_arm64.sh |
| [ ] | Commit.

---
### Core Files Involved
```
src/arch/arm64/arm64-codegen.c
src/arch/arm64/arm64-codegen.h
src/codegen_arm64.h
src/ffts_runtime_arm64.c
src/ffts_runtime_arm64.h
src/macros-neon64.h
src/neon64.s
src/neon64_static.s

src/codegen.c
src/ffts.c
src/ffts_real.c
src/ffts_transpose.c
src/ffts_trig.c
src/macros-neon.h
src/macros.h
src/neon.s

configure.ac
src/Makefile.am
src/arch/arm64/Makefile.am

# optional
build_arm64.sh
CMakeLists.txt
cmake/arm64-toolchain.cmake
```

---
### Notes / Decisions
* Never push changes to the remote.
* We deliberately **exclude** every generated artefact from `dev` (Makefile.in, configure, CMakeFiles/**, compiled tests, etc.).
* Regenerate autotools outputs locally after each phase.
* Build-and-run checkpoints after each phase to catch regressions early. 