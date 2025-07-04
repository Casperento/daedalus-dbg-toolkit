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

while IFS= read -r line; do
  if [[ -n "$line" ]]; then
    eval "bash \"$EXTRACT_FUNC_SCRIPT\" $line"
  fi
done < "$FAULTY_FUNCTIONS_FILE"
