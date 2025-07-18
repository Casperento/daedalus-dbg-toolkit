#!/bin/bash

SOURCESFOLDER=$1

echo -e "Reducing faulty programs to a minimal faulty program for debugging...\n"

if [ -d "$SOURCESFOLDER" ]; then
    for llfile in "$SOURCESFOLDER"/*.ll; do
        echo -e "Reducing $llfile..."
        if llvm-reduce -j 10 "--test=script.sh" "$llfile" > /dev/null 2>&1; then
            NEWNAME="${llfile/.e./.reduced.}"
            mv reduced.ll "$NEWNAME"
            echo -e "Successfully reduced $llfile to $SOURCESFOLDER/$NEWNAME\n"
        else
            echo -e "Failed to reduce $llfile\n"
        fi
    done
else
    llfile="$SOURCESFOLDER"
    echo -e "Reducing $llfile..."
    if llvm-reduce -j 10 "--test=script.sh" "$llfile" > /dev/null 2>&1; then
        NEWNAME="${llfile/.e./.reduced.}"
        mv reduced.ll "$NEWNAME"
        echo -e "Successfully reduced $llfile to $NEWNAME\n"
    else
        echo -e "Failed to reduce $llfile\n"
    fi
fi
