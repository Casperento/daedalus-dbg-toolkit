import re
import pandas as pd
from tabulate import tabulate

# ------------------------------------------------------------
# Schema
# ------------------------------------------------------------
COLUMNS = [
    "Program",
    "baseline (instcount)",
    "daedalus (instcount)",
    "diff (instcount)",
    "baseline (size.text)",
    "daedalus (size.text)",
    "diff (size.text)",
    "baseline (exec_time)",
    "daedalus (exec_time)",
    "diff (exec_time)",
    "baseline (compile_time)",
    "daedalus (compile_time)",
    "diff (compile_time)",
]

_GROUPS = [
    ("baseline (instcount)", "daedalus (instcount)", "diff (instcount)"),
    ("baseline (size.text)", "daedalus (size.text)", "diff (size.text)"),
    ("baseline (exec_time)", "daedalus (exec_time)", "diff (exec_time)"),
    ("baseline (compile_time)", "daedalus (compile_time)", "diff (compile_time)"),
]

# tokens: numeric (incl. 'inf') or percent (incl. 'inf%')
_TOKEN_RE = re.compile(
    r"""
    (?:
        (?P<pct>(?:inf|[-+]?(?:\d+(?:\.\d+)?|\.\d+))%)  # e.g., 12.6%, -3%, inf%
      | (?P<num>(?:inf|[-+]?(?:\d+(?:\.\d+)?|\.\d+)))   # e.g., 246, .05, -7, inf
    )
""",
    re.IGNORECASE | re.VERBOSE,
)

# Program = everything before first numeric/inf token
_PROG_SPLIT_RE = re.compile(r"^(.*?)(?=\s+(?:inf|[-+]?(?:\d+(?:\.\d+)?|\.\d+))%?\b)")


# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------
def _num_or_zero(tok: str) -> float:
    if not tok:
        return 0.0
    t = tok.strip().lower()
    if not t or t == "inf":
        return 0.0
    try:
        return float(t)
    except ValueError:
        return 0.0


def _pct_to_number_or_zero(tok: str) -> float:
    # '12.6%' -> 12.6; 'inf%'/empty -> 0.0; if '%' missing, treat as numeric percent already
    if not tok:
        return 0.0
    t = tok.strip().lower()
    if t.endswith("%"):
        body = t[:-1].strip()
        if not body or body == "inf":
            return 0.0
        try:
            return float(body)
        except ValueError:
            return 0.0
    return _num_or_zero(t)


def _split_program(line: str) -> tuple[str, str]:
    s = (line or "").rstrip()
    if not s:
        return "", ""
    m = _PROG_SPLIT_RE.search(s)
    if not m:
        return s.strip(), ""
    prog = m.group(1).strip()
    rest = s[m.end() :].strip()
    return prog, rest


# ------------------------------------------------------------
# Parser (enforces: two numbers before each %; gaps allowed)
# ------------------------------------------------------------
def parse_fixed_row(line: str) -> dict:
    """
    Row pattern:
    Program  baseline daedalus diff | baseline daedalus diff | baseline daedalus diff | baseline daedalus diff
    - Program may contain spaces (everything before first numeric/inf token)
    - Any missing/empty/inf/inf% -> 0.00
    - diff stored as percent number (e.g., 12.6)
    """
    program, rest = _split_program(line)
    toks = [m.group(0) for m in _TOKEN_RE.finditer(rest)]

    out = {"Program": program}
    ti = 0
    for base_col, daed_col, diff_col in _GROUPS:
        base = daed = diff = None

        # baseline: first non-% token
        while ti < len(toks) and base is None:
            if toks[ti].endswith("%"):
                break
            base = _num_or_zero(toks[ti])
            ti += 1

        # daedalus: next non-% token
        while ti < len(toks) and daed is None:
            if toks[ti].endswith("%"):
                break
            daed = _num_or_zero(toks[ti])
            ti += 1

        # diff: prefer %, but accept numeric percent if malformed
        if ti < len(toks):
            if toks[ti].endswith("%"):
                diff = _pct_to_number_or_zero(toks[ti])
                ti += 1
            else:
                diff = _pct_to_number_or_zero(toks[ti])
                ti += 1

        out[base_col] = 0.0 if base is None else base
        out[daed_col] = 0.0 if daed is None else daed
        out[diff_col] = 0.0 if diff is None else diff

    return out


def parse_fixed_rows(lines):
    if isinstance(lines, str):
        lines = [ln for ln in lines.splitlines() if ln.strip()]
    else:
        lines = [ln for ln in lines if ln and ln.strip()]
    return [parse_fixed_row(ln) for ln in lines]


# ------------------------------------------------------------
# Geomean (expects percent numbers; returns fraction)
# ------------------------------------------------------------
def geomean(series: pd.Series, tol: float = 1e-12) -> float:
    """
    Geometric mean of percentage changes, robust to '-100%' sentinels.
    Input: series of percent numbers (e.g., 12.6, -3.2, -100.0).
    Returns a fraction (e.g., 0.034 -> 3.4%).

    Any value <= -100% + tol is treated as invalid (factor <= 0) and excluded.
    If no valid entries remain, returns 0.0.
    """
    s = pd.to_numeric(series, errors="coerce").dropna()

    # Exclude values that would produce non-positive factors (<= -100%)
    s = s[s > (-100.0 + tol)]
    if s.empty:
        return 0.0

    factors = 1.0 + (s / 100.0)
    return factors.prod() ** (1.0 / len(factors)) - 1.0


# ------------------------------------------------------------
# IO + Orchestration (keeps explicit geomean recalculation blocks)
# ------------------------------------------------------------
def convert_to_tsv(input_file: str, output_file: str):
    with open(input_file, "r", encoding="utf-8") as f:
        raw_lines = [line.rstrip("\n") for line in f]

    skip_prefixes = (
        "Geomean",
        "Tests",
        "count",
        "mean",
        "std",
        "min",
        "25%",
        "50%",
        "75%",
        "max",
    )

    rows = []
    for line in raw_lines:
        if not line.strip():
            continue
        if not _PROG_SPLIT_RE.search(line):
            continue
        prog = _PROG_SPLIT_RE.search(line).group(1).strip()
        if prog.startswith(skip_prefixes):
            continue
        rows.append(parse_fixed_row(line))

    df = pd.DataFrame(rows, columns=COLUMNS) if rows else pd.DataFrame(columns=COLUMNS)
    df.to_csv(output_file, sep="\t", index=False)

    print(f"{df.shape[0]} rows x {df.shape[1]} columns")
    print(df.head(len(df)))

    if df.empty:
        return

    # ===== Explicit recalculation blocks (kept) =====
    total_rows = len(df)

    # --- instcount ---
    diff_instcount_col = pd.to_numeric(df["diff (instcount)"], errors="coerce").fillna(
        0.0
    )
    positive_count_instcount = (diff_instcount_col > 0).sum()
    negative_count_instcount = (diff_instcount_col < 0).sum()
    zero_count_instcount = (diff_instcount_col == 0).sum()
    positive_percent_instcount = positive_count_instcount / total_rows
    negative_percent_instcount = negative_count_instcount / total_rows
    zero_percent_instcount = zero_count_instcount / total_rows
    geomean_diff_instcount = geomean(diff_instcount_col)
    positive_geomean_instcount = geomean(diff_instcount_col[diff_instcount_col > 0])
    negative_geomean_instcount = geomean(diff_instcount_col[diff_instcount_col < 0])
    zero_geomean_instcount = geomean(diff_instcount_col[diff_instcount_col == 0])

    # --- size.text ---
    diff_sizetext_col = pd.to_numeric(df["diff (size.text)"], errors="coerce").fillna(
        0.0
    )
    positive_count_sizetext = (diff_sizetext_col > 0).sum()
    negative_count_sizetext = (diff_sizetext_col < 0).sum()
    zero_count_sizetext = (diff_sizetext_col == 0).sum()
    positive_percent_sizetext = positive_count_sizetext / total_rows
    negative_percent_sizetext = negative_count_sizetext / total_rows
    zero_percent_sizetext = zero_count_sizetext / total_rows
    geomean_diff_sizetext = geomean(diff_sizetext_col)
    positive_geomean_sizetext = geomean(diff_sizetext_col[diff_sizetext_col > 0])
    negative_geomean_sizetext = geomean(diff_sizetext_col[diff_sizetext_col < 0])
    zero_geomean_sizetext = geomean(diff_sizetext_col[diff_sizetext_col == 0])

    # --- exec_time ---
    diff_exectime_col = pd.to_numeric(df["diff (exec_time)"], errors="coerce").fillna(
        0.0
    )
    positive_count_exectime = (diff_exectime_col > 0).sum()
    negative_count_exectime = (diff_exectime_col < 0).sum()
    zero_count_exectime = (diff_exectime_col == 0).sum()
    positive_percent_exectime = positive_count_exectime / total_rows
    negative_percent_exectime = negative_count_exectime / total_rows
    zero_percent_exectime = zero_count_exectime / total_rows
    geomean_diff_exectime = geomean(diff_exectime_col)
    positive_geomean_exectime = geomean(diff_exectime_col[diff_exectime_col > 0])
    negative_geomean_exectime = geomean(diff_exectime_col[diff_exectime_col < 0])
    zero_geomean_exectime = geomean(diff_exectime_col[diff_exectime_col == 0])

    # --- compile_time ---
    diff_compiletime_col = pd.to_numeric(
        df["diff (compile_time)"], errors="coerce"
    ).fillna(0.0)
    positive_count_compiletime = (diff_compiletime_col > 0).sum()
    negative_count_compiletime = (diff_compiletime_col < 0).sum()
    zero_count_compiletime = (diff_compiletime_col == 0).sum()
    positive_percent_compiletime = positive_count_compiletime / total_rows
    negative_percent_compiletime = negative_count_compiletime / total_rows
    zero_percent_compiletime = zero_count_compiletime / total_rows
    geomean_diff_compiletime = geomean(diff_compiletime_col)
    positive_geomean_compiletime = geomean(
        diff_compiletime_col[diff_compiletime_col > 0]
    )
    negative_geomean_compiletime = geomean(
        diff_compiletime_col[diff_compiletime_col < 0]
    )
    zero_geomean_compiletime = geomean(diff_compiletime_col[diff_compiletime_col == 0])

    # ===== Summaries (tabulated) =====
    larger_df = pd.DataFrame(
        {
            "Count": [
                positive_count_instcount,
                positive_count_sizetext,
                positive_count_exectime,
                positive_count_compiletime,
            ],
            "% of total": [
                positive_percent_instcount,
                positive_percent_sizetext,
                positive_percent_exectime,
                positive_percent_compiletime,
            ],
            "Geomean": [
                positive_geomean_instcount,
                positive_geomean_sizetext,
                positive_geomean_exectime,
                positive_geomean_compiletime,
            ],
        },
        index=["Instcount", "Size.text", "Exec. Time", "Compile Time"],
    )
    smaller_df = pd.DataFrame(
        {
            "Count": [
                negative_count_instcount,
                negative_count_sizetext,
                negative_count_exectime,
                negative_count_compiletime,
            ],
            "% of total": [
                negative_percent_instcount,
                negative_percent_sizetext,
                negative_percent_exectime,
                negative_percent_compiletime,
            ],
            "Geomean": [
                negative_geomean_instcount,
                negative_geomean_sizetext,
                negative_geomean_exectime,
                negative_geomean_compiletime,
            ],
        },
        index=["Instcount", "Size.text", "Exec. Time", "Compile Time"],
    )
    unchanged_df = pd.DataFrame(
        {
            "Count": [
                zero_count_instcount,
                zero_count_sizetext,
                zero_count_exectime,
                zero_count_compiletime,
            ],
            "% of total": [
                zero_percent_instcount,
                zero_percent_sizetext,
                zero_percent_exectime,
                zero_percent_compiletime,
            ],
            "Geomean": [
                zero_geomean_instcount,
                zero_geomean_sizetext,
                zero_geomean_exectime,
                zero_geomean_compiletime,
            ],
        },
        index=["Instcount", "Size.text", "Exec. Time", "Compile Time"],
    )
    overall_df = pd.DataFrame(
        {
            "Total Programs": [total_rows, total_rows, total_rows, total_rows],
            "Geomean": [
                geomean_diff_instcount,
                geomean_diff_sizetext,
                geomean_diff_exectime,
                geomean_diff_compiletime,
            ],
        },
        index=["Instcount", "Size.text", "Exec. Time", "Compile Time"],
    )

    # format
    for dfx in (larger_df, smaller_df, unchanged_df):
        dfx["% of total"] = dfx["% of total"].apply(lambda x: f"{x*100:.2f}%")
        dfx["Geomean"] = dfx["Geomean"].apply(lambda x: f"{x*100:.2f}%")
    overall_df["Geomean"] = overall_df["Geomean"].apply(lambda x: f"{x*100:.2f}%")

    print("Programs that got increased metrics:")
    print(tabulate(larger_df, headers="keys", tablefmt="psql"))
    print("\nPrograms that got decreased metrics:")
    print(tabulate(smaller_df, headers="keys", tablefmt="psql"))
    print("\nPrograms that metrics didn't change:")
    print(tabulate(unchanged_df, headers="keys", tablefmt="psql"))
    print("\nOverall metrics:")
    print(tabulate(overall_df, headers="keys", tablefmt="psql"))


if __name__ == "__main__":
    convert_to_tsv("comparison_results.txt", "comparison_results.tsv")
