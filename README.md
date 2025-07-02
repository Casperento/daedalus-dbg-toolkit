# Daedalus Debugging Toolkit

This repository offers a collection of scripts and tools to streamline building, testing, debugging, and minimizing LLVM IR programs. It is tailored for use with the Daedalus LLVM pass and integrates with the LLVM Test Suite.

## Project Structure

```
.
├── gen_baseline.sh
├── gen_daedalus.sh
├── list-errors.sh
├── reduce-programs.sh
├── extract-func.sh
├── expand-logs.sh
├── ll2dot.sh
├── print-dots.sh
├── print-hardware-info.sh
├── print-repo-info.sh
├── txt2filecheckpattern.sh
├── errors-summary-grouped.py
├── analyze_comparison_results.py
├── analyze-experiment.py
├── cost-model-experiment.py
├── errors_summary/
│   ├── errors_counts.csv
│   ├── errors_summary_grouped.csv
├── output/
│   ├── bc_logs/ # Contains logs for each .bc file run by LIT.
│   ├── script_logs/ # Contains `list-errors.sh` logs.
│   ├── sources/ # Contains extracted LLVM IR files.
│   ├── sources_comparison_failed/ # Contains LLVM IR files that failed comparison.
```

---

## Requirements

- Bash
- Python 3
- LLVM tools (`opt`, `llvm-reduce`, `llvm-extract`)
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

### 1. `gen_baseline.sh`

**Purpose**: Automates the process of generating a baseline for comparison purposes.

**Usage**:
```bash
./gen_baseline.sh [options]
```

**Options**:
- `-h, --help`               Show help message and exit
- `-c, --clean`              Clean build directory before building
- `-w, --workers <n>`        Number of parallel workers (default: 10)
- `-t, --timeout <n>`        Timeout to set for LIT (default: 120)
- `--llvm-test-suite <path>` Path to LLVM test suite (default: $HOME/src/github/llvm-test-suite)
- `--lit-results <path>`     Directory for LIT results JSON (default: $HOME/lit-results)

---

### 2. `gen_daedalus.sh`

**Purpose**: Automates the process of cleaning, updating, building, and testing the Daedalus LLVM pass alongside the LLVM Test Suite. It also runs LIT tests and processes errors.

**Usage**:
```bash
./gen_daedalus.sh [options]
```

**Options**:
- `--clean`: Cleans build directories before building.
- `--upgrade`: Updates the Daedalus repository to the latest commits.
- `--branch <name>`: Specifies the branch to use for Daedalus (default: `main`).
- `--workers <n>`: Sets the number of parallel workers (default: `10`).
- `--llvm-project <path>`: Path to the LLVM project.
- `--llvm-test-suite <path>`: Path to the LLVM Test Suite.
- `--daedalus <path>`: Path to the Daedalus project.
- `--errors-dbg <path>`: Directory for LIT log output.
- `--lit-results <path>`: Directory for LIT results JSON.

**Example**:
```bash
./gen_daedalus.sh --clean --workers 16 --llvm-project=/path/to/llvm-project --llvm-test-suite=/path/to/llvm-test-suite
```

---

### 3. `list-errors.sh`

**Purpose**: Processes LIT test outputs and comparison results to extract failing tests, generate LLVM IR sources, and collate error logs for analysis.

**Usage**:
```bash
./list-errors.sh [options]
```

**Options**:
- `--build-dir <path>`: Path to the LLVM Test Suite build folder (required).
- `--plugin-dir <path>`: Path to the folder containing `libdaedalus.so` (required).
- `--results-dir <path>`: Path to the LIT results folder with JSON files (required).
- `--output-dir <path>`: Path to the output base directory (default: `output`).

**Example**:
```bash
./list-errors.sh --build-dir=/path/to/build --plugin-dir=/path/to/libdaedalus --results-dir=/path/to/lit-results --output-dir=/path/to/output
```

---

### 4. `reduce-programs.sh`

**Purpose**: Reduces faulty LLVM IR programs to minimal reproducing cases for debugging.

**Usage**:
```bash
./reduce-programs.sh <sources_folder>
```

**Arguments**:
- `<sources_folder>`: Path to the folder containing `.ll` files to be reduced.

**Example**:
```bash
./reduce-programs.sh output/sources
```

---

### 5. `extract-func.sh`

**Purpose**: Extracts a single function from an LLVM IR (`.ll`) file using `llvm-extract`.

**Usage**:
```bash
./extract-func.sh <llvm-ir-file> <function-name>
```

**Arguments**:
- `<llvm-ir-file>`: Path to the LLVM IR file (`.ll`) from which to extract the function.
- `<function-name>`: Name of the function to extract (without the `@` prefix).

**Example**:
```bash
./extract-func.sh output/sources/foo.ll main
```

**Output**:
- A new `.ll` file containing only the extracted function, named `<llvm-ir-file>.<function-name>.ll` (e.g., `foo.main.ll`).

---

### 6. `expand-logs.sh`

**Purpose**: Expands or processes log files, supporting both single file and directory modes. Can also clean up generated files.

**Usage**:
```bash
./expand-logs.sh [-f <file.ll>] [-c|--clean]
```

**Options**:
- `-f <file.ll>`: Process a single `.ll` file.
- `-c`, `--clean`: Clean up generated files.

---

### 7. `ll2dot.sh`

**Purpose**: Converts `.ll` files to `.dot` files and then to PDF for visualizing control flow graphs of LLVM IR files.

**Usage**:
```bash
./ll2dot.sh [directory]
```

**Arguments**:
- `[directory]`: Directory containing `.ll` files (default: current directory).

---

### 8. `print-dots.sh`

**Purpose**: Automates the generation of `.dot` files from one or more LLVM IR (`.ll`) files, organizing outputs and logging the process. It wraps and extends `ll2dot.sh` for batch processing and flexible output management.

**Usage**:
```bash
./print-dots.sh [-o output_dir] [-l log_file] file1.ll [file2.ll ...]
```

**Options**:
- `-o output_dir`   Output base directory (default: `output`)
- `-l log_file`     Log file to append output (default: `/dev/null`)
- `file1.ll ...`    One or more `.ll` files to process

**Behavior**:
- For each `.ll` file, creates a subdirectory under `<output_dir>/dots/<basename>`
- Copies the `.ll` file to that directory
- Invokes `ll2dot.sh` on the directory to generate `.dot` (and possibly PDF) files
- Logs actions to the specified log file

**Example**:
```bash
./print-dots.sh -o output -l print-dots.log output/sources/foo.ll output/sources/bar.ll
```

**Notes**:
- Requires `ll2dot.sh` in the same directory.
- Prints usage and exits if no input files are provided.

---

### 9. `print-hardware-info.sh`

**Purpose**: Prints a summary of the system's hardware information, including CPU, memory, GPU, and disk details. Useful for quickly gathering environment details for debugging or reporting.

**Usage**:
```bash
./print-hardware-info.sh
```

**Output**:
- Hostname
- CPU model, sockets, threads, cores, and total CPUs (via `lscpu`)
- Total and available memory (via `free -h`)
- GPU/graphics card information (via `lspci`)
- Disk usage for root filesystem (via `df -h /`)

**Notes**:
- If a command is not available, the script will print a warning for that section.

---

### 10. `print-repo-info.sh`

**Purpose**: Prints basic information about a Git repository, including the current branch and latest commit hash. Useful for documenting the state of a codebase during experiments or debugging.

**Usage**:
```bash
./print-repo-info.sh <path-to-git-repo>
```

**Arguments**:
- `<path-to-git-repo>`: Path to the root directory of the Git repository.

**Output**:
- Repository path
- Current branch name
- Latest commit hash

**Notes**:
- Prints an error and exits if the path is not a Git repository or is missing.

---

### 11. `txt2filecheckpattern.sh`

**Purpose**: Converts a text file to a file-check pattern, with argument parsing and help options.

**Usage**:
```bash
./txt2filecheckpattern.sh -f <inputfile>
```

**Options**:
- `-f, --file <inputfile>`: Input file to process.
- `-h, --help`: Show help message.

---

### 12. `errors-summary-grouped.py`

**Purpose**: Analyzes error logs and generates grouped summaries and counts of errors.

**Usage**:
```bash
python3 errors-summary-grouped.py <errors_file>
```

**Arguments**:
- `<errors_file>`: Path to the error logs file (e.g., `output/logs/errors.txt`).

**Example**:
```bash
python3 errors-summary-grouped.py output/logs/errors.txt
```

**Output**:
- `errors_summary/errors_summary_grouped.csv`: Grouped summary of errors.
- `errors_summary/errors_counts.csv`: Count of files affected by each error.

---

### 13. `analyze_comparison_results.py`

**Purpose**: Analyzes TSV comparison results, computes statistics and summaries for program differences.

**Usage**:
```bash
python3 analyze_comparison_results.py <comparison_results.tsv>
```

**Arguments**:
- `<comparison_results.tsv>`: Path to the TSV file with comparison results.

**Output**:
- Summary statistics and categorized program changes.

---

### 14. `analyze-experiment.py`

**Purpose**: Parses one or more dbg-toolkit experiment report files, extracting summary statistics, file paths, runtime, and ASCII-art tables into structured data. When given multiple files, it can compare runs and identify which log has the greatest Instcount geomean among "got smaller" metrics.

**Usage**:
```bash
python3 analyze-experiment.py <report_file> [-o output.json]
```

**Arguments**:
- `<report_file>`: Path to a dbg-toolkit report file (log file from experiment runs).
- `-o, --output <output.json>`: (Optional) Write parsed results to a JSON file.

**Output**:
- Prints parsed summary and table data for each run.
- Identifies runs with greatest reduction/growth in Instcount and Size.text metrics.
- Optionally writes all parsed data to a JSON file.

---

### 15. `cost-model-experiment.py`

**Purpose**: Automates running the Daedalus LLVM pass (`gen_daedalus.sh`) over a grid of slice parameters, logging results, and analyzing them with `analyze-experiment.py`.

**Usage**:
```bash
python3 cost-model-experiment.py [--log-file <log>] [--params N ...] [--sizes N ...] [--users N ...]
```

**Options**:
- `--log-file, -l <log>`: File to append stdout/stderr to (default: `transform.log`).
- `--params N ...`: Values for `-max-slice-params` (default: 5).
- `--sizes N ...`: Values for `-max-slice-size` (default: 40).
- `--users N ...`: Values for `-max-slice-users` (default: 100).

**Behavior**:
- Runs `gen_daedalus.sh` for each combination of parameters, logs output, and prints a header for each run.
- After all runs, analyzes the log file with `analyze-experiment.py` and prints the summary.

---

## Workflow

1. **Generate Baseline**:
   Use `gen_baseline.sh` to create a baseline for comparison.

2. **Build and Test**:
   Use `gen_daedalus.sh` to build the LLVM Test Suite with the Daedalus plugin and run LIT tests.

3. **Extract Errors**:
   Use `list-errors.sh` to process the LIT results, extract failing tests, and generate LLVM IR sources.

4. **Analyze Errors**:
   Use `errors-summary-grouped.py` to analyze the error logs and generate summaries.

5. **Reduce Programs**:
   Use `reduce-programs.sh` to minimize faulty LLVM IR programs for debugging.

6. **Extract Functions**:
   Use `extract-func.sh` to extract a single function from an LLVM IR file for focused debugging or analysis.

7. **Expand Logs**:
   Use `expand-logs.sh` to process or clean up log files.

8. **Visualize IR**:
   Use `ll2dot.sh` to generate control flow graph PDFs from `.ll` files.

9. **Convert to FileCheck Pattern**:
   Use `txt2filecheckpattern.sh` to generate file-check patterns from text files.

10. **Analyze Comparison Results**:
   Use the provided Python scripts to analyze and summarize comparison metrics.

---


