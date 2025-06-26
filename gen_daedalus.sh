#!/usr/bin/env bash
#
# Script: gen_daedalus.sh
#
# Brief: Automates cleaning, updating, building, and testing the Daedalus LLVM pass
#        alongside the LLVM Test Suite. Continues to run LIT tests and error
#        processing even if there are build failures in the test suite.
#
# Usage examples:
#  # Clean, build, then run LIT
#  ./gen_daedalus.sh --clean
#
#  # Update Daedalus to 'dev' branch and use 16 workers
#  ./gen_daedalus.sh --upgrade --branch dev --workers 16
#
#  # Override default paths
#  ./gen_daedalus.sh \
#      --llvm-project=/path/to/llvm-project \
#      --llvm-test-suite=/path/to/llvm-test-suite
#
set -euo pipefail
IFS=$'\n\t'

# Default configuration
LLVM_PROJECT="$HOME/src/github/llvm-project"
LLVM_TEST_SUITE="$HOME/src/github/llvm-test-suite"
DAEDALUS="$HOME/src/github/Daedalus"
ERRORS_DBG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # current script directory
LIT_RESULTS="$HOME/lit-results"
DAEDALUS_BRANCH="main"
WORKERS=10
TIMEOUT=120
CLEAN=false
UPGRADE=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -h, --help               Show this help message and exit
  -c, --clean              Clean build directories before building
  -u, --upgrade            Fetch and pull latest Daedalus commits
  -b, --branch <name>      Checkout this Daedalus branch (default: $DAEDALUS_BRANCH)
  -w, --workers <n>        Number of parallel workers (default: $WORKERS)
  -t, --timeout <n>        Timeout to set for LIT (default $TIMEOUT)
  --llvm-project <path>    Path to LLVM project (default: $LLVM_PROJECT)
  --llvm-test-suite <path> Path to LLVM test suite (default: $LLVM_TEST_SUITE)
  --daedalus <path>        Path to Daedalus project (default: $DAEDALUS)
  --errors-dbg <path>      Directory for LIT log output (default: $ERRORS_DBG)
  --lit-results <path>     Directory for LIT results JSON (default: $LIT_RESULTS)
  --max-slice-params <n>   Set -max-slice-params for Daedalus pass (default: 5)
  --max-slice-size <n>     Set -max-slice-size for Daedalus pass (default: 40)
  --max-slice-users <n>    Set -max-slice-users for Daedalus pass (default: 100)
EOF
}

# Default values for new options
MAX_SLICE_PARAMS=5
MAX_SLICE_SIZE=40
MAX_SLICE_USERS=100

# Parse arguments
if ! PARSED=$(getopt -o hcub:w:t: --long help,clean,upgrade,branch:,workers:,timeout:,llvm-project:,llvm-test-suite:,daedalus:,errors-dbg:,lit-results:,max-slice-params:,max-slice-size:,max-slice-users: -n "$(basename "$0")" -- "$@"); then
  usage; exit 1
fi
eval set -- "$PARSED"
while true; do
  case "$1" in
    -h|--help) usage; exit 0;;
    -c|--clean) CLEAN=true; shift;;
    -u|--upgrade) UPGRADE=true; shift;;
    -b|--branch) DAEDALUS_BRANCH="$2"; shift 2;;
    -w|--workers) WORKERS="$2"; shift 2;;
    -t|--timeout) TIMEOUT="$2"; shift 2;;
    --llvm-project) LLVM_PROJECT="$2"; shift 2;;
    --llvm-test-suite) LLVM_TEST_SUITE="$2"; shift 2;;
    --daedalus) DAEDALUS="$2"; shift 2;;
    --errors-dbg) ERRORS_DBG="$2"; shift 2;;
    --lit-results) LIT_RESULTS="$2"; shift 2;;
    --max-slice-params) MAX_SLICE_PARAMS="$2"; shift 2;;
    --max-slice-size) MAX_SLICE_SIZE="$2"; shift 2;;
    --max-slice-users) MAX_SLICE_USERS="$2"; shift 2;;
    --) shift; break;;
    *) echo "Unknown option: $1"; usage; exit 1;;
  esac
done

# Validate directories
for dir in "$LLVM_PROJECT" "$LLVM_TEST_SUITE" "$DAEDALUS" "$ERRORS_DBG" "$LIT_RESULTS"; do
  if [[ ! -d "$dir" ]]; then
    echo "Error: Directory '$dir' does not exist." >&2
    exit 1
  fi
done

# Clean step
if [[ "$CLEAN" == true ]]; then
  echo "Cleaning build directories..."
  rm -rf "$LLVM_TEST_SUITE/build"/* && echo "- Cleared $LLVM_TEST_SUITE/build"
  rm -rf "$DAEDALUS/build"/*        && echo "- Cleared $DAEDALUS/build"
fi

# Upgrade step
if [[ "$UPGRADE" == true ]]; then
  echo "Updating Daedalus repo (branch: $DAEDALUS_BRANCH)..."
  # Prevent uncommitted changes
  if [[ -n $(git -C "$DAEDALUS" status --porcelain) ]]; then
    echo "Error: Uncommitted changes in $DAEDALUS. Please commit or stash them." >&2
    exit 1
  fi
  git -C "$DAEDALUS" fetch
  git -C "$DAEDALUS" checkout "$DAEDALUS_BRANCH"
  git -C "$DAEDALUS" pull
fi

script_start_time=$(date +%s)
echo "$script_start_time" > "$ERRORS_DBG/experiment-start-time.log"

# Build Daedalus
echo "Building libdaedalus.so..."
cmake -G Ninja -DLLVM_DIR="$LLVM_PROJECT" -S "$DAEDALUS" -B "$DAEDALUS/build"
cmake --build "$DAEDALUS/build"

# Build LLVM test suite
echo "Building LLVM test suite with Daedalus plugin..."
# Only add max-slice-* args if any were explicitly set by the user
MAX_ARGS_SET=false
if [[ ${MAX_SLICE_PARAMS} != 5 ]] || [[ ${MAX_SLICE_SIZE} != 40 ]] || [[ ${MAX_SLICE_USERS} != 100 ]]; then
  MAX_ARGS_SET=true
  echo "MAX_SLICE_PARAMS=$MAX_SLICE_PARAMS"
  echo "MAX_SLICE_SIZE=$MAX_SLICE_SIZE"
  echo "MAX_SLICE_USERS=$MAX_SLICE_USERS"
fi

if [[ $MAX_ARGS_SET == true ]]; then
  cmake -G Ninja \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_FLAGS="-flto" \
    -DCMAKE_CXX_FLAGS="-flto" \
    -DCMAKE_EXE_LINKER_FLAGS="-flto -fuse-ld=lld -Wl,--plugin-opt=-lto-embed-bitcode=post-merge-pre-opt" \
    -DTEST_SUITE_COLLECT_INSTCOUNT=ON \
    -DTEST_SUITE_SELECTED_PASSES=daedalus \
    -DTEST_SUITE_PASSES_ARGS=-load-pass-plugin=$DAEDALUS/build/lib/libdaedalus.so\;-max-slice-params=$MAX_SLICE_PARAMS\;-max-slice-size=$MAX_SLICE_SIZE\;-max-slice-users=$MAX_SLICE_USERS \
    -DTEST_SUITE_COLLECT_COMPILE_TIME=OFF \
    "-DTEST_SUITE_SUBDIRS=SingleSource;MultiSource" \
    -C "$LLVM_TEST_SUITE/cmake/caches/Os.cmake" \
    -S "$LLVM_TEST_SUITE" -B "$LLVM_TEST_SUITE/build"

  # SPEC2017 configuration
  # cmake -G Ninja \
  #   -DCMAKE_C_COMPILER=clang \
  #   -DCMAKE_CXX_COMPILER=clang++ \
  #   -DCMAKE_C_FLAGS="-flto" \
  #   -DCMAKE_CXX_FLAGS="-flto" \
  #   -DCMAKE_EXE_LINKER_FLAGS="-flto -fuse-ld=lld -Wl,--plugin-opt=-lto-embed-bitcode=post-merge-pre-opt" \
  #   -DTEST_SUITE_COLLECT_INSTCOUNT=ON \
  #   -DTEST_SUITE_SELECTED_PASSES=daedalus \
  #   -DTEST_SUITE_PASSES_ARGS="-load-pass-plugin=$DAEDALUS/build/lib/libdaedalus.so;-max-slice-params=$MAX_SLICE_PARAMS;-max-slice-size=$MAX_SLICE_SIZE;-max-slice-users=$MAX_SLICE_USERS" \
  #   -DTEST_SUITE_COLLECT_COMPILE_TIME=OFF \
  #   -DTEST_SUITE_SUBDIRS=External \
  #   "-DTEST_SUITE_SPEC2017_ROOT=$LLVM_TEST_SUITE/test-suite-externals/speccpu2017" \
  #   -DTEST_SUITE_RUN_TYPE=train \
  #   -C "$LLVM_TEST_SUITE/cmake/caches/Os.cmake" \
  #   -S "$LLVM_TEST_SUITE" \
  #   -B "$LLVM_TEST_SUITE/build"
else
  cmake -G Ninja \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_FLAGS="-flto" \
    -DCMAKE_CXX_FLAGS="-flto" \
    -DCMAKE_EXE_LINKER_FLAGS="-flto -fuse-ld=lld -Wl,--plugin-opt=-lto-embed-bitcode=post-merge-pre-opt" \
    -DTEST_SUITE_COLLECT_INSTCOUNT=ON \
    -DTEST_SUITE_SELECTED_PASSES=daedalus \
    -DTEST_SUITE_PASSES_ARGS=-load-pass-plugin=$DAEDALUS/build/lib/libdaedalus.so \
    -DTEST_SUITE_COLLECT_COMPILE_TIME=OFF \
    "-DTEST_SUITE_SUBDIRS=SingleSource;MultiSource" \
    -C "$LLVM_TEST_SUITE/cmake/caches/Os.cmake" \
    -S "$LLVM_TEST_SUITE" \
    -B "$LLVM_TEST_SUITE/build"

  #   cmake -G Ninja \
  # -DCMAKE_C_COMPILER=clang \
  # -DCMAKE_CXX_COMPILER=clang++ \
  # -DCMAKE_C_FLAGS="-flto" \
  # -DCMAKE_CXX_FLAGS="-flto" \
  # -DCMAKE_EXE_LINKER_FLAGS="-flto -fuse-ld=lld -Wl,--plugin-opt=-lto-embed-bitcode=post-merge-pre-opt" \
  # -DTEST_SUITE_COLLECT_INSTCOUNT=ON \
  # -DTEST_SUITE_SELECTED_PASSES=func-merging \
  # -DTEST_SUITE_PASSES_ARGS= \
  # -DTEST_SUITE_COLLECT_COMPILE_TIME=OFF \
  # "-DTEST_SUITE_SUBDIRS=SingleSource;MultiSource" \
  # -C "$LLVM_TEST_SUITE/cmake/caches/Os.cmake" \
  # -S "$LLVM_TEST_SUITE" \
  # -B "$LLVM_TEST_SUITE/build"

  # SPEC2017 configuration
  # cmake -G Ninja \
  #   -DCMAKE_C_COMPILER=clang \
  #   -DCMAKE_CXX_COMPILER=clang++ \
  #   -DCMAKE_C_FLAGS="-flto" \
  #   -DCMAKE_CXX_FLAGS="-flto" \
  #   -DCMAKE_EXE_LINKER_FLAGS="-flto -fuse-ld=lld -Wl,--plugin-opt=-lto-embed-bitcode=post-merge-pre-opt" \
  #   -DTEST_SUITE_COLLECT_INSTCOUNT=ON \
  #   -DTEST_SUITE_SELECTED_PASSES=daedalus \
  #   -DTEST_SUITE_PASSES_ARGS=-load-pass-plugin="$DAEDALUS/build/lib/libdaedalus.so" \
  #   -DTEST_SUITE_COLLECT_COMPILE_TIME=OFF \
  #   -DTEST_SUITE_SUBDIRS=External \
  #   -DTEST_SUITE_SPEC2017_ROOT="$LLVM_TEST_SUITE/test-suite-externals/speccpu2017" \
  #   -DTEST_SUITE_RUN_TYPE=train \
  #   -C "$LLVM_TEST_SUITE/cmake/caches/Os.cmake" \
  #   -S "$LLVM_TEST_SUITE" \
  #   -B "$LLVM_TEST_SUITE/build"
fi

# Allow build errors but continue
if ! cmake --build "$LLVM_TEST_SUITE/build" -- -k 0 -j "$WORKERS"; then
  echo "Warning: Build errors detected in test suite; proceeding to LIT tests." >&2
fi

# Run LIT tests
echo "Running LIT tests..."
# if ! llvm-lit \
#      --time-tests \
#      --ignore-fail \
#      --verbose \
#      --filter-out "GCC-C-execute.*" \
#      --timeout $TIMEOUT \
#      -j "$WORKERS" \
#      -s \
#      -o "$LIT_RESULTS/daedalus.json" \
#      "$LLVM_TEST_SUITE/build" \
#      | tee -a "$ERRORS_DBG/lit-output.log"; then
#   echo "Error: LIT tests failed. Log saved to $ERRORS_DBG/lit-output.log" >&2
# fi
if ! llvm-lit \
     --time-tests \
     --ignore-fail \
     --verbose \
     --timeout $TIMEOUT \
     -j "$WORKERS" \
     -s \
     -o "$LIT_RESULTS/daedalus.json" \
     "$LLVM_TEST_SUITE/build" \
     | tee -a "$ERRORS_DBG/lit-output.log"; then
  echo "Error: LIT tests failed. Log saved to $ERRORS_DBG/lit-output.log" >&2
fi

# Post-process errors
echo "Extracting errors..."
"$ERRORS_DBG/list-errors.sh" \
  --build-dir "$LLVM_TEST_SUITE/build" \
  --plugin-dir "$DAEDALUS/build/lib" \
  --results-dir "$LIT_RESULTS" \
  --clear

exit 0
