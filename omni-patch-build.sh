#!/bin/bash

#  /------------------------------------------------------------------------------\
#  | Openbox 3.8.1 "Omni-Patch" & Build Automator                                 |
#  | Patches and Compiles: Branding, Memory Safety, API Modernization,            |
#  | Logic Fixes, and Rust-based session-init.                                    |
#  |                                                                              |
#  | Copyright (C) 2026  Chris-McGimpsey-Jones                                    |
#  |                                                                              |
#  | This program is free software: you can redistribute it and/or modify         |
#  | it under the terms of the GNU General Public License as published by         |
#  | the Free Software Foundation, either version 3 of the License, or            |
#  | (at your option) any later version.                                          |
#  |                                                                              |
#  | This program is distributed in the hope that it will be useful,              |
#  | but WITHOUT ANY WARRANTY; without even the implied warranty of               |
#  | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                |
#  | GNU General Public License for more details.                                 |
#  |                                                                              |
#  | You should have received a copy of the GNU General Public License            |
#  | along with this program.  If not, see <https://www.gnu.org/licenses/>.       |
#  \------------------------------------------------------------------------------/

set -e # Exit on error

echo "--- GNU Operating System / H-Linux: Starting Omni-Patch Sequence ---"

# 1. VERSION & BRANDING BUMP
# Sets the H-Linux standard version and adds your copyright
echo "[1/8] Applying H-Linux Branding..."
# Catches both the original upstream (3.6.1) and original fork (3.7.2)
find . -name "version.h.in" -exec sed -i -E 's/3\.(6\.1|7\.2|8\.0)/3.8.1/g' {} +
sed -i -E 's/\[3\.(6\.1|7\.2|8\.0)\]/\[3.8.1\]/g' configure.ac

# Safety net: Only apply copyright patch if it hasn't been applied already
if ! grep -q "Chris McGimpsey-Jones" openbox/openbox.c; then
    sed -i '/g_print(_("Copyright (c)"));/{
        N
        /2004[[:space:]]*Mikael Magnusson/c\
    g_print(_("Copyright (c)"));\
    g_print(" 2026   Chris McGimpsey-Jones\\n");\
    g_print(_("Copyright (c)"));\
    g_print(" 2004   Mikael Magnusson\\n");
    }' openbox/openbox.c
fi

# 2. COMPILER PRAGMAS (Silencing the noise)
echo "[2/8] Injecting compiler silencers..."
for header in "openbox/frame.h" "obrender/render.h" "obt/obt.h"; do
    if [ -f "$header" ]; then
        if ! grep -q "diagnostic ignored" "$header"; then
            sed -i '1i #pragma GCC diagnostic ignored "-Wdeprecated-declarations"' "$header"
        fi
    fi
done

# 3. XML HANDLING (Const Safety)
# Fixes the const mismatch and reset cast in obt/xml.c
echo "[3/8] Fixing XML logic..."
if [ -f "obt/xml.c" ]; then
    sed -i 's/xmlErrorPtr error = xmlGetLastError();/const xmlError *error = xmlGetLastError();/g' obt/xml.c
    sed -i 's/xmlResetError(error);/xmlResetError((xmlErrorPtr)error);/g' obt/xml.c
fi

# 4. GLIB MODERNIZATION (g_memdup2 & Patterns)
# Upgrades memory allocation and pattern matching to modern standards
echo "[4/8] Upgrading GLib APIs..."
find . -type f -name "*.c" -exec sed -i 's/g_memdup(/g_memdup2(/g' {} +
find . -type f -name "*.c" -exec sed -i 's/g_pattern_match_string/g_pattern_spec_match_string/g' {} +
find . -type f -name "*.c" -exec sed -i 's/g_pattern_match(/g_pattern_spec_match(/g' {} +

# 5. THE PROP.C FINAL FIX (Memory Safety + Data Integrity)
echo "[5/8] Patching prop.c logic error..."
if [ -f "obt/prop.c" ]; then
    sed -i 's/retlist = NULL;/retlist = single;/g' obt/prop.c
    sed -i 's/return (retlist ? retlist\[0\] : NULL);/return retlist[0];/g' obt/prop.c
    sed -i 's/return (retlist == NULL ? NULL : retlist);/return retlist;/g' obt/prop.c
    sed -i 's/retlist = single;/retlist = g_memdup2(single, sizeof(gchar*) * 2);/g' obt/prop.c
fi

# 6. SESSION-INIT (Source Compile or Fallback Binary)
echo "[6/8] Preparing session-init..."

# But first, clean
echo "Setting up clean build environment..."
rm -fr session-init/target

RUST_BIN_NAME="session-init"
RUST_SRC_DIR="session-init"
FALLBACK_BIN="session-init/session-init-fallback" 
FINAL_RUST_BIN=""

if command -v cargo &> /dev/null; then
    echo " -> Rust toolchain found. Building $RUST_BIN_NAME from source..."
    if [ -d "$RUST_SRC_DIR" ]; then
        (cd "$RUST_SRC_DIR" && cargo build --release)
        FINAL_RUST_BIN="$RUST_SRC_DIR/target/release/$RUST_BIN_NAME"
    else
        echo " -> Warning: $RUST_SRC_DIR directory not found. Attempting to use the pre-compiled fallback binary."
        FINAL_RUST_BIN="$FALLBACK_BIN"
    fi
else
    echo " -> Rust toolchain not found. Using the pre-compiled fallback binary."
    FINAL_RUST_BIN="$FALLBACK_BIN"
fi

if [ ! -f "$FINAL_RUST_BIN" ]; then
    echo "Error: Could not locate compiled binary or pre-compiled fallback binary at $FINAL_RUST_BIN"
    exit 1
fi

echo " -> Compiled binary ready at: $FINAL_RUST_BIN"

if command -v raku &> /dev/null; then
    echo " -> ✓ Perl 6 toolchain found. Full transpilation pipeline enabled."
else
    echo " -> ✗ Perl 6 NOT found. session-init will run in legacy mode."
    echo "   Install Perl 6 to enable transpilation."
fi

# 7. AUTOSTART TEMPLATE INJECTION
echo "[7/8] Injecting Rust hook into openbox-autostart.in..."
AUTOSTART_TEMPLATE="data/autostart/openbox-autostart.in"

if [ -f "$AUTOSTART_TEMPLATE" ]; then
    # Safety net: Only inject if it hasn't been injected yet
    if ! grep -q "session-init integration" "$AUTOSTART_TEMPLATE"; then
        cat << 'RUST_HOOK' > /tmp/hlinux_rust_hook.txt

# --- session-init integration ---
if [ -x "@bindir@/session-init" ]; then
    "@bindir@/session-init"
    exit 0
fi
# ------------------------------------------
RUST_HOOK
        sed -i '1r /tmp/hlinux_rust_hook.txt' "$AUTOSTART_TEMPLATE"
        rm -f /tmp/hlinux_rust_hook.txt
        echo " -> Successfully patched $AUTOSTART_TEMPLATE"
    else
        echo " -> $AUTOSTART_TEMPLATE is already patched."
    fi
else
    echo " -> Warning: $AUTOSTART_TEMPLATE not found. Openbox will revert to Autostart legacy mode."
fi

# 8. BUILD & INSTALL
echo "[8/8] Commencing Build Phase..."
# Clean build env
echo "Extra cleaning needed... wait..."
rm -rf build && mkdir build && cd build
echo "... done."

echo "--- Configuring ---"
../configure --prefix=/usr/local --sysconfdir=/etc --disable-static

echo "--- Compiling ---"
make -j$(nproc)

echo "--- Installing Openbox ---"
# Run make first as safety and prep for dir creation
sudo make install

sudo cp "../$FINAL_RUST_BIN" "/usr/local/bin/$RUST_BIN_NAME"
sudo chmod +x "/usr/local/bin/$RUST_BIN_NAME"

sudo cp "../session-init/transpile" "/usr/local/bin/transpile"
sudo chmod +x "/usr/local/bin/transpile"

# CONFIRM
echo "--- Openbox 3.8.1 Build Complete ---"

# VERIFY
/usr/local/bin/openbox --version
