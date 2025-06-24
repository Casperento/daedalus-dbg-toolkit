#!/usr/bin/env python3
import argparse
import subprocess
from pathlib import Path


def parse_args():
    p = argparse.ArgumentParser(
        description="Run LLVM opt with daedalus pass over a grid of slice parameters."
    )
    p.add_argument(
        "--log-file",
        "-l",
        default="transform.log",
        help="File to append stdout/stderr to",
    )
    p.add_argument(
        "--params",
        nargs="+",
        type=int,
        default=[5],
        help="Values for -max-slice-params",
    )
    p.add_argument(
        "--sizes", nargs="+", type=int, default=[40], help="Values for -max-slice-size"
    )
    p.add_argument(
        "--users",
        nargs="+",
        type=int,
        default=[100],
        help="Values for -max-slice-users",
    )
    return p.parse_args()


def main():
    args = parse_args()

    log = args.log_file

    # remove old log file if it exists
    if Path(log).exists():
        Path(log).unlink()

    # ensure log directory exists
    Path(log).parent.mkdir(parents=True, exist_ok=True)

    for mp in args.params:
        for ms in args.sizes:
            for mu in args.users:
                cmd = [
                    "bash",
                    "gen_daedalus.sh",
                    "-c",
                    "-b", "bugfixes",
                    "--max-slice-params", str(mp),
                    "--max-slice-size", str(ms),
                    "--max-slice-users", str(mu),
                ]

                header = f"\n\n## Run: params={mp}, size={ms}, users={mu}\n"
                with open(log, "a") as lf:
                    lf.write(header)
                    print(header)
                    # run and append both stdout and stderr
                    process = subprocess.run(cmd, stdout=lf, stderr=lf)
                    if process.returncode != 0:
                        print(f"[!] opt failed for params={mp},size={ms},users={mu}")

    print("All runs complete. See", log)

    # Analyze the log file with analyze-experiment.py
    print("\nAnalyzing log file with analyze-experiment.py...")
    result = subprocess.run([
        "python3", "analyze-experiment.py", log
    ], capture_output=True, text=True)
    print(result.stdout)
    if result.returncode != 0:
        print("[!] analyze-experiment.py failed:")
        print(result.stderr)


if __name__ == "__main__":
    main()
