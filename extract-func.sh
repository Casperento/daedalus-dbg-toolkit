#!/bin/bash
# Script to extract a function from an LLVM IR module
#
# Usage: ./extract-func.sh -i <llvm-ir-file> -f <function-name> [-o <output-folder>]
#

set -e

usage() {
    echo "Usage: $0 -i <llvm-ir-file> -f <function-name> [-o <output-folder>]"
    exit 1
}

# Default values
OUTPUT_DIR="."

# Parse arguments
while getopts "i:f:o:h" opt; do
  case $opt in
    i) LL_FILE="$OPTARG" ;;
    f) FUNCTION_NAME="$OPTARG" ;;
    o) OUTPUT_DIR="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

# Check required arguments
if [ -z "$LL_FILE" ] || [ -z "$FUNCTION_NAME" ]; then
    usage
fi

# Check if the LLVM IR file exists
if [ ! -f "$LL_FILE" ]; then
    echo "File not found: $LL_FILE"
    exit 1
fi

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Compose output file path
BASENAME="$(basename "${LL_FILE%.ll}")"

FUNCTION_SHORT_NAME="$FUNCTION_NAME"
if [ ${#FUNCTION_NAME} -gt 64 ]; then
  FUNCTION_SHORT_NAME="${FUNCTION_NAME:0:64}"
fi

OUTPUT_FILE="$OUTPUT_DIR/${BASENAME}.${FUNCTION_SHORT_NAME}.ll"
printf "\nExtracting function: %s from %s\n\tTo %s\n" "$FUNCTION_NAME" "$LL_FILE" "$OUTPUT_FILE"

if ! llvm-extract -S "-func=$FUNCTION_NAME" "$LL_FILE" -o "$OUTPUT_FILE"; then
    echo "Error extracting function $FUNCTION_NAME from $LL_FILE"
    exit 1
fi
echo "Function $FUNCTION_NAME extracted to $OUTPUT_FILE"
