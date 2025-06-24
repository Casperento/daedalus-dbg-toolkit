#!/bin/bash

SOURCES_DIR="./output/sources"
OUTPUT_DIR="./output/extended_bc_logs"
LIBDAEDALUS_DIR="$HOME/src/github/Daedalus/build/lib/libdaedalus.so"
SINGLE_FILE=""
CLEAN_OUTPUT=0

# Parse options
while getopts "f:c-:" opt; do
  case $opt in
    f)
      SINGLE_FILE="$OPTARG"
      ;;
    c)
      CLEAN_OUTPUT=1
      ;;
    -)
      case $OPTARG in
        clean)
          CLEAN_OUTPUT=1
          ;;
        *)
          echo "Usage: $0 [-f <file.ll>] [-c|--clean]"
          exit 1
          ;;
      esac
      ;;
    *)
      echo "Usage: $0 [-f <file.ll>] [-c|--clean]"
      exit 1
      ;;
  esac
done

if [ $CLEAN_OUTPUT -eq 1 ]; then
  if [ -d "$OUTPUT_DIR" ]; then
    rm -rf "$OUTPUT_DIR"
    echo "Removed $OUTPUT_DIR."
  fi
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

  # Move any *.parent_module.ll files to the output directory
  shopt -s nullglob
  for pm_file in *.parent_module.ll; do
    mv "$pm_file" "$output_dir/"
  done
  shopt -u nullglob
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
