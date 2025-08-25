#!/usr/bin/env bash
#
# Script: list-errors-iro.sh
#
set -euo pipefail
IFS=$'\n\t'

# Default directories (will be overridden by args)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR=""
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
  --results-dir <path>      LIT results folder with JSON files (required)
  --output-dir <path>       Output base directory (default: $OUTPUT_DIR)
  --print-dots              Print dots after processing (default: no)
  --clear                   Clear output directories before processing (default: no)
  --full-logs               Print full debug logs when calling opt (default: no)
EOF
}

# Parse options
PRINT_DOTS=false
CLEAR_OUTPUT=false
FULL_LOGS=false
PARSED=$(getopt -o h --long help,build-dir:,results-dir:,output-dir:,print-dots,clear,full-logs -n "$(basename "$0")" -- "$@")
eval set -- "$PARSED"
while true; do
  case "$1" in
    -h|--help)
      usage; exit 0;;
    --build-dir)
      BUILD_DIR="$2"; shift 2;;
    --results-dir)
      RESULTS_DIR="$2"; shift 2;;
    --output-dir)
      OUTPUT_DIR="$2"; shift 2;;
    --print-dots)
      PRINT_DOTS=true; shift;;
    --clear)
      CLEAR_OUTPUT=true; shift;;
    --full-logs)
      FULL_LOGS=true; shift;;
    --)
      shift; break;;
    *)
      echo "Unknown option: $1" >&2; usage; exit 1;;
  esac
done

# Ensure required arguments are provided
if [[ -z "$BUILD_DIR" || -z "$RESULTS_DIR" ]]; then
  echo "ERROR: --build-dir, and --results-dir are required." >&2
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
[[ -d "$RESULTS_DIR" ]] || { echo "ERROR: Results directory '$RESULTS_DIR' not found." >&2; exit 1; }
[[ -f "$RESULTS_DIR/baseline.json" && -f "$RESULTS_DIR/iroutliner.json" ]] || \
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
        "$RESULTS_DIR/iroutliner.json" \
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

# Sort the files list by basename and store the sorted list in FILES_LIST_SORTED
FILES_LIST_SORTED="$SCRIPT_LOGS_DIR/files-list-sorted.txt"
awk '{print $0}' "$FILES_LIST" | while read -r file; do
  echo "$(basename "$file"):$file"
done | sort | cut -d: -f2 > "$FILES_LIST_SORTED"

# Step 5: Apply Daedalus pass and log results
echo -e "\nRunning Daedalus pass..." | tee -a "$LOG_FILE"
TOTAL=0; FAILED_BUILD=0; FAILED_COMP=0
while IFS= read -r file; do
  TOTAL=$((TOTAL + 1))
  src="$BUILD_DIR/$file"
  base=$(basename "$file")
  echo -e "\nRunning opt over: ${file/.e.bc/.ll}" | tee -a "$LOG_FILE"
  if [[ "${FULL_LOGS:-false}" == "true" ]]; then
    if opt -stats -passes=iroutliner \
      -S "$src" -disable-output > /dev/null 2> "$BC_LOGS_DIR/$base.log"; then
      echo -e "\tFailed comparison..." | tee -a "$LOG_FILE"
      FAILED_COMP=$((FAILED_COMP + 1))
      mv "$SCRIPT_DIR"/*_slices_report.log "$BC_LOGS_DIR/" || true
    else
      echo -e "\tFailed build..." | tee -a "$LOG_FILE"
      FAILED_BUILD=$((FAILED_BUILD + 1))
    fi
    mv "$SCRIPT_DIR"/*.parent_module.ll "$SOURCES_SUCC_DIR/" || true
  else
    if opt -passes=iroutliner \
      -S "$src" -o "$SOURCES_SUCC_DIR/${base/.e.bc/.d.ll}" 2> "$BC_LOGS_DIR/$base.log"; then
      echo -e "\tFailed comparison..." | tee -a "$LOG_FILE"
      FAILED_COMP=$((FAILED_COMP + 1))
    else
      echo -e "\tFailed build..." | tee -a "$LOG_FILE"
      FAILED_BUILD=$((FAILED_BUILD + 1))
    fi
  fi
done < "$FILES_LIST_SORTED"

# Summary
cat <<EOF | tee -a "$LOG_FILE"

Processed: $TOTAL
Build failures    : $FAILED_BUILD
Comparison failures: $FAILED_COMP
EOF

# Step 6: Collate error logs
grep -B10 -A50 "PLEASE submit a bug report to" "$BC_LOGS_DIR"/*.log \
  > "$SCRIPT_LOGS_DIR/errors.txt" || true

# Generate grouped summary
python3 "$SCRIPT_DIR/errors-summary-grouped.py" "$SCRIPT_LOGS_DIR/errors.txt"

# Filter faulty functions' names into a file
grep '.*.log-Original' output/script_logs/errors.txt \
| sed 's/\(.*\).e.bc.log-Original function name/\1/g' \
| sed 's/\(.*\)\/bc_logs\/\(.*\):/\1\/sources\/\2.ll/g' \
> "$SCRIPT_LOGS_DIR/faulty_functions.txt" || true

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
