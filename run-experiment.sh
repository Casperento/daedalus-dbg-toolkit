#!/usr/bin/env bash
#
# Run the experiment for -Os with Daedalus, IROutliner, and func-merging
#
# Usage: ./run-experiment.sh
#

# Default values
WORKERS=10
TIMEOUT=120
VENV="$HOME/src/github/daedalus-dbg-toolkit/venv"
LLVM_PROJECT="$HOME/src/github/llvm-project"
CODE_SIZE="$HOME/src/github/code-size"
LLVM_TEST_SUITE="$HOME/src/github/llvm-test-suite"
DAEDALUS="$HOME/src/github/Daedalus"
ERRORS_DBG="$HOME/src/github/daedalus-dbg-toolkit"
LIT_RESULTS="$HOME/lit-results"

# Argument parsing
print_usage() {
    echo "Usage: $0 [options]"
    echo "  -w, --workers <n>        Number of parallel workers (default: 10)"
    echo "  -t, --timeout <n>        Timeout to set for LIT (default 120)"
    echo "      --venv <path>        Path to Python virtual environment (default: $VENV)"
    echo "      --llvm-project <path>    Path to LLVM project (default: $LLVM_PROJECT)"
    echo "      --code-size <path>       Path to code size llvm-project (default: $CODE_SIZE)"
    echo "      --llvm-test-suite <path> Path to LLVM test suite (default: $LLVM_TEST_SUITE)"
    echo "      --daedalus <path>        Path to Daedalus project (default: $DAEDALUS)"
    echo "      --errors-dbg <path>      Directory for LIT log output (default: $ERRORS_DBG)"
    echo "      --lit-results <path>     Directory for LIT results JSON (default: $LIT_RESULTS)"
    echo "  -h, --help              Show this help message"
}

ARGS=$(getopt -o w:t:h --long workers:,timeout:,llvm-project:,code-size:,llvm-test-suite:,daedalus:,errors-dbg:,lit-results:,help -n "$0" -- "$@")
if [ $? -ne 0 ]; then
    print_usage
    exit 1
fi
eval set -- "$ARGS"
while true; do
    case "$1" in
        -w|--workers)
            WORKERS="$2"; shift 2;;
        -t|--timeout)
            TIMEOUT="$2"; shift 2;;
        --venv)
            VENV="$2"; shift 2;;
        --llvm-project)
            LLVM_PROJECT="$2"; shift 2;;
        --code-size)
            CODE_SIZE="$2"; shift 2;;
        --llvm-test-suite)
            LLVM_TEST_SUITE="$2"; shift 2;;
        --daedalus)
            DAEDALUS="$2"; shift 2;;
        --errors-dbg)
            ERRORS_DBG="$2"; shift 2;;
        --lit-results)
            LIT_RESULTS="$2"; shift 2;;
        -h|--help)
            print_usage; exit 0;;
        --)
            shift; break;;
        *)
            echo "Unknown option: $1"; print_usage; exit 1;;
    esac
done


# Activate python venv only if VENV is set and non-empty
if [ -n "$VENV" ]; then
    if [ -f "$VENV/bin/activate" ]; then
        source "$VENV/bin/activate"
    else
        echo "Warning: Python virtual environment activation script not found at $VENV/bin/activate. Skipping venv activation."
    fi
else
    echo "VENV variable not set. Skipping venv activation."
fi

# Os baseline setup and running
./gen_baseline.sh -c -w "$WORKERS" -t "$TIMEOUT" \
    --llvm-test-suite "$LLVM_TEST_SUITE" \
    --lit-results "$LIT_RESULTS"

# Daedalus setup and running
./gen_daedalus.sh -b main -u -c --max-slice-params 1 --max-slice-size 20 --max-slice-users 10 \
    -w "$WORKERS" -t "$TIMEOUT" \
    --llvm-project "$LLVM_PROJECT" \
    --llvm-test-suite "$LLVM_TEST_SUITE" \
    --daedalus "$DAEDALUS" \
    --errors-dbg "$ERRORS_DBG" \
    --lit-results "$LIT_RESULTS"

# IROutliner setup and running

./gen_iro.sh -c -w "$WORKERS" -t "$TIMEOUT" \
    --llvm-project "$LLVM_PROJECT" \
    --llvm-test-suite "$LLVM_TEST_SUITE" \
    --errors-dbg "$ERRORS_DBG" \
    --lit-results "$LIT_RESULTS"

# func-merging setup and running
export PATH="$CODE_SIZE/build/bin:$PATH"

./gen_fm.sh -c -w "$WORKERS" -t "$TIMEOUT" \
    --llvm-project "$LLVM_PROJECT" \
    --llvm-test-suite "$LLVM_TEST_SUITE" \
    --errors-dbg "$ERRORS_DBG" \
    --lit-results "$LIT_RESULTS"

# Comparison report generation
python "$LLVM_TEST_SUITE/utils/compare.py" \
    --full --nodiff \
    -m instcount \
    -m size..text \
    -m exec_time \
    -m compile_time \
    "$LIT_RESULTS/baseline.json" \
    "$LIT_RESULTS/iroutliner.json" \
    "$LIT_RESULTS/func-merging.json" \
    "$LIT_RESULTS/daedalus.json" > comp-Os-fm-iro-daedalus.txt

printf "Comparison report generated: %s\n" "$(realpath comp-Os-fm-iro-daedalus.txt)"
