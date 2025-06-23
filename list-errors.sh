#!/usr/bin/env bash
#
# Script: list-errors.sh
#
# Brief: Processes LIT test outputs and comparison results to extract failing tests,
#        generate LLVM IR sources, and collate error logs for analysis.
#        Supports configurable build, plugin, results, and output directories.
#
# Usage examples:
#  # Basic invocation with positional args
#  ./list-errors.sh /path/to/build /path/to/libdaedalus /path/to/lit-results
#
#  # Using long-form options
#  ./list-errors.sh \
#      --build-dir=/path/to/build \
#      --plugin-dir=/path/to/libdaedalus \
#      --results-dir=/path/to/lit-results \
#      --output-dir=/path/to/output
#
set -euo pipefail
IFS=$'\n\t'

# Default directories (will be overridden by args)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR=""
PLUGIN_DIR=""
RESULTS_DIR=""
OUTPUT_DIR="$SCRIPT_DIR/output"

# Derived paths (initialized later)
LOG_FILE=""
SOURCES_DIR=""
BC_LOGS_DIR=""
SCRIPT_LOGS_DIR=""
FILES_LIST=""
COMPARISON_RESULTS=""

# Record the start time of the script
if [[ -f "$SCRIPT_DIR/experiment-start-time.log" ]]; then
  script_start_time=$(cat "$SCRIPT_DIR/experiment-start-time.log")
else
  script_start_time=$(date +%s)
fi

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -h, --help                Show this help message and exit
  --build-dir <path>        LLVM Test Suite build folder (required)
  --plugin-dir <path>       Folder containing libdaedalus.so (required)
  --results-dir <path>      LIT results folder with JSON files (required)
  --output-dir <path>       Output base directory (default: $OUTPUT_DIR)
  --print-dots              Print dots after processing (default: no)
  --clear                   Clear output directories before processing (default: no)
EOF
}

# Parse options
PRINT_DOTS=false
CLEAR_OUTPUT=false
PARSED=$(getopt -o h --long help,build-dir:,plugin-dir:,results-dir:,output-dir:,print-dots,clear -n "$(basename "$0")" -- "$@")
eval set -- "$PARSED"
while true; do
  case "$1" in
    -h|--help)
      usage; exit 0;;
    --build-dir)
      BUILD_DIR="$2"; shift 2;;
    --plugin-dir)
      PLUGIN_DIR="$2"; shift 2;;
    --results-dir)
      RESULTS_DIR="$2"; shift 2;;
    --output-dir)
      OUTPUT_DIR="$2"; shift 2;;
    --print-dots)
      PRINT_DOTS=true; shift;;
    --clear)
      CLEAR_OUTPUT=true; shift;;
    --)
      shift; break;;
    *)
      echo "Unknown option: $1" >&2; usage; exit 1;;
  esac
done

# Ensure required arguments are provided
if [[ -z "$BUILD_DIR" || -z "$PLUGIN_DIR" || -z "$RESULTS_DIR" ]]; then
  echo "ERROR: --build-dir, --plugin-dir, and --results-dir are required." >&2
  usage; exit 1
fi

# Compute script and derived paths
LOG_FILE="$SCRIPT_DIR/list-errors.log"
SOURCES_DIR="$OUTPUT_DIR/sources"
BC_LOGS_DIR="$OUTPUT_DIR/bc_logs"
SCRIPT_LOGS_DIR="$OUTPUT_DIR/script_logs"
FILES_LIST="$SCRIPT_LOGS_DIR/files-list.txt"
COMPARISON_RESULTS="$SCRIPT_DIR/comparison_results.txt"
SOURCES_SUCC_DIR="$OUTPUT_DIR/sources_comparison_failed"
ERRORS_SUMMARY_DIR="$OUTPUT_DIR/errors_summary"

# Preconditions
[[ -d "$BUILD_DIR" ]] || { echo "ERROR: Build directory '$BUILD_DIR' not found." >&2; exit 1; }
[[ -d "$PLUGIN_DIR" ]] || { echo "ERROR: Plugin directory '$PLUGIN_DIR' not found." >&2; exit 1; }
[[ -f "$PLUGIN_DIR/libdaedalus.so" ]] || { echo "ERROR: libdaedalus.so missing in '$PLUGIN_DIR'." >&2; exit 1; }
[[ -d "$RESULTS_DIR" ]] || { echo "ERROR: Results directory '$RESULTS_DIR' not found." >&2; exit 1; }
[[ -f "$RESULTS_DIR/baseline.json" && -f "$RESULTS_DIR/daedalus.json" ]] || \
  { echo "ERROR: Expected JSON files in '$RESULTS_DIR'." >&2; exit 1; }


# Clear output directories if requested
if [[ "${CLEAR_OUTPUT:-false}" == "true" ]]; then
  echo "Clearing output directories..." | tee -a "$LOG_FILE"
  rm -rf "$FILES_LIST" "$SOURCES_DIR" "$BC_LOGS_DIR" "$SCRIPT_LOGS_DIR" "$SOURCES_SUCC_DIR" "$ERRORS_SUMMARY_DIR"
fi

# Prepare output
rm "$LOG_FILE" || true
touch "$LOG_FILE"
mkdir -p "$OUTPUT_DIR" "$SOURCES_DIR" "$BC_LOGS_DIR" "$SCRIPT_LOGS_DIR" "$SOURCES_SUCC_DIR"

# Move existing lit-output.log if present
if [[ -f "$SCRIPT_DIR/lit-output.log" ]]; then
  mv "$SCRIPT_DIR/lit-output.log" "$SCRIPT_LOGS_DIR/"
fi

# Log configuration
cat <<EOF | tee -a "$LOG_FILE"
Build directory  : $BUILD_DIR
Plugin directory : $PLUGIN_DIR
Results directory: $RESULTS_DIR
Output directory : $OUTPUT_DIR
EOF

# Step 1: Filter lit-output logs
echo -e "\nFiltering LIT logs..." | tee -a "$LOG_FILE"
grep --text -B2 ": Compar\(ison failed,\|ed:\)" \
     "$SCRIPT_LOGS_DIR/lit-output.log" \
     | awk '/\s*.reference_output/{print $NF}' \
     | sed 's/.*build\///g' \
     > "$SCRIPT_LOGS_DIR/comparison_failed.log" || true
grep --text -oE ": error: (unable to open|child terminated)(.*)" \
     "$SCRIPT_LOGS_DIR/lit-output.log" \
     | awk '{print $6}' \
     | sed "s/.*build\/\(.*\)'/\1/g" \
     > "$SCRIPT_LOGS_DIR/build_failed.log" || true
grep -A1000 "Slowest Tests:" "$SCRIPT_LOGS_DIR/lit-output.log" \
     | grep -B1000 "Tests Times:" \
     | sed '$d' \
     > "$SCRIPT_LOGS_DIR/slowest_tests.log" || true

echo "Filtered logs written to $SCRIPT_LOGS_DIR" | tee -a "$LOG_FILE"

# Step 2: Generate comparison report
echo -e "\nGenerating comparison report..." | tee -a "$LOG_FILE"
python3 "$BUILD_DIR/../utils/compare.py" \
        --full \
        --diff \
        -m instcount \
        -m size..text \
        "$RESULTS_DIR/baseline.json" \
        "$RESULTS_DIR/daedalus.json" \
        > "$COMPARISON_RESULTS"
echo "Comparison results: $COMPARISON_RESULTS" | tee -a "$LOG_FILE"

# Step 3: List failing test files
grep -oP "(?<=:: ).*?(?=' has no metrics)" "$COMPARISON_RESULTS" \
     | sed 's/\.test$/\.e.bc/' \
     > "$FILES_LIST" || true
echo "Files list: $FILES_LIST" | tee -a "$LOG_FILE"

# Step 4: Extract source .ll files
echo -e "\nExtracting IR to $SOURCES_DIR..." | tee -a "$LOG_FILE"

while IFS= read -r file; do
  src="$BUILD_DIR/$file"
  if [[ -f "$src" ]]; then
    file=$(basename "$file")
    opt -S "$src" -o "$SOURCES_DIR/${file/.e.bc/.ll}"
  else
    echo "Missing: $src" | tee -a "$LOG_FILE"
  fi
done < "$FILES_LIST"

# Step 5: Apply Daedalus pass and log results
echo -e "\nRunning Daedalus pass..." | tee -a "$LOG_FILE"
TOTAL=0; FAILED_BUILD=0; FAILED_COMP=0
while IFS= read -r file; do
  TOTAL=$((TOTAL + 1))
  src="$BUILD_DIR/$file"
  base=$(basename "$file")
  if opt -passes=daedalus \
         -load-pass-plugin="$PLUGIN_DIR/libdaedalus.so" \
         -S "$src" -o "$SOURCES_SUCC_DIR/${base/.e.bc/.d.ll}" 2> "$BC_LOGS_DIR/$base.log"; then
    FAILED_COMP=$((FAILED_COMP + 1))
  else
    FAILED_BUILD=$((FAILED_BUILD + 1))
  fi
done < "$FILES_LIST"

# Summary
cat <<EOF | tee -a "$LOG_FILE"

Processed: $TOTAL
Build failures    : $FAILED_BUILD
Comparison failures: $FAILED_COMP
EOF

# Step 6: Collate error logs
grep -B10 -A50 "PLEASE submit a bug report to" "$BC_LOGS_DIR"/*.log \
  > "$SCRIPT_LOGS_DIR/errors.txt"

# Generate grouped summary
python3 "$SCRIPT_DIR/errors-summary-grouped.py" "$SCRIPT_LOGS_DIR/errors.txt"

# Analyze comparison results
python3 analyze_comparison_results.py > "$SCRIPT_LOGS_DIR/comparison_analysis.txt"
tee -a "$LOG_FILE" < "$SCRIPT_LOGS_DIR/comparison_analysis.txt"
echo -e "--> Comparison analysis written to: $SCRIPT_LOGS_DIR/comparison_analysis.txt"

# Print dots if requested
if [[ "${PRINT_DOTS:-false}" == "true" ]]; then
  bash "$SCRIPT_DIR/print-dots.sh" "$SOURCES_DIR"
fi

script_end_time=$(date +%s)
script_elapsed=$((script_end_time - script_start_time))
echo "Total script runtime: ${script_elapsed} seconds" | tee -a "$LOG_FILE"

exit 0