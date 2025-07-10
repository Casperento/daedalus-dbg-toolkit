#!/bin/bash

# Usage: ./ll2dot.sh [directory]
# If no directory is given, uses the current directory.

set -euo pipefail

TARGET_DIR="${1:-.}"

convertDotToPdf() {
    local dotfile="$1"
    local output_pdf_dir="$2"
    local pdfname="$3"
    echo "  Converting $dotfile to $output_pdf_dir"
    if ! dot -Tpdf "$dotfile" -o "$output_pdf_dir"; then
        echo "  Warning: Failed to convert $dotfile to $pdfname. Skipping."
        rm "$dotfile"
        return 1
    fi
    return 0
}

printPDFs() {
    local llfile="$1"
    local TARGET_DIR="$2"
    local prefix="$3"
    local newprefix="$4"
    for dotfile in *.dot .*.dot; do
        [ -e "$dotfile" ] || continue
        local base funcname pdfname output_pdf_dir
        base=$(basename "$llfile" .ll)
        base="${base/.ll/}"
        funcname="${dotfile/.dot/}"
        funcname="${funcname/#$prefix/}"
        
        if [ ${#funcname} -gt 64 ]; then
            funcname="${funcname:0:64}"
        fi

        pdfname="$newprefix.$base.$funcname.pdf"
        output_pdf_dir="${TARGET_DIR%/}/$pdfname"
        printf "Function name: %s\n" "$funcname"
        printf "\tPDF Name: %s\n\n" "$pdfname"
        convertDotToPdf "$dotfile" "$output_pdf_dir" "$pdfname" || continue
        rm "$dotfile"
    done
}

# Find all .ll files in the target directory (non-recursive)
find "$TARGET_DIR" -maxdepth 1 -type f -name "*.ll" | while IFS= read -r llfile; do
    echo -e "Processing: $llfile\n"

    # Generate .dot files using opt
    opt -passes=dot-cfg "$llfile" -disable-output
    printPDFs "$llfile" "$TARGET_DIR" "." "dot-cfg"
    opt -passes=dot-dom "$llfile" -disable-output
    printPDFs "$llfile" "$TARGET_DIR" "dom." "dot-dom"
    opt -passes=dot-post-dom "$llfile" -disable-output
    printPDFs "$llfile" "$TARGET_DIR" "postdom." "dot-post-dom"
    opt -dot-regions "$llfile" -disable-output
    printPDFs "$llfile" "$TARGET_DIR" "reg." "dot-regions"
    opt -passes=dot-cfg-only "$llfile" -disable-output
    printPDFs "$llfile" "$TARGET_DIR" "." "cfg-only"
done

echo "All done."
