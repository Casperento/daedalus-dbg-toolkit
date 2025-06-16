#!/usr/bin/env bash
# print-dots.sh
# Generates .dot files from .ll sources, refactored to use getopts and accept input files as arguments

set -euo pipefail

# Default values
OUTPUT_DIR="output"
LOG_FILE="/dev/null"

usage() {
  echo "Usage: $0 [-o output_dir] [-l log_file] file1.ll [file2.ll ...]"
  echo "  -o output_dir   Output base directory (default: output)"
  echo "  -l log_file     Log file (default: /dev/null)"
  echo "  file1.ll ...    One or more .ll files to process"
}

# Parse options
while getopts "o:l:h" opt; do
  case $opt in
    o) OUTPUT_DIR="$OPTARG";;
    l) LOG_FILE="$OPTARG";;
    h) usage; exit 0;;
    *) usage; exit 1;;
  esac
done
shift $((OPTIND - 1))

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

# Logging
{
  echo -e "Generating .dot files...\n"
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for ll_file in "$@"; do
    [[ -f "$ll_file" ]] || { echo "Missing: $ll_file"; continue; }
    name=$(basename "$ll_file" .ll)
    dot_dir="$OUTPUT_DIR/dots/${name}"
    mkdir -p "$dot_dir"
    cp "$ll_file" "$dot_dir/"
    bash "$SCRIPT_DIR/ll2dot.sh" "$dot_dir/"
  done
} | tee -a "$LOG_FILE"
