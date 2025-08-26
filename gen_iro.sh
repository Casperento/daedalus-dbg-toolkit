#!/usr/bin/env bash
#
# Script: gen_iro.sh
#
set -euo pipefail
IFS=$'\n\t'

# Default configuration
LLVM_PROJECT="$HOME/src/github/llvm-project"
LLVM_TEST_SUITE="$HOME/src/github/llvm-test-suite"
ERRORS_DBG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # current script directory
LIT_RESULTS="$HOME/lit-results"
WORKERS=10
TIMEOUT=120
CLEAN=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -h, --help               Show this help message and exit
  -c, --clean              Clean build directories before building
  -w, --workers <n>        Number of parallel workers (default: $WORKERS)
  -t, --timeout <n>        Timeout to set for LIT (default $TIMEOUT)
  --llvm-project <path>    Path to LLVM project (default: $LLVM_PROJECT)
  --llvm-test-suite <path> Path to LLVM test suite (default: $LLVM_TEST_SUITE)
  --errors-dbg <path>      Directory for LIT log output (default: $ERRORS_DBG)
  --lit-results <path>     Directory for LIT results JSON (default: $LIT_RESULTS)
EOF
}

# Parse arguments
if ! PARSED=$(getopt -o hcub:w:t: --long help,clean,workers:,timeout:,llvm-project:,llvm-test-suite:,errors-dbg:,lit-results: -n "$(basename "$0")" -- "$@"); then
  usage; exit 1
fi
eval set -- "$PARSED"
while true; do
  case "$1" in
    -h|--help) usage; exit 0;;
    -c|--clean) CLEAN=true; shift;;
    -w|--workers) WORKERS="$2"; shift 2;;
    -t|--timeout) TIMEOUT="$2"; shift 2;;
    --llvm-project) LLVM_PROJECT="$2"; shift 2;;
    --llvm-test-suite) LLVM_TEST_SUITE="$2"; shift 2;;
    --errors-dbg) ERRORS_DBG="$2"; shift 2;;
    --lit-results) LIT_RESULTS="$2"; shift 2;;
    --) shift; break;;
    *) echo "Unknown option: $1"; usage; exit 1;;
  esac
done

# Validate directories
for dir in "$LLVM_PROJECT" "$LLVM_TEST_SUITE" "$ERRORS_DBG" "$LIT_RESULTS"; do
  if [[ ! -d "$dir" ]]; then
    echo "Error: Directory '$dir' does not exist." >&2
    exit 1
  fi
done

# Clean step
if [[ "$CLEAN" == true ]]; then
  echo "Cleaning build directories..."
  rm -rf "$LLVM_TEST_SUITE/build"/* && echo "- Cleared $LLVM_TEST_SUITE/build"
fi

script_start_time=$(date +%s)
echo "$script_start_time" > "$ERRORS_DBG/experiment-start-time.log"

# Build LLVM test suite
echo "Building LLVM test suite with IROutliner pass..."
# iroutliner configuration
cmake -G Ninja \
 -DCMAKE_C_COMPILER=clang \
 -DCMAKE_CXX_COMPILER=clang++ \
 -DCMAKE_C_FLAGS="-flto" \
 -DCMAKE_CXX_FLAGS="-flto" \
 -DCMAKE_EXE_LINKER_FLAGS="-flto -fuse-ld=lld -Wl,--plugin-opt=-lto-embed-bitcode=post-merge-pre-opt" \
 -DTEST_SUITE_COLLECT_INSTCOUNT=ON \
 -DTEST_SUITE_SELECTED_PASSES=iroutliner \
 -DTEST_SUITE_PASSES_ARGS= \
 -DTEST_SUITE_COLLECT_COMPILE_TIME=OFF \
 "-DTEST_SUITE_SUBDIRS=SingleSource;MultiSource" \
 -C "$LLVM_TEST_SUITE/cmake/caches/Os.cmake" \
 -S "$LLVM_TEST_SUITE" \
 -B "$LLVM_TEST_SUITE/build"

# SPEC2017 configuration
# cmake -G Ninja \
#   -DCMAKE_C_COMPILER=clang \
#   -DCMAKE_CXX_COMPILER=clang++ \
#   -DCMAKE_C_FLAGS="-flto" \
#   -DCMAKE_CXX_FLAGS="-flto" \
#   -DCMAKE_EXE_LINKER_FLAGS="-flto -fuse-ld=lld -Wl,--plugin-opt=-lto-embed-bitcode=post-merge-pre-opt" \
#   -DTEST_SUITE_COLLECT_INSTCOUNT=ON \
#   -DTEST_SUITE_SELECTED_PASSES=iroutliner \
#   -DTEST_SUITE_COLLECT_COMPILE_TIME=OFF \
#   -DTEST_SUITE_SUBDIRS=External \
#   -DTEST_SUITE_SPEC2017_ROOT="$LLVM_TEST_SUITE/test-suite-externals/speccpu2017" \
#   -DTEST_SUITE_RUN_TYPE=train \
#   -C "$LLVM_TEST_SUITE/cmake/caches/Os.cmake" \
#   -S "$LLVM_TEST_SUITE" \
#   -B "$LLVM_TEST_SUITE/build"

# Allow build errors but continue
if ! cmake --build "$LLVM_TEST_SUITE/build" -- -k 0 -j "$WORKERS"; then
  echo "Warning: Build errors detected in test suite; proceeding to LIT tests." >&2
fi

# Run LIT tests
echo "Running LIT tests..."
if ! python3 $(which llvm-lit) \
     --time-tests \
     --ignore-fail \
     --verbose \
     --timeout $TIMEOUT \
     -j "$WORKERS" \
     -s \
     -o "$LIT_RESULTS/iroutliner.json" \
     "$LLVM_TEST_SUITE/build" \
     | tee -a "$ERRORS_DBG/lit-output.log"; then
  echo "Error: LIT tests failed. Log saved to $ERRORS_DBG/lit-output.log" >&2
fi

# Post-process errors
echo "Extracting errors..."
"$ERRORS_DBG/list-errors-iro.sh" \
  --build-dir "$LLVM_TEST_SUITE/build" \
  --results-dir "$LIT_RESULTS" \
  --clear

exit 0
