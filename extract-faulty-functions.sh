#!/usr/bin/env bash
#
# Script: extract-faulty-functions.sh
#
# Brief: Reads file paths from output/script_logs/faulty_functions.txt and calls extract-func.sh for each entry.
#        Each line in faulty_functions.txt is passed as an argument to extract-func.sh.
#
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAULTY_FUNCTIONS_FILE="$SCRIPT_DIR/output/script_logs/faulty_functions.txt"
EXTRACT_FUNC_SCRIPT="$SCRIPT_DIR/extract-func.sh"

if [[ ! -f "$FAULTY_FUNCTIONS_FILE" ]]; then
  echo "ERROR: $FAULTY_FUNCTIONS_FILE not found." >&2
  exit 1
fi

if [[ ! -x "$EXTRACT_FUNC_SCRIPT" ]]; then
  echo "ERROR: $EXTRACT_FUNC_SCRIPT not found or not executable." >&2
  exit 1
fi

OUTPUT_DIR=""

# Parse arguments for this script
usage() {
  echo "Usage: $0 [-o <output-folder>]" >&2
  exit 1
}

while getopts "o:h" opt; do
  case $opt in
    o) OUTPUT_DIR="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

# If not set, default to ./extracted_faulty_functions
if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="$SCRIPT_DIR/extracted_faulty_functions"
fi
mkdir -p "$OUTPUT_DIR"

while IFS= read -r line; do
  if [[ -n "$line" ]]; then
    # Expecting $line to be: <llvm-ir-file> <function-name>
    llfile="$(echo $line | awk '{print $1}')"
    funcname="$(echo $line | awk '{print $2}')"
    # escape funcname for use in a bash command
    funcname=$(printf '%q' "$funcname")
    eval "bash $EXTRACT_FUNC_SCRIPT -i \"$llfile\" -f \"$funcname\" -o \"$OUTPUT_DIR\""
  fi
done < "$FAULTY_FUNCTIONS_FILE"
