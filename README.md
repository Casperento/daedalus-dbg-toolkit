# Daedalus Debugging Toolkit

The Daedalus Debugging Toolkit is a comprehensive suite of Bash and Python scripts designed to automate and streamline the workflow for building, testing, debugging, analyzing, and minimizing LLVM IR programs. It is specifically tailored for use with the Daedalus LLVM pass and integrates seamlessly with the LLVM Test Suite, supporting advanced program slicing, error analysis, and experiment automation.

Key features include:
- Automated building and testing of the LLVM Test Suite with and without the Daedalus pass, including baseline and experimental runs.
- Extraction and reduction of faulty LLVM IR programs to minimal reproducing cases for efficient debugging.
- Batch extraction of functions and automated processing of error logs to generate detailed summaries and statistics.
- Visualization tools for generating control flow graphs (CFGs) from LLVM IR files, including .dot and PDF outputs.
- Scripts for hardware and repository introspection, as well as utilities for converting logs and text files into formats suitable for regression testing (e.g., FileCheck patterns).
- Experiment automation for running the Daedalus pass over a grid of slicing parameters, with integrated result analysis and reporting.

The toolkit is intended for compiler researchers, LLVM pass developers, and anyone working with large-scale program analysis or transformation pipelines. It provides a reproducible, scriptable environment for regression testing, debugging, and performance analysis of program slicing and transformation passes in LLVM.

## Workflow Example

Below is a typical workflow leveraging the scripts in this repository to analyze, debug, and minimize issues found in LLVM IR programs using the Daedalus pass:

1. **Generate a Baseline**
   ```bash
   ./gen_baseline.sh --clean --workers 16
   ```
   This builds and tests the LLVM Test Suite without the Daedalus pass, producing a baseline for later comparison.

2. **Build and Test with Daedalus**
   ```bash
   ./gen_daedalus.sh --clean --workers 16 --branch main --upgrade
   ```
   This builds the Daedalus pass, integrates it with the LLVM Test Suite, and runs the tests.

3. **Extract Specific Functions**
   ```bash
   ./extract-faulty-functions.sh
   ```
   This extracts functions from faulty IR files for focused analysis.

4. **Print Control Flow Graphs**
   ```bash
   ./print-dots.sh output/sources/*.*.ll
   ```
   This generates PDF files for visualizing the control flow graphs of the IR files.

This workflow can be adapted and extended depending on your debugging, analysis, or research needs. See the script descriptions above for more details and options.

## Project Structure

```
.
├── gen_baseline.sh                # Generate baseline.json for llvm-test-suite
├── gen_daedalus.sh                # Build/test Daedalus LLVM pass and test suite
├── list-errors.sh                 # Extract failing tests, IR sources, error logs
├── extract-func.sh                # Extract a function from an LLVM IR file
├── extract-faulty-functions.sh    # Extract all faulty functions listed in script_logs
├── expand-logs.sh                 # Expand/process log files, clean up generated files
├── ll2dot.sh                      # Convert .ll files to .dot/.pdf for CFG visualization
├── print-dots.sh                  # Batch .dot/.pdf generation from .ll files
├── print-hardware-info.sh         # Print system hardware info
├── print-repo-info.sh             # Print git repo info (branch, commit)
├── txt2filecheckpattern.sh        # Convert text file to FileCheck pattern
├── errors-summary-grouped.py      # Summarize and group error logs
├── analyze_comparison_results.py  # Analyze TSV comparison results
├── analyze-experiment.py          # Parse/compare experiment report files
├── cost-model-experiment.py       # Run Daedalus pass over grid of slice params
├── errors_summary/
│   ├── errors_counts.csv
│   ├── errors_summary_grouped.csv
├── output/
│   ├── bc_logs/                   # Logs for each .bc file run by LIT
│   ├── script_logs/               # `list-errors.sh` logs
│   ├── sources/                   # Extracted LLVM IR files
│   ├── sources_comparison_failed/ # LLVM IR files that failed comparison
```

---

## Requirements

- Bash
- Python 3
- LLVM tools (`opt`, `llvm-extract`)
- CMake and Ninja (for building the LLVM Test Suite)

### Installing Required Packages

To configure a Python virtual environment and install the required packages (`pandas`, `scipy`, `psutil`), follow these steps:

1. **Create a Virtual Environment**:
   ```bash
   python3 -m venv venv
   ```

2. **Activate the Virtual Environment**:
   - On Linux/macOS:
     ```bash
     source venv/bin/activate
     ```
   - On Windows:
     ```bash
     venv\Scripts\activate
     ```

3. **Upgrade `pip`**:
   ```bash
   pip install --upgrade pip
   ```

4. **Install Required Packages**:
   ```bash
   pip install -r requirements.txt
   ```

5. **Verify Installation**:
   ```bash
   pip list
   ```

   Ensure `pandas`, `scipy`, `psutil` and `tabulate` are listed.

6. **Deactivate the Virtual Environment** (when done):
   ```bash
   deactivate
   ```

---

## Scripts Overview

### `gen_baseline.sh`

   - **Purpose**: Automates the process of generating a baseline for comparison purposes.
   - **Usage**:
   ```bash
   ./gen_baseline.sh [options]
   ```
   - **Options**:
      - `-h, --help`               Show help message and exit
      - `-c, --clean`              Clean build directory before building
      - `-w, --workers <n>`        Number of parallel workers (default: 10)
      - `-t, --timeout <n>`        Timeout to set for LIT (default: 120)
      - `--llvm-test-suite <path>` Path to LLVM test suite (default: $HOME/src/github/llvm-test-suite)
      - `--lit-results <path>`     Directory for LIT results JSON (default: $HOME/lit-results)

### `gen_daedalus.sh`
   - *Purpose*: Automates cleaning, updating, building, and testing the Daedalus LLVM pass alongside the LLVM Test Suite.
   - *Usage*:
     ```bash
     ./gen_daedalus.sh [options]
     ```
   - *Options*:
      - `-h, --help`               Show help message and exit
      - `-c, --clean`              Clean build directories before building
      - `-u, --upgrade`            Fetch and pull latest Daedalus commits
      - `-b, --branch <name>`      Checkout this Daedalus branch (default: main)
      - `-w, --workers <n>`        Number of parallel workers (default: 10)
      - `-t, --timeout <n>`        Timeout to set for LIT (default: 120)
      - `--llvm-project <path>`    Path to LLVM project (default: $HOME/src/github/llvm-project)
      - `--llvm-test-suite <path>` Path to LLVM test suite (default: $HOME/src/github/llvm-test-suite)
      - `--daedalus <path>`        Path to Daedalus project (default: $HOME/src/github/Daedalus)
      - `--errors-dbg <path>`      Directory for LIT log output (default: script dir)
      - `--lit-results <path>`     Directory for LIT results JSON (default: $HOME/lit-results)
      - `--max-slice-params <n>`   Set -max-slice-params for Daedalus pass (default: 5)
      - `--max-slice-size <n>`     Set -max-slice-size for Daedalus pass (default: 40)
      - `--max-slice-users <n>`    Set -max-slice-users for Daedalus pass (default: 100)

### `list-errors.sh`
   - *Purpose*: Processes LIT test outputs and comparison results to extract failing tests, generate LLVM IR sources, and collate error logs for analysis.
   - *Usage*:
     ```bash
     ./list-errors.sh [options]
     ```
   - *Options*:
      - `-h, --help`                Show help message and exit
      - `--build-dir <path>`        LLVM Test Suite build folder (required)
      - `--plugin-dir <path>`       Folder containing libdaedalus.so (required)
      - `--results-dir <path>`      LIT results folder with JSON files (required)
      - `--output-dir <path>`       Output base directory (default: output)
      - `--print-dots`              Print dots after processing (default: no)
      - `--clear`                   Clear output directories before processing (default: no)
      - `--full-logs`               Print full debug logs when calling opt (default: no)

### `extract-func.sh`
   - *Purpose*: Extracts a single function from an LLVM IR (.ll) file using llvm-extract.
   - *Usage*:
     ```bash
     ./extract-func.sh <llvm-ir-file> <function-name>
     ```

### `extract-faulty-functions.sh`
   - *Purpose*: Reads file paths from output/script_logs/faulty_functions.txt and calls extract-func.sh for each entry.
   - *Usage*:
     ```bash
     ./extract-faulty-functions.sh
     ```
   - *No CLI options* (uses the file as input).

### `expand-logs.sh`
   - *Purpose*: Expands or processes log files, supporting both single file and directory modes. Can also clean up generated files.
   - *Usage*:
     ```bash
     ./expand-logs.sh [-f <file.ll>] [-c|--clean]
     ```
   - *Options*:
      - `-f <file.ll>`: Process a single .ll file.
      - `-c`, `--clean`: Clean up generated files.

### `ll2dot.sh`
   - *Purpose*: Converts .ll files to .dot files and then to PDF for visualizing control flow graphs of LLVM IR files.
   - *Usage*:
     ```bash
     ./ll2dot.sh [directory]
     ```

### `print-dots.sh`
   - *Purpose*: Automates the generation of .dot files from one or more LLVM IR (.ll) files, organizing outputs and logging the process.
   - *Usage*:
     ```bash
     ./print-dots.sh [-o output_dir] [-l log_file] file1.ll [file2.ll ...]
     ```
   - *Options*:
      - `-o output_dir`   Output base directory (default: output)
      - `-l log_file`     Log file to append output (default: /dev/null)
      - `file1.ll ...`    One or more .ll files to process

### `print-hardware-info.sh`
   - *Purpose*: Prints a summary of the system's hardware information, including CPU, memory, GPU, and disk details.
   - *Usage*:
     ```bash
     ./print-hardware-info.sh
     ```
   - *No CLI options*.

### `print-repo-info.sh`
   - *Purpose*: Prints basic information about a Git repository, including the current branch and latest commit hash.
   - *Usage*:
     ```bash
     ./print-repo-info.sh <path-to-git-repo>
     ```

### `txt2filecheckpattern.sh`
   - *Purpose*: Converts a text file to a file-check pattern, with argument parsing and help options.
   - *Usage*:
     ```bash
     ./txt2filecheckpattern.sh -f <inputfile>
     ```
   - *Options*:
      - `-f, --file <inputfile>`: Input file to process.
      - `-h, --help`: Show help message.

### Python Scripts

### `errors-summary-grouped.py`
   - *Purpose*: Parses error logs, summarizes per-file errors, counts files per error, and tallies total files.
   - *Usage*:
     ```bash
     python3 errors-summary-grouped.py <errors_file>
     ```

### `analyze_comparison_results.py`
   - *Purpose*: Analyzes TSV comparison results, computes statistics and summaries for program differences.
   - *Usage*:
     ```bash
     python3 analyze_comparison_results.py <comparison_results.tsv>
     ```

### `analyze-experiment.py`
   - *Purpose*: Parses one or more dbg-toolkit experiment report files, extracting summary statistics, file paths, runtime, and ASCII-art tables into structured data.
   - *Usage*:
     ```bash
     python3 analyze-experiment.py <report_file> [-o output.json]
     ```

### `cost-model-experiment.py`
   - *Purpose*: Automates running the Daedalus LLVM pass (gen_daedalus.sh) over a grid of slice parameters, logging results, and analyzing them with analyze-experiment.py.
   - *Usage*:
     ```bash
     python3 cost-model-experiment.py [--log-file <log>] [--params N ...] [--sizes N ...] [--users N ...]
     ```
   - *Options*:
      - `--log-file, -l <log>`: File to append stdout/stderr to (default: transform.log)
      - `--params N ...`: Values for -max-slice-params (default: 5)
      - `--sizes N ...`: Values for -max-slice-size (default: 40)
      - `--users N ...`: Values for -max-slice-users (default: 100)
