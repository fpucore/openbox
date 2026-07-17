![Openbox 3 logo](assets/ob3-logo.png)

# Openbox 3.8.0

A modernized, high-performance continuation of Openbox, re-engineered for strict memory safety, modern toolchains, native XLibre optimization, and a novel polyglot session management pipeline.

---

## Overview

The 3.8.0 release bridges the gap between classic minimalist window management and modern systems architecture.

Development upstream has historically relied on legacy code dependencies that trigger extensive diagnostics under modern GCC/Clang toolchains and lack safe, flexible session initialization.

This continuation of Openbox implements a comprehensive modernization pipeline—delivered via an automated patch infrastructure (`omni-patch-build.sh`)—achieving a 100% zero-warning production build, fixing long-standing memory safety bugs, and introducing a first-of-its-kind Rust/Perl polyglot session manager with three-tier graceful degradation (legacy mode).

---

## Technical Enhancements & Modernization

### 1. Polyglot Session-Init (New in v3.8.0)

A Rust-supervised, Perl 6-transpiled session manager that replaces legacy autostart exec with a three-tier graceful degradation pipeline:

* **Tier 1 — Full Pipeline (Rust + Perl 6):** Rust daemonizes and supervises; Perl 6 parses the legacy `~/.config/openbox/autostart` config at runtime, strips noise, comments, normalizes `~/` > `$HOME/`, structures lockfile guards as native Perl 6 conditionals, and emits a clean exec script.
* **Tier 2 — Safe Shell Executor (Rust only):** When Perl 6 is unavailable, Rust still provides memory-safe daemonization, unified logging, and process supervision while exec the legacy autostart directly via `/bin/sh`.
* **Tier 3 — Pure Legacy (Neither):** When neither Rust nor Perl 6 is installed, Openbox falls back to its old native `C/shell` autostart path unchanged, ensuring zero breakage on minimal or legacy systems.

Unified session logging to `~/.cache/openbox/session-init.log`.

## Session Management Comparison

| Feature | Legacy Openbox Autostart | Tier 1 (Full Pipeline) | Tier 2 (Safe Shell) | Tier 3 (Pure Legacy) |
| :--- | :--- | :--- | :--- | :--- |
| **Runtime Dependencies** | `/bin/sh` only | Rust + Raku | Rust only | None |
| **Process Supervision** | ❌ None | ✅ Rust daemon | ✅ Rust daemon | ❌ None |
| **Memory Safety** | ❌ Shell/C only | ✅ Rust supervisor | ✅ Rust supervisor | ❌ Shell/C only |
| **Unified Logging** | ❌ Scattered outputs | ✅ Single log stream | ✅ Single log stream | ❌ Scattered outputs |
| **Autostart Parsing** | Raw shell execution | Raku transpilation | Raw shell execution | Raw shell execution |
| **Comment/Noise Stripping** | ❌ Manual | ✅ Automatic | ❌ Manual | ❌ Manual |
| **Lockfile Guards** | Bash `if/fi` blocks | Native Raku conditionals | Bash `if/fi` blocks | Bash `if/fi` blocks |
| **Path Normalization** | ❌ Shell-dependent | ✅ `$HOME` at transpile time | ❌ Shell-dependent | ❌ Shell-dependent |
| **Stale Artifact Protection** | N/A | ✅ Auto-reset on failure | N/A | N/A |
| **Edit → Apply Cycle** | Next login | Next login (auto-transpile) | Next login | Next login |
| **Source of Truth** | `~/.config/openbox/autostart` | `~/.config/openbox/autostart` | `~/.config/openbox/autostart` | `~/.config/openbox/autostart` |
| **Graceful Degradation** | ❌ No fallback | → Tier 2 → Tier 3 | → Tier 3 | Terminal fallback |

### 2. Strict Memory Safety & Bug Fixes

* **`obt/prop.c` Refactor:** Resolved a critical `-Wreturn-local-addr` compiler violation. Legacy code returned a pointer to a temporary stack-allocated array (`single`), resulting in runtime undefined behavior and the notorious "Unnamed Window" bug where window title data became corrupted upon function return. This logic has been completely overhauled to utilize persistent heap allocation via `g_memdup2`, ensuring absolute data persistence and stability.

* **`obt/xml.c` Const-Correctness:** Patched `libxml2` error handling structures to correctly match modern type checking definitions, shifting definitions to explicitly handle `const xmlError` pointers seamlessly.

### 3. GLib 2.70+ API Migration

* **Integer Overflow Mitigation:** Migrated all legacy, security-vulnerable `g_memdup` routines globally to the modern `g_memdup2` API specification, preventing potential integer wrapped allocation exploits.

* **Modern Pattern Matching:** Refactored deprecated utility logic to leverage `g_pattern_spec_match_string` and `g_pattern_spec_match`.

* **Diagnostic Hygiene:** Suppressed persistent toolchain noise regarding legacy `GTimeVal` and Pango API deprecations via targeted localized `#pragma` overrides within foundational header structures (`frame.h`, `render.h`, `obt.h`).

### 4. Native Environment Optimization

* **Display Server Target:** Architecture and compilation parameters are explicitly optimized out-of-the-box for the modern **XLibre** display server environment, yielding dramatic rendering efficiency gains and a completely fluid, stutter-free compositor phase compared to stock legacy Xorg environments.

* **Clean System Prefixing:** Targets `/usr/local` defaults for cleanly separating modernized system libraries (`libobt.so.2`, `libobrender.so.32`) from legacy or vendor packages.

---

## Dependencies

### Required

* **C Toolchain:** GCC or Clang with C11 support
* **GLib 2.70+:** Core runtime library (`g_memdup2`, pattern matching APIs)
* **libxml2:** XML configuration parsing
* **X11 (Xorg) / XLibre:** X Display server libraries and headers
* **Pango:** Text rendering and font handling
* **GNU Autotools:** `autoconf`, `automake`, `libtool` (for building from source)

### Optional, but **highly recommended** (Polyglot Session-Init)

* **Rust Toolchain:** Required to compile `session-init` from source. If absent, the build system uses the pre-compiled fallback binary included in the repository.
* **Raku (Perl 6):** Required for Tier 1 full transpilation pipeline. If absent, `session-init` automatically falls back to Tier 2 (safe shell exec) or Tier 3 (pure legacy mode) at runtime. No build-time failure occurs.

> **Note:** The `omni-patch-build.sh` script performs automatic detection of both Rust and Perl 6 at build time and configures the appropriate execution tier. All three tiers function correctly regardless of which optional dependencies are installed.

---

## Architecture & Build Strategy

The project employs a structured **VPATH build execution** matrix to separate binary generation from the immutable source tree. 

```
┌──────────────────────────────────────┐
│         Omni-Patch Automator         │
│    (Branding, Memory Safety, GLib    │
│   Modernization, Toolchain Checks)   │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│          Session-Init Build          │
│  (Rust compile or fallback binary +  │
│   Perl 6 transpiler installation)    │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│        VPATH /build Directory        │
│ (Preserves source tree segregation)  │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│      make -j$(nproc) Toolchain       │
│  (Natively optimized parallel exec)  │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│     Zero-Warning Binary Output       │
│      (Openbox + session-init +       │
│  transpiler deployed to /usr/local)  │
└──────────────────────────────────────┘
```

---

## Compilation & Deployment

Execute the fully automated build using the `omni-patch-build.sh` script:

```bash
./omni-patch-build.sh
```

---

## Licensing

Distributed strictly under the terms of the **GNU General Public License, Version 3 (GPLv3)**. All original upstream copyrights are explicitly preserved, honored, and documented alongside the 2026 authorship extensions.
