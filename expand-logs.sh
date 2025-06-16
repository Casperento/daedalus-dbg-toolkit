#!/bin/bash

SOURCES_DIR="./output/sources"
OUTPUT_DIR="./output/extended_bc_logs"
LIBDAEDALUS_DIR="$HOME/src/github/Daedalus/build/lib/libdaedalus.so"
SINGLE_FILE=""

# Parse options
while getopts "f:" opt; do
  case $opt in
    f)
      SINGLE_FILE="$OPTARG"
      ;;
    *)
      echo "Usage: $0 [-f <file.ll>]"
      exit 1
      ;;
  esac
done

if [ -d "$OUTPUT_DIR" ]; then
  rm -rf "$OUTPUT_DIR"
fi
mkdir -p "$OUTPUT_DIR"

process_ll_file() {
  local ll_file="$1"
  local output_dir="$2"
  local libdaedalus_dir="$3"
  local filename
  filename=$(basename "$ll_file" .ll)
  filename=$(basename "$filename" .e)
  local output_file="$output_dir/${filename}_errors.log"
  echo "Processing $ll_file..."
  opt -stats \
      -debug-only=daedalus,ProgramSlice \
      -passes=daedalus \
      -load-pass-plugin "$libdaedalus_dir" \
      -disable-output "$ll_file" \
      &> "$output_file"
}

# If a single file is provided, process only that file
if [ -n "$SINGLE_FILE" ]; then
  if [ ! -f "$SINGLE_FILE" ]; then
    echo "Error: File '$SINGLE_FILE' not found."
    exit 1
  fi
  process_ll_file "$SINGLE_FILE" "$OUTPUT_DIR" "$LIBDAEDALUS_DIR"
  echo "Error log generation complete."
  exit 0
fi

# If SOURCES_DIR is a file, process it as a single file
if [ -f "$SOURCES_DIR" ]; then
  process_ll_file "$SOURCES_DIR" "$OUTPUT_DIR" "$LIBDAEDALUS_DIR"
  echo "Error log generation complete."
  exit 0
fi

# Check if sources directory exists
if [ ! -d "$SOURCES_DIR" ]; then
  echo "Error: Source directory '$SOURCES_DIR' not found."
  exit 1
fi

# Iterate over each .ll file in the sources directory
for source_file in "$SOURCES_DIR"/*.ll; do
  if [ -f "$source_file" ]; then
    process_ll_file "$source_file" "$OUTPUT_DIR" "$LIBDAEDALUS_DIR"
  fi
done

echo "Error log generation complete."
