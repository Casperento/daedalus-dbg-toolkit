#!/bin/bash

SOURCES_DIR="./output/sources"
OUTPUT_DIR="./output/extended_bc_logs"

if [ ! -d "$OUTPUT_DIR" ]; then
  mkdir -p "$OUTPUT_DIR"
else
  rm -rf "$OUTPUT_DIR"
fi

# Check if sources directory exists
if [ ! -d "$SOURCES_DIR" ]; then
  echo "Error: Source directory '$SOURCES_DIR' not found."
  exit 1
fi

# Iterate over each .ll file in the sources directory
for source_file in "$SOURCES_DIR"/*.ll; do
  if [ -f "$source_file" ]; then
    filename=$(basename "$source_file" .ll)
    filename=$(basename "$filename" .e)
    output_file="$OUTPUT_DIR/${filename}_errors.log"

    echo "Processing $source_file..."

    opt -stats \
        -debug-only=daedalus,ProgramSlice \
        -passes=daedalus \
        -load-pass-plugin ~/src/github/Daedalus/build/lib/libdaedalus.so \
        -disable-output "$source_file" \
        &> "$output_file"
  fi
done

echo "Error log generation complete."
