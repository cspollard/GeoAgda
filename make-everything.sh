#!/usr/bin/env bash
set -euo pipefail

TARGETDIR="test/"
mkdir -p $TARGETDIR

TARGET="Everything.agda"

TARGET="${TARGETDIR%/}/${TARGET}"

cat << 'EOF' > "$TARGET"
module Everything where

EOF

find src -type f -name "*.agda" | sort | while IFS= read -r file; do
  mod="${file#src/}"
  mod="${mod%.agda}"
  mod="${mod//\//.}"
  echo "import $mod" >> "$TARGET"
done

agda -i src -i "$TARGETDIR" "$TARGET"
