#!/usr/bin/env python3
"""
Script to parse one or more dbg-toolkit report files.
- Extracts summary counts, file paths, and runtime.
- Parses ASCII-art tables into structured data.
- When given multiple files, identifies which log has the greatest Instcount geomean among "got smaller" metrics.
"""
import re
import argparse
import json
import sys


def parse_table(lines):
    """
    Parse an ASCII-art table block into a list of dicts.
    """
    header = None
    rows = []
    for line in lines:
        text = line.rstrip("\n")
        # Identify header or data rows
        if text.startswith("|") and not set(text.strip()) <= set("+-| "):
            parts = [cell.strip() for cell in text.strip().strip("|").split("|")]
            if header is None:
                header = parts
            else:
                rows.append(dict(zip(header, parts)))
    return rows


def parse_report(filepath):
    """
    Parse a single report into a dict.
    """
    data = {}
    with open(filepath, "r") as f:
        lines = f.readlines()

    i = 0
    while i < len(lines):
        line = lines[i].rstrip()
        if line.startswith("Processed:"):
            data["processed"] = int(line.split(":", 1)[1].strip())
        elif line.startswith("Build failures"):
            data["build_failures"] = int(line.split(":", 1)[1].strip())
        elif line.startswith("Comparison failures"):
            data["comparison_failures"] = int(line.split(":", 1)[1].strip())
        elif line.startswith("--> Summary written to:"):
            data["summary_path"] = line.split(":", 1)[1].strip()
        elif line.startswith("--> Error counts written to:"):
            data["error_counts_path"] = line.split(":", 1)[1].strip()
        elif line.startswith("--> Total files with at least one error"):
            m = re.search(r":\s*(\d+)", line)
            data["total_files_with_errors"] = int(m.group(1)) if m else None
        elif line.startswith("Programs that got larger:"):
            block = []
            i += 1
            while i < len(lines) and lines[i].strip():
                block.append(lines[i])
                i += 1
            data["larger"] = parse_table(block)
            continue
        elif line.startswith("Programs that got smaller:"):
            block = []
            i += 1
            while i < len(lines) and lines[i].strip():
                block.append(lines[i])
                i += 1
            data["smaller"] = parse_table(block)
            continue
        elif line.startswith("Programs that didn't change:"):
            block = []
            i += 1
            while i < len(lines) and lines[i].strip():
                block.append(lines[i])
                i += 1
            data["unchanged"] = parse_table(block)
            continue
        elif line.startswith("Overall metrics:"):
            block = []
            i += 1
            while i < len(lines) and lines[i].strip():
                block.append(lines[i])
                i += 1
            data["overall"] = parse_table(block)
            continue
        elif line.startswith("--> Comparison analysis written to:"):
            data["comparison_analysis_path"] = line.split(":", 1)[1].strip()
        elif line.startswith("Total script runtime:"):
            m = re.search(r"(\d+)\s*seconds", line)
            data["runtime_seconds"] = int(m.group(1)) if m else None
        i += 1

    return data


def parse_all_reports(filepath):
    """
    Parse a file with multiple experiment runs, associating each 'smaller' and 'larger' table with the next run header.
    """
    with open(filepath, "r") as f:
        lines = f.readlines()
    runs = []
    i = 0
    while i < len(lines):
        line = lines[i].rstrip()
        if line.startswith("Programs that got smaller:") or line.startswith("Programs that got larger:"):
            tbl_type = "smaller" if "smaller" in line else "larger"
            tbl = []
            i += 1
            while i < len(lines) and lines[i].strip():
                tbl.append(lines[i])
                i += 1
            # Look ahead for the next run header
            header = None
            lookahead = i
            while lookahead < len(lines):
                if lines[lookahead].startswith("## Run: "):
                    header = lines[lookahead].strip()
                    break
                lookahead += 1
            # If this header already exists in runs, update it, else create new
            found = False
            for run in runs:
                if run["header"] == header:
                    run[tbl_type] = parse_table(tbl)
                    found = True
                    break
            if not found:
                run = {"header": header, tbl_type: parse_table(tbl)}
                runs.append(run)
        else:
            i += 1
    return runs


def extract_inst_geomean_smaller(parsed):
    """
    From a parsed report, return the Instcount geomean as a float (percent) if present.
    """
    for row in parsed.get("smaller", []):
        key = next(iter(row.values()))  # first column value
        if key.lower() == "instcount":
            val = row.get("Geomean", "").strip().rstrip("%")
            try:
                return float(val)
            except ValueError:
                return None
    return None


def extract_inst_geomean_smaller_from_runs(runs):
    """
    From a list of run dicts, yield (header, geomean) for each run with Instcount geomean.
    """
    for run in runs:
        for row in run.get("smaller", []):
            key = next(iter(row.values()))
            if key.lower() == "instcount":
                val = row.get("Geomean", "").strip().rstrip("%")
                try:
                    yield (run["header"], float(val))
                except ValueError:
                    continue


def extract_metric_geomeans(runs, metric, progtype):
    """
    From a list of run dicts, yield (header, geomean) for each run with the given metric in the given progtype table.
    progtype: 'smaller' or 'larger'
    metric: 'Instcount' or 'Size.text'
    """
    for run in runs:
        for row in run.get(progtype, []):
            key = next(iter(row.values()))
            if key.lower() == metric.lower():
                val = row.get("Geomean", "").strip().rstrip("%")
                try:
                    yield (run["header"], float(val))
                except ValueError:
                    continue


def main():
    parser = argparse.ArgumentParser(description="Parse dbg-toolkit report files")
    parser.add_argument("input_files", nargs="+", help="One or more report files")
    parser.add_argument("-o", "--output", help="Optional: output JSON file")
    args = parser.parse_args()

    runs = parse_all_reports(args.input_files[0])

    # Print all runs content pretty
    # Write all parsed runs to a JSON file named after the input file
    input_base = args.input_files[0].rsplit(".", 1)[0]
    json_filename = f"{input_base}.json"
    with open(json_filename, "w") as jf:
        json.dump(runs, jf, indent=2)
    print(f"\nAll parsed runs written to {json_filename}")

    for metric in ("Instcount", "Size.text"):
        # Greatest reduction from smaller
        geomeans_smaller = list(extract_metric_geomeans(runs, metric, "smaller"))
        if geomeans_smaller:
            best = min(geomeans_smaller, key=lambda x: x[1])
            print(f"Greatest reduction for {metric} (programs that got smaller):")
            print(f"  {best[0]} => {best[1]}%")
        else:
            print(f"No {metric} geomean found in any 'smaller' run.")
        # Largest growth from larger
        geomeans_larger = list(extract_metric_geomeans(runs, metric, "larger"))
        if geomeans_larger:
            worst = max(geomeans_larger, key=lambda x: x[1])
            print(f"Largest growth for {metric} (programs that got larger):")
            print(f"  {worst[0]} => {worst[1]}%")
        else:
            print(f"No {metric} geomean found in any 'larger' run.")
    # Optionally output all parsed runs
    if args.output:
        with open(args.output, "w") as out:
            json.dump(runs, out, indent=2)


if __name__ == "__main__":
    main()
