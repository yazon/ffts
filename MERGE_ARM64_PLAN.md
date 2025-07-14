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
| [x] | Run `autoreconf -fi` to regenerate autotools files locally. |
| [x] | Commit: **"Add Makefile rules for ARM64"** |

---
## Phase 3 – Configure-time Switch
| Status | Task |
|:------:|------|
| [x] | Apply minimal changes to `configure.ac`:<br/>&nbsp;&nbsp;• `AC_ARG_ENABLE(arm64 …)`<br/>&nbsp;&nbsp;• `AM_CONDITIONAL(HAVE_ARM64 …)`<br/>&nbsp;&nbsp;• host triplet case for `aarch64*`<br/>&nbsp;&nbsp;• `AC_DEFINE(HAVE_ARM64,1,…)` and related defines |
| [x] | Run `autoreconf -fi`, then `./configure --enable-arm64` to verify. |
| [x] | Commit: **"Introduce --enable-arm64 flag"** |

---
## Phase 4 – Helper Script
| Status | Task |
|:------:|------|
| [x] | Bring in `build_arm64.sh`, ensure it has executable bit and correct paths. |
| [x] | Make `build_arm64.sh`, similar to `build_arm32.sh`, must run tests at the end. |
| [x] | Commit. |

---
## Phase 5 – (OPTIONAL) CMake Path
| Status | Task |
|:------:|------|
| [ ] | Copy `cmake/arm64-toolchain.cmake`. |
| [ ] | Patch `CMakeLists.txt` only with ARM64-related hunks. |
| [ ] | Commit if applied. |

---
## Phase 5 – Core Source Patches
| Status | Task |
|:------:|------|
| [x] | Cherry-pick ARM64-aware versions of core sources (`codegen.c`, `ffts.c`, `ffts_real.c`, `ffts_transpose.c`, `ffts_trig.c`, `macros-neon.h`, `macros.h`, `neon.s`). |
| [ ] | Build & run `make -j$(nproc)` to confirm compilation succeeds. |
| [ ] | Commit: **"Phase 5: ARM64 core source patches"** |

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