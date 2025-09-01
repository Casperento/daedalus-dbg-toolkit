#!/bin/bash
opt -stats \
    -passes=daedalus \
    -load-pass-plugin ~/src/github/Daedalus/build/lib/libdaedalus.so \
    -disable-output \
    $1 \
    |& grep -E 'Assertion `(.+) failed\.'
