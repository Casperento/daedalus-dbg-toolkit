#!/bin/bash
# Script to extract a function from an LLVM IR module
#
# Usage: ./extract-func.sh <llvm-ir-file>
#

LL_FILE=$1
FUNCTION_NAME=$2

# Check if the LLVM IR file and function name are provided
if [ -z "$LL_FILE" ] || [ -z "$FUNCTION_NAME" ]; then
    echo "Usage: $0 <llvm-ir-file> <function-name>"
    exit 1
fi

# Check if the LLVM IR file exists
if [ ! -f "$LL_FILE" ]; then
    echo "File not found!"
    exit 1
fi

OUTPUT_FILE="${LL_FILE%.ll}.$FUNCTION_NAME.ll"
if ! llvm-extract -S "-func=$FUNCTION_NAME" "$LL_FILE" -o "$OUTPUT_FILE"; then
    echo "Error extracting function $FUNCTION_NAME from $LL_FILE"
    exit 1
fi
echo "Function $FUNCTION_NAME extracted to $OUTPUT_FILE"
