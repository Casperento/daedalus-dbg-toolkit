# Errors Debugging and Reduction Framework

This project provides a set of scripts and utilities to automate the process of building, testing, debugging, and reducing LLVM IR programs. The framework is designed to work with the Daedalus LLVM pass and the LLVM Test Suite.

## Project Structure

```
.
├── gen_baseline.sh
├── gen_daedalus.sh
├── list-errors.sh
├── reduce-programs.sh
├── errors-summary-grouped.py
├── errors_summary/
│   ├── errors_counts.csv
│   ├── errors_summary_grouped.csv
├── output/
│   ├── logs/
│   ├── sources/
│   ├── sources_comparison_failed/
```

## Scripts Overview

### 1. `gen_baseline.sh`

**Purpose**: Automates the process of generating a baseline for comparison purposes.

**Usage**:
```bash
./gen_baseline.sh [options]
```

**Options**: This script may require specific paths or configurations. Refer to the script for details.

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

### 5. `errors-summary-grouped.py`

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

---

## Output Directory Structure

- `output/logs/`: Contains logs for each test, including errors.
- `output/sources/`: Contains extracted LLVM IR files.
- `output/sources_comparison_failed/`: Contains LLVM IR files that failed comparison.

---

## Requirements

- Bash
- Python 3
- LLVM tools (`opt`, `llvm-reduce`)
- CMake and Ninja (for building the LLVM Test Suite)

---

## License

This project is licensed under the MIT License.
