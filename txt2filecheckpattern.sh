#!/bin/bash
# filepath: $HOME/src/github/errors-dbg-framework/txt2filecheckpattern.sh

# Parse arguments using getopt
usage() {
    echo "Usage: $0 -f, --file <inputfile>"
    exit 1
}

OPTS=$(getopt -o f:h --long file:,help -n 'parse-options' -- "$@")
if [ $? != 0 ]; then usage; fi

eval set -- "$OPTS"

INPUTFILE=""
while true; do
  case "$1" in
    -f | --file ) INPUTFILE="$2"; shift 2 ;;
    -h | --help ) usage ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

if [ -z "$INPUTFILE" ]; then
    usage
fi

# Apply sed transformations to the input file
sed -i '1s/^/; CHECK: /' "$INPUTFILE"
sed -i 's/^/; CHECK-NEXT: /g' "$INPUTFILE"
sed -i 's/^; CHECK-NEXT: $/; CHECK-EMPTY:/g' "$INPUTFILE"
sed -i '1s/; CHECK-NEXT: //g' "$INPUTFILE"
sed -i 's/__[0-9]\+(/__[[ID:[0-9]+]](/g' "$INPUTFILE"
