# Activate python venv

source venv/bin/activate

# Os baseline setup and running
./gen_baseline.sh -c

# Daedalus setup and running
./gen_daedalus.sh -c --max-slice-params 1 --max-slice-size 20 --max-slice-users 10

# IROutliner setup and running

./gen_iro.sh -c

# func-merging setup and running
export PATH="$HOME/src/github/code-size/build/bin:$PATH"

./gen_fm.sh -c

# Comparison report generation
cd ~/lit-results || exit
python ~/src/github/llvm-test-suite/utils/compare.py \
    --full --nodiff \
    -m instcount \
    -m size..text \
    -m exec_time \
    -m compile_time \
    baseline.json iroutliner.json func-merging.json daedalus.json > comp-Os-fm-iro-daedalus.txt
