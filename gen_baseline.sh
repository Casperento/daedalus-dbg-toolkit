#!/bin/bash
# Generates baseline.json for llvm-test-suite by building and running tests with specific configurations.

LLVM_TEST_SUITE="$HOME/src/github/llvm-test-suite"
LIT_RESULTS="$HOME/lit-results"
TIMEOUT=120
WORKERS=10

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -h, --help               Show this help message and exit
  -c, --clean              Clean build directory before building
  -w, --workers <n>        Number of parallel workers (default: $WORKERS)
  -t, --timeout <n>        Timeout to set for LIT (default $TIMEOUT)
  --llvm-test-suite <path> Path to LLVM test suite (default: $LLVM_TEST_SUITE)
  --lit-results <path>     Directory for LIT results JSON (default: $LIT_RESULTS)
EOF
}

# Parse arguments
if ! PARSED=$(getopt -o hcw:t: --long help,clean,workers:,timeout:,llvm-test-suite:,lit-results: -n "$(basename "$0")" -- "$@"); then
    usage; exit 1
fi
eval set -- "$PARSED"
CLEAN=false
while true; do
    case "$1" in
        -h|--help) usage; exit 0;;
        -c|--clean) CLEAN=true; shift;;
        -w|--workers) WORKERS="$2"; shift 2;;
        -t|--timeout) TIMEOUT="$2"; shift 2;;
        --llvm-test-suite) LLVM_TEST_SUITE="$2"; shift 2;;
        --lit-results) LIT_RESULTS="$2"; shift 2;;
        --) shift; break;;
        *) echo "Unknown option: $1"; usage; exit 1;;
    esac
done

# Clean step
if [[ "$CLEAN" == true ]]; then
    if [[ -d "$LLVM_TEST_SUITE/build" ]]; then
        rm -rf "$LLVM_TEST_SUITE/build/"*
    else
        mkdir -p "$LLVM_TEST_SUITE/build"
    fi
fi

cmake -G "Ninja" \
      -DCMAKE_C_COMPILER=clang \
      -DCMAKE_CXX_COMPILER=clang++ \
      -DCMAKE_C_FLAGS="-flto" \
      -DCMAKE_CXX_FLAGS="-flto" \
      -DCMAKE_EXE_LINKER_FLAGS="-flto -fuse-ld=lld -Wl,--plugin-opt=-lto-embed-bitcode=post-merge-pre-opt" \
      -DTEST_SUITE_COLLECT_INSTCOUNT=ON \
      -DTEST_SUITE_SELECTED_PASSES= \
      -DTEST_SUITE_PASSES_ARGS= \
      -DTEST_SUITE_COLLECT_COMPILE_TIME=OFF \
      "-DTEST_SUITE_SUBDIRS=SingleSource;MultiSource" \
      -C "$LLVM_TEST_SUITE/cmake/caches/Os.cmake" \
      -S "$LLVM_TEST_SUITE" \
      -B "$LLVM_TEST_SUITE/build"

# SPEC2017 configuration
# cmake -G "Ninja" \
#       -DCMAKE_C_COMPILER=clang \
#       -DCMAKE_CXX_COMPILER=clang++ \
#       -DCMAKE_C_FLAGS="-flto" \
#       -DCMAKE_CXX_FLAGS="-flto" \
#       -DCMAKE_EXE_LINKER_FLAGS="-flto -fuse-ld=lld -Wl,--plugin-opt=-lto-embed-bitcode=post-merge-pre-opt" \
#       -DTEST_SUITE_COLLECT_INSTCOUNT=ON \
#       -DTEST_SUITE_SELECTED_PASSES= \
#       -DTEST_SUITE_PASSES_ARGS= \
#       -DTEST_SUITE_COLLECT_COMPILE_TIME=OFF \
#       -DTEST_SUITE_SUBDIRS=External \
#       -DTEST_SUITE_SPEC2017_ROOT="$LLVM_TEST_SUITE/test-suite-externals/speccpu2017" \
#       -DTEST_SUITE_RUN_TYPE=train \
#       -C "$LLVM_TEST_SUITE/cmake/caches/Os.cmake" \
#       -S "$LLVM_TEST_SUITE" \
#       -B "$LLVM_TEST_SUITE/build"

cmake --build "$LLVM_TEST_SUITE/build" -- -k 0 -j $WORKERS

# llvm-lit \
# --filter-out "GCC-C-execute.*" \
# --timeout $TIMEOUT \
# -j $WORKERS \
# -s \
# -o "$LIT_RESULTS/baseline.json" \
# "$LLVM_TEST_SUITE/build"

llvm-lit \
--timeout $TIMEOUT \
-j $WORKERS \
-s \
-o "$LIT_RESULTS/baseline.json" \
"$LLVM_TEST_SUITE/build"