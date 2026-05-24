#!/bin/bash
# H-Linux Openbox 3.7.2 "Omni-Patch" & Build Automator
# Combines: Branding, Memory Safety, API Modernization, and Logic Fixes.

set -e # Exit on error

echo "--- H-Linux: Starting Omni-Patch Sequence ---"

# 1. VERSION & BRANDING BUMP
# Sets the H-Linux standard version and adds your copyright
echo "[1/6] Applying H-Linux Branding..."
find . -name "version.h.in" -exec sed -i 's/3.6.1/3.7.2/g' {} +
sed -i 's/\[3.6.1\]/\[3.7.2\]/g' configure.ac
sed -i '/g_print(_("Copyright (c)"));/{N;/2004[[:space:]]*Mikael Magnusson/s/.*/    g_print(_("Copyright (c)"));\n    g_print(" 2026   Chris McGimpsey-Jones\\n");\n    g_print(_("Copyright (c)"));\n    g_print(" 2004   Mikael Magnusson\\n");/}' openbox/openbox.c

# 2. COMPILER PRAGMAS (Silencing the noise)
# Disables deprecation warnings for GTimeVal and Pango in specific headers
echo "[2/6] Injecting compiler silencers..."
for header in "openbox/frame.h" "obrender/render.h" "obt/obt.h"; do
    if [ -f "$header" ]; then
        if ! grep -q "diagnostic ignored" "$header"; then
            sed -i '1i #pragma GCC diagnostic ignored "-Wdeprecated-declarations"' "$header"
        fi
    fi
done

# 3. XML HANDLING (Const Safety)
# Fixes the const mismatch and reset cast in obt/xml.c
echo "[3/6] Fixing XML logic..."
if [ -f "obt/xml.c" ]; then
    sed -i 's/xmlErrorPtr error = xmlGetLastError();/const xmlError *error = xmlGetLastError();/g' obt/xml.c
    sed -i 's/xmlResetError(error);/xmlResetError((xmlErrorPtr)error);/g' obt/xml.c
fi

# 4. GLIB MODERNIZATION (g_memdup2 & Patterns)
# Upgrades memory allocation and pattern matching to modern standards
echo "[4/6] Upgrading GLib APIs..."
find . -type f -name "*.c" -exec sed -i 's/g_memdup(/g_memdup2(/g' {} +
find . -type f -name "*.c" -exec sed -i 's/g_pattern_match_string/g_pattern_spec_match_string/g' {} +
find . -type f -name "*.c" -exec sed -i 's/g_pattern_match(/g_pattern_spec_match(/g' {} +

# 5. THE PROP.C FINAL FIX (Memory Safety + Data Integrity)
echo "[5/6] Patching prop.c logic error..."
if [ -f "obt/prop.c" ]; then
    sed -i 's/retlist = NULL;/retlist = single;/g' obt/prop.c
    sed -i 's/return (retlist ? retlist\[0\] : NULL);/return retlist[0];/g' obt/prop.c
    sed -i 's/return (retlist == NULL ? NULL : retlist);/return retlist;/g' obt/prop.c
    sed -i 's/retlist = single;/retlist = g_memdup2(single, sizeof(gchar*) * 2);/g' obt/prop.c
fi

# 6. BUILD & INSTALL
echo "[6/6] Entering Build Phase..."
# Clean build environment
rm -rf build && mkdir build && cd build

echo "--- Configuring ---"
../configure --prefix=/usr/local --sysconfdir=/etc --disable-static

echo "--- Compiling ---"
make -j$(nproc)

echo "--- Installing ---"
sudo make install

echo "--- H-Linux Openbox 3.7.2 Build Complete ---"
/usr/local/bin/openbox --version
