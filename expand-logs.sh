#!/bin/bash

SOURCES_="./output/faulty_sources"
OUTPUT_DIR="./output/extended_bc_logs"
LIBDAEDALUS_DIR="$HOME/src/github/Daedalus/build/lib/libdaedalus.so"
CLEAN_OUTPUT=0

# Parse options
while getopts "f:c-:" opt; do
  case $opt in
    f)
      SOURCES_="$OPTARG"
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
          echo "Usage: $0 [-f <file.ll>/<folder>] [-c|--clean]"
          exit 1
          ;;
      esac
      ;;
    *)
      echo "Usage: $0 [-f <file.ll>/<folder>] [-c|--clean]"
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
      -debug-only=daedalus,ProgramSlice,PHIGateAnalyzer \
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

# If SOURCES_ is a file, process it as a single file
if [ -f "$SOURCES_" ]; then
  process_ll_file "$SOURCES_" "$OUTPUT_DIR" "$LIBDAEDALUS_DIR"
  echo "Error log generation complete."
  exit 0
fi

SOURCES_="${SOURCES_%/}"  # Remove trailing slash if present

# Check if sources directory exists
if [ ! -d "$SOURCES_" ]; then
  echo "Error: Source directory '$SOURCES_' not found."
  exit 1
fi

# Iterate over each .ll file in the sources directory
for source_file in "$SOURCES_"/*.ll; do
  if [ -f "$source_file" ]; then
    process_ll_file "$source_file" "$OUTPUT_DIR" "$LIBDAEDALUS_DIR"
  fi
done

echo "Error log generation complete."
