#!/bin/bash
# Generates baseline.json for llvm-test-suite

LLVM_TEST_SUITE="/home/reckstein/src/github/llvm-test-suite"
LIT_RESULTS="/home/reckstein/lit-results"
TIMEOUT=120
WORKERS=10

if [[ "$1" == "clean" ]]; then
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
      -C  "$LLVM_TEST_SUITE/cmake/caches/Os.cmake" \
      -S "$LLVM_TEST_SUITE" \
      -B "$LLVM_TEST_SUITE/build"

cmake --build "$LLVM_TEST_SUITE/build" -- -k 0 -j 10

llvm-lit --filter-out "GCC-C-execute.*" --timeout $TIMEOUT -j $WORKERS -s -o "$LIT_RESULTS/baseline.json" "$LLVM_TEST_SUITE/build"
