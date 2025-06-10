#!/bin/bash

# Usage: ./ll-to-dot-pdf.sh [directory]
# If no directory is given, uses the current directory.

set -euo pipefail

TARGET_DIR="${1:-.}"

# Find all .ll files in the target directory (non-recursive)
find "$TARGET_DIR" -maxdepth 1 -type f -name "*.ll" | while IFS= read -r llfile; do
    echo -e "Processing: $llfile\n"
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
        func=$(echo "$dotfile" | sed 's/^\.//; s/\.dot$//')
        # Shorten pdfname if it's too long (e.g., >32 chars)
        pdfname="${base}.${func}.dot.pdf"
        maxlen=32
        if [ ${#pdfname} -gt $maxlen ]; then
            # Use a hash of the full name for uniqueness, keep start/end for readability
            hash=$(echo -n "$pdfname" | sha1sum | cut -c1-8)
            pdfname="${base/.ll/}.${func:0:10}.${hash}.dot.pdf"
        fi
        output_pdf_dir="${TARGET_DIR%/}/$pdfname"
        
        echo "  Converting $dotfile to $output_pdf_dir"
        if ! dot -Tpdf "$dotfile" -o "$output_pdf_dir"; then
            echo "  Warning: Failed to convert $dotfile to $pdfname. Skipping."
            rm "$dotfile"
            continue
        fi
        rm "$dotfile"
    done
done

echo "All done."
