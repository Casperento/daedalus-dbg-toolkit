import re
import csv
import argparse
from collections import defaultdict
import os


def parse_errors(file_path):
    # 1) Define your patterns (all as compiled regexes)
    raw_patterns = [
        r"llvm::ProgramSlice::populateBBsWithInsts\(llvm::Function\*\)",
        r"get_data_dependences_for",
        r"appendBlockGatesToPhiParent",
        r"removeInstructions",
        r"Instruction does not dominate all uses!",
        r"PHINode should have one entry for each predecessor of its parent basic block!",
        r"PHI node has multiple entries for the same basic block with different incoming values!",
        r"Entry block to function must not have predecessors!",
        r"Basic Block in function '(.+)' does not have terminator!",
        r"Only PHI nodes may reference their own value!",
        r"Assertion\s`(.+)\sfailed\.",
        r"Referring to an argument in another function!",
        r"Referring to a basic block in another function!"
    ]
    patterns = [re.compile(p) for p in raw_patterns]

    # 2) File‐path regex to pick up the current .log file name
    file_re = re.compile(r"^/.*?/(.*?\.log)")

    # Maps filename -> set of matched error‐strings
    file_errors = defaultdict(set)
    current_file = None

    # Read through the log lines
    with open(file_path, "r") as f:
        for line in f:
            m = file_re.match(line)
            if m:
                current_file = m.group(1)
            if current_file:
                for pat in patterns:
                    mo = pat.search(line)
                    if mo:
                        # use the exact text matched as the "error type"
                        file_errors[current_file].add(mo.group(0))

    # 3) Compute how many files each error shows up in
    error_file_counts = defaultdict(int)
    for errors in file_errors.values():
        for err in errors:
            error_file_counts[err] += 1

    total_files = len(file_errors)

    output_folder = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "errors_summary"
    )
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    # 4) Write per-file summary (plus total at the end)
    summary_csv = os.path.join(output_folder, "errors_summary_grouped.csv")
    with open(summary_csv, "w", newline="") as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(["file", "errors"])
        for fname, errs in sorted(file_errors.items()):
            writer.writerow([fname, "; ".join(sorted(errs))])
        # blank row to separate, then total
        writer.writerow([])
        writer.writerow(["Total files with errors", total_files])

    # 5) Write per-error counts
    counts_csv = os.path.join(output_folder, "errors_counts.csv")
    with open(counts_csv, "w", newline="") as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(["error", "file_count"])
        for err, cnt in sorted(
            error_file_counts.items(), key=lambda x: x[1], reverse=True
        ):
            writer.writerow([err, cnt])

    print(f"--> Summary written to: {summary_csv}")
    print(f"--> Error counts written to: {counts_csv}")
    print(f"--> Total files with at least one error: {total_files}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Parse error logs, summarize per-file errors, count files per error, and tally total files."
    )
    parser.add_argument("filepath", help="Path to the errors.txt (or .log) file")
    args = parser.parse_args()
    parse_errors(args.filepath)
