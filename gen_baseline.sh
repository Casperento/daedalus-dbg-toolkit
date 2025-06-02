#!/bin/bash
# Generates baseline.json for llvm-test-suite by building and running tests with specific configurations.

LLVM_TEST_SUITE="/home/reckstein/src/github/llvm-test-suite"
LIT_RESULTS="/home/reckstein/lit-results"
TIMEOUT=120
WORKERS=10

function usage() {
    echo "Usage: $0 [clean]"
    echo "  clean: Removes and recreates the build directory before proceeding."
    exit 1
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

if [[ "$1" == "clean" ]]; then
    if [[ -d "$LLVM_TEST_SUITE/build" ]]; then
        rm -rf "$LLVM_TEST_SUITE/build/"*
    else
        mkdir -p "$LLVM_TEST_SUITE/build"
    fi
elif [[ -n "$1" ]]; then
    echo "Error: Unknown argument '$1'"
    usage
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
      -C  "$LLVM_TEST_SUITE/cmake/caches/Os.cmake" \
      -S "$LLVM_TEST_SUITE" \
      -B "$LLVM_TEST_SUITE/build"

cmake --build "$LLVM_TEST_SUITE/build" -- -k 0 -j $WORKERS

llvm-lit \
--filter-out "GCC-C-execute.*" \
--timeout $TIMEOUT \
-j $WORKERS \
-s \
-o "$LIT_RESULTS/baseline.json" \
"$LLVM_TEST_SUITE/build"

# llvm-lit \
# --timeout $TIMEOUT \
# -j $WORKERS \
# -s \
# -o "$LIT_RESULTS/baseline.json" \
# "$LLVM_TEST_SUITE/build"