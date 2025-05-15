#!/bin/bash
opt -stats \
    -passes=daedalus \
    -load-pass-plugin ~/src/github/Daedalus/build/lib/libdaedalus.so \
    -debug-only=daedalus,ProgramSlice \
    -disable-output \
    $1 \
    |& grep -E 'Assertion `(.+) failed\.'
