#!/bin/bash
# compile_wine.sh — Compile PS2 Horror shaders on Linux/Mac using Wine + SCell555's ShaderCompile
#
# Prerequisites:
#   - wine installed (apt install wine / brew install wine)
#   - winetricks (for installing d3dcompiler_47 if needed)
#   - SCell555's ShaderCompile.exe placed in ./tools/
#     Download from: https://github.com/SCell555/ShaderCompile/releases
#
# Usage:
#   chmod +x compile_wine.sh
#   ./compile_wine.sh
#
# Output: shaders/fxc/*.vcs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR/tools"
SHADERSRC_DIR="$SCRIPT_DIR/shadersrc"
OUTPUT_DIR="$SCRIPT_DIR/shaders"

# --- Sanity checks ---
if ! command -v wine &> /dev/null; then
    echo "ERROR: wine is not installed."
    echo "  Ubuntu/Debian: sudo apt install wine"
    echo "  macOS:         brew install --cask wine-stable"
    exit 1
fi

if [ ! -f "$TOOLS_DIR/ShaderCompile.exe" ]; then
    echo "ERROR: ShaderCompile.exe not found at $TOOLS_DIR/"
    echo "  Download from: https://github.com/SCell555/ShaderCompile/releases"
    echo "  Place ShaderCompile.exe and its DLL dependencies in $TOOLS_DIR/"
    exit 1
fi

# --- Ensure d3dcompiler is available in Wine ---
# SCell555's compiler may error with "SM1 non-float expression" without the real d3dcompiler.
# Run once: winetricks d3dcompiler_47
if [ ! -f "$HOME/.wine/drive_c/windows/system32/d3dcompiler_47.dll" ]; then
    echo "NOTE: d3dcompiler_47 not detected in default Wine prefix."
    echo "If compilation fails with 'SM1 non-float expression', run:"
    echo "  winetricks d3dcompiler_47"
fi

# --- Compile each shader listed in compile_shader_list.txt ---
mkdir -p "$OUTPUT_DIR/fxc"

cd "$SHADERSRC_DIR"

while IFS= read -r shader_file || [ -n "$shader_file" ]; do
    # Skip blank lines and comments
    [ -z "$shader_file" ] && continue
    [[ "$shader_file" == \#* ]] && continue

    if [ ! -f "$shader_file" ]; then
        echo "WARNING: $shader_file not found, skipping"
        continue
    fi

    echo "Compiling $shader_file..."
    wine "$TOOLS_DIR/ShaderCompile.exe" \
        /O 3 \
        -ver 20b \
        -shaderpath "$(winepath -w "$OUTPUT_DIR")" \
        "$shader_file"

done < compile_shader_list.txt

echo ""
echo "=== Compilation complete ==="
echo "Output .vcs files are in: $OUTPUT_DIR/fxc/"
ls -la "$OUTPUT_DIR/fxc/" 2>/dev/null || echo "(directory empty — check errors above)"
echo ""
echo "Next: copy these .vcs files to your addon at:"
echo "  ps2_horror_v2/shaders/fxc/"
