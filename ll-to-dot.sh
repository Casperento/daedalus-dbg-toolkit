#!/bin/bash

# Usage: ./ll-to-dot-pdf.sh [directory]
# If no directory is given, uses the current directory.

set -euo pipefail

TARGET_DIR="${1:-.}"

# Find all .ll files in the target directory (non-recursive)
find "$TARGET_DIR" -maxdepth 1 -type f -name "*.ll" | while IFS= read -r llfile; do
    echo "Processing: $llfile"
    # Generate .dot files using opt
    opt -passes=dot-cfg "$llfile" -disable-output
    opt -passes=dot-dom "$llfile" -disable-output
    opt -passes=dot-post-dom "$llfile" -disable-output
    opt -dot-regions "$llfile" -disable-output

    # For each .dot file generated (e.g., .main.dot, .foo.dot, etc.)
    for dotfile in *.dot .*.dot; do
        # Check if any .dot files exist
        [ -e "$dotfile" ] || continue

        # Compose output PDF name: <basename>.function.dot.pdf
        base=$(basename "$llfile" .ll)
        base=$(basename "$base" .e)
        func=$(echo "$dotfile" | sed 's/^\.//; s/\.dot$//')
        pdfname="${base}.${func}.dot.pdf"

        echo "  Converting $dotfile to $pdfname"
        if ! dot -Tpdf "$dotfile" -o "$pdfname"; then
            echo "  Warning: Failed to convert $dotfile to $pdfname. Skipping."
            rm "$dotfile"
            continue
        fi
        rm "$dotfile"
    done
done

echo "All done."
