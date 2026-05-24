# H-Linux Openbox 3.7.2

A modernized, high-performance fork of the Openbox 3.6.1 window manager, re-engineered for modern toolchains, strict memory safety, and native optimization within the **H-Linux** ecosystem.

## Overview

The 3.7.2 fork bridges the gap between classic minimalist window management and modern compiler standards. Development upstream has historically legacy code dependencies that trigger extensive diagnostics under modern GCC and Clang toolchains. 

This fork implements a comprehensive modernization pipeline—delivered via an automated patch infrastructure—achieving a **100% Zero-Warning production build** while fixing long-standing memory safety bugs.

## Technical Enhancements & Modernization

### 1. Strict Memory Safety & Bug Fixes

* **`obt/prop.c` Refactor:** Resolved a critical `-Wreturn-local-addr` compiler violation. Legacy code returned a pointer to a temporary stack-allocated array (`single`), resulting in runtime undefined behavior and the notorious "Unnamed Window" bug where window title data became corrupted upon function return. This logic has been completely overhauled to utilize persistent heap allocation via `g_memdup2`, ensuring absolute data persistence and stability.

* **`obt/xml.c` Const-Correctness:** Patched `libxml2` error handling structures to correctly match modern type checking definitions, shifting definitions to explicitly handle `const xmlError` pointers seamlessly.

### 2. GLib 2.70+ API Migration

* **Integer Overflow Mitigation:** Migrated all legacy, security-vulnerable `g_memdup` routines globally to the modern `g_memdup2` API specification, preventing potential integer wrapped allocation exploits.

* **Modern Pattern Matching:** Refactored deprecated utility logic to leverage `g_pattern_spec_match_string` and `g_pattern_spec_match`.

* **Diagnostic Hygiene:** Suppressed persistent toolchain noise regarding legacy `GTimeVal` and Pango API deprecations via targeted localized `#pragma` overrides within foundational header structures (`frame.h`, `render.h`, `obt.h`).

### 3. Native Environment Optimization

* **Display Server Target:** Architecture and compilation parameters are explicitly optimized out-of-the-box for the modern **XLibre** display server environment, yielding dramatic rendering efficiency gains and a completely fluid, stutter-free compositor phase compared to stock legacy Xorg environments.

* **Clean System Prefixing:** Targets `/usr/local` defaults for cleanly separating modernized system libraries (`libobt.so.2`, `libobrender.so.32`) from legacy or vendor packages.

## Architecture & Build Strategy

The project employs a structured **VPATH build execution** matrix to separate binary generation from the immutable source tree. 

```
┌──────────────────────────────────────┐
│        Automated Patch Stage         │  (Injects modern GLib APIs & C safety refactors)
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│        VPATH /build Directory        │  (Preserves source tree segregation)
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│     make -j$(nproc) Toolchain        │  (Natively optimized parallel execution)
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│     Zero-Warning Binary Output       │  (Natively linked to XLibre & /usr/local)
└──────────────────────────────────────┘
```

## Compilation & Deployment

Execute the automated build using parallel processing mapped directly to available hardware threads:

```bash
# 1. Prepare and enter compilation tree
mkdir -p build && cd build

# 2. Initialize configuration environment matching local host architecture
../configure --prefix=/usr/local

# 3. Compile using optimal processing threads
make -j$(nproc)

# 4. Deploy binaries and localized shared assets to system path
sudo make install
```

## Licensing

Distributed strictly under the terms of the **GNU General Public License, Version 2 or later (GPLv2+)**. All original upstream copyrights are explicitly preserved, honored, and documented alongside the 2026 authorship extensions.
