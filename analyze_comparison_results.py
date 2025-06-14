import re
import pandas as pd
from tabulate import tabulate


def geomean(series):
    return (series / 100 + 1).prod() ** (1 / len(series)) - 1


def convert_to_tsv(input_file, output_file):
    with open(input_file, "r", encoding="utf-8") as f:
        lines = [line.rstrip() for line in f if line.strip()]

    # Prepare output
    with open(output_file, "w", encoding="utf-8") as out:
        for line in lines:
            if not line.strip():
                continue
            match = re.match(r"^(.*?)(\s+\d.*)$", line)
            if match:
                program = match.group(1).strip()
                rest = re.sub(r"\s{1,}", "\t", match.group(2).strip())
                if rest.count("\t") < 5:
                    continue
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
                if program.startswith(skip_prefixes):
                    continue
                out.write(f"{program}\t{rest}\n")

    # Read the TSV file into a DataFrame
    df = pd.read_csv(output_file, sep="\t", header=None)
    df.columns = [
        "Program",
        "baseline (instcount)",
        "daedalus (instcount)",
        "diff (instcount)",
        "baseline (size.text)",
        "daedalus (size.text)",
        "diff (size.text)",
    ]

    # Convert "diff (instcount)" from percentage string to float
    df["diff (instcount)"] = df["diff (instcount)"].str.rstrip("%").astype(float)
    df["diff (size.text)"] = df["diff (size.text)"].str.rstrip("%").astype(float)

    # Totals
    total_rows = len(df)

    # Calculate counts and percentages for instcount
    diff_instcount_col = df["diff (instcount)"]
    positive_count_instcount = (diff_instcount_col > 0).sum()
    negative_count_instcount = (diff_instcount_col < 0).sum()
    zero_count_instcount = (diff_instcount_col == 0).sum()
    total_rows = len(df)
    positive_percent_instcount = positive_count_instcount / total_rows
    negative_percent_instcount = negative_count_instcount / total_rows
    zero_percent_instcount = zero_count_instcount / total_rows
    geomean_diff_instcount = geomean(diff_instcount_col)
    positive_geomean_instcount = geomean(diff_instcount_col[diff_instcount_col > 0])
    negative_geomean_instcount = geomean(diff_instcount_col[diff_instcount_col < 0])
    zero_geomean_instcount = geomean(diff_instcount_col[diff_instcount_col == 0])

    # Calculate counts and percentages for size.text
    diff_sizetext_col = df["diff (size.text)"]
    positive_count_sizetext = (diff_sizetext_col > 0).sum()
    negative_count_sizetext = (diff_sizetext_col < 0).sum()
    zero_count_sizetext = (diff_sizetext_col == 0).sum()
    positive_percent_sizetext = positive_count_sizetext / total_rows
    negative_percent_sizetext = negative_count_sizetext / total_rows
    zero_percent_sizetext = zero_count_sizetext / total_rows
    geomean_diff_textsize = geomean(diff_sizetext_col)
    positive_geomean_sizetext = geomean(diff_sizetext_col[diff_sizetext_col > 0])
    negative_geomean_sizetext = geomean(diff_sizetext_col[diff_sizetext_col < 0])
    zero_geomean_sizetext = geomean(diff_sizetext_col[diff_sizetext_col == 0])

    # Create summary DataFrames for each category
    # Larger Programs
    larger_df = pd.DataFrame(
        {
            "Count": [positive_count_instcount, positive_count_sizetext],
            "% of total": [positive_percent_instcount, positive_percent_sizetext],
            "Geomean": [positive_geomean_instcount, positive_geomean_sizetext],
        },
        index=["Instcount", "Size.text"],
    )
    # Smaller Programs
    smaller_df = pd.DataFrame(
        {
            "Count": [negative_count_instcount, negative_count_sizetext],
            "% of total": [negative_percent_instcount, negative_percent_sizetext],
            "Geomean": [negative_geomean_instcount, negative_geomean_sizetext],
        },
        index=["Instcount", "Size.text"],
    )
    # Unchanged Programs
    unchanged_df = pd.DataFrame(
        {
            "Count": [zero_count_instcount, zero_count_sizetext],
            "% of total": [zero_percent_instcount, zero_percent_sizetext],
            "Geomean": [zero_geomean_instcount, zero_geomean_sizetext],
        },
        index=["Instcount", "Size.text"],
    )
    # Add Overall summary DataFrame with count and geomean
    overall_Df = pd.DataFrame(
        {
            "Total Programs": [total_rows, total_rows],
            "Geomean": [geomean_diff_instcount, geomean_diff_textsize],
        },
        index=["Instcount", "Size.text"],
    )

    # Format float columns to 2 decimal places for percent and geomean
    for df_ in [larger_df, smaller_df, unchanged_df]:
        df_["% of total"] = df_["% of total"].apply(lambda x: f"{x*100:.2f}%")
        df_["Geomean"] = df_["Geomean"].apply(lambda x: f"{x*100:.2f}%")
    overall_Df["Geomean"] = overall_Df["Geomean"].apply(lambda x: f"{x*100:.2f}%")

    print("Programs that got larger:")
    print(tabulate(larger_df, headers='keys', tablefmt='psql'))
    print("\nPrograms that got smaller:")
    print(tabulate(smaller_df, headers='keys', tablefmt='psql'))
    print("\nPrograms that didn't change:")
    print(tabulate(unchanged_df, headers='keys', tablefmt='psql'))
    print("\nOverall metrics:")
    print(tabulate(overall_Df, headers='keys', tablefmt='psql'))


if __name__ == "__main__":
    convert_to_tsv("comparison_results.txt", "comparison_results.tsv")
