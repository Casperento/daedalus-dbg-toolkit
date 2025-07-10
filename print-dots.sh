#!/usr/bin/env bash
# print-dots.sh
# Generates .dot files from .ll sources, refactored to use getopts and accept input files as arguments

set -euo pipefail

# Default values
OUTPUT_DIR="output"
LOG_FILE="/dev/null"
LL_FILES=()

usage() {
  echo "Usage: $0 [-o output_dir] [-l log_file] -f file_or_dir"
  echo "  -o output_dir   Output base directory (default: output)"
  echo "  -l log_file     Log file (default: /dev/null)"
  echo "  -f file_or_dir  A single .ll file or a directory containing .ll files (required)"
}

# Parse options
while getopts "o:l:f:h" opt; do
  case $opt in
    o) OUTPUT_DIR="$OPTARG";;
    l) LOG_FILE="$OPTARG";;
    f)
      ARG="$OPTARG"
      if [[ -d "$ARG" ]]; then
        mapfile -t LL_FILES < <(find "$ARG" -maxdepth 1 -type f -name '*.ll' | sort)
      elif [[ -f "$ARG" && "$ARG" == *.ll ]]; then
        LL_FILES=("$ARG")
      else
        echo "-f must be a .ll file or a directory containing .ll files" >&2
        usage
        exit 1
      fi
      ;;
    h) usage; exit 0;;
    *) usage; exit 1;;
  esac
done
shift $((OPTIND - 1))

if [[ ${#LL_FILES[@]} -eq 0 ]]; then
  echo "Error: -f is required."
  usage
  exit 1
fi

# Logging
{
  echo -e "Generating .dot files...\n"
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for ll_file in "${LL_FILES[@]}"; do
    [[ -f "$ll_file" ]] || { echo "Missing: $ll_file"; continue; }
    name=$(basename "$ll_file" .ll)
    dot_dir="$OUTPUT_DIR/dots/${name}"
    mkdir -p "$dot_dir"
    cp "$ll_file" "$dot_dir/"
    bash "$SCRIPT_DIR/ll2dot.sh" "$dot_dir/"
  done
} | tee -a "$LOG_FILE"
