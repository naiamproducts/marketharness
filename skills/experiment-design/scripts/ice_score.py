#!/usr/bin/env python3
"""ICE scoring for experiment candidates.

Reads CSV (header: name,impact,confidence,effort) from stdin or a file,
computes ICE = impact * confidence / effort for each row, ranks descending,
and flags each row against a pre-registered threshold.

Stdlib only. Exit codes: 0 ok, 1 input/validation error.
"""
import argparse
import csv
import io
import sys

ERROR_JSON = False  # humans run this interactively; prose errors are fine


def parse_args(argv=None):
    p = argparse.ArgumentParser(
        prog="ice_score.py",
        description="Rank experiment candidates by ICE score and check a "
                    "pre-registered threshold.",
        epilog="CSV columns: name,impact,confidence,effort (effort 1-10, "
               "low effort = high score). Scores 1-10.",
    )
    p.add_argument("csv_file", nargs="?", default="-",
                   help="CSV file path, or '-' for stdin (default)")
    p.add_argument("--threshold", type=float, required=True,
                   help="Pre-registered minimum ICE score for a candidate "
                        "to meet the bar (e.g. 6.0)")
    p.add_argument("--top", type=int, default=0,
                   help="Show only the top N candidates (0 = all)")
    return p.parse_args(argv)


def read_rows(src):
    text = sys.stdin.read() if src == "-" else open(src, encoding="utf-8").read()
    reader = csv.DictReader(io.StringIO(text))
    required = {"name", "impact", "confidence", "effort"}
    if reader.fieldnames is None:
        raise ValueError("empty CSV input (expected header: name,impact,confidence,effort)")
    fields = {f.strip().lower() for f in reader.fieldnames}
    missing = required - fields
    if missing:
        raise ValueError(f"missing CSV columns: {', '.join(sorted(missing))}")
    rows = []
    for i, raw in enumerate(reader, start=2):
        row = {k.strip().lower(): (v or "").strip() for k, v in raw.items() if k}
        name = row.get("name", "")
        if not name:
            raise ValueError(f"line {i}: empty name")
        try:
            impact = float(row["impact"])
            confidence = float(row["confidence"])
            effort = float(row["effort"])
        except (KeyError, ValueError):
            raise ValueError(f"line {i} ({name}): impact/confidence/effort must be numbers")
        for label, v in (("impact", impact), ("confidence", confidence), ("effort", effort)):
            if not 1 <= v <= 10:
                raise ValueError(f"line {i} ({name}): {label}={v} out of range 1-10")
        if effort <= 0:
            raise ValueError(f"line {i} ({name}): effort must be > 0")
        rows.append({"name": name, "impact": impact, "confidence": confidence,
                     "effort": effort})
    if not rows:
        raise ValueError("CSV has a header but no candidate rows")
    return rows


def main(argv=None):
    args = parse_args(argv)
    try:
        rows = read_rows(args.csv_file)
    except (ValueError, OSError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    for r in rows:
        r["ice"] = round(r["impact"] * r["confidence"] / r["effort"], 2)
    rows.sort(key=lambda r: (-r["ice"], r["name"]))

    threshold = args.threshold
    shown = rows[: args.top] if args.top > 0 else rows
    width = max(len(r["name"]) for r in shown)

    print(f"Pre-registered threshold: ICE >= {threshold}")
    print(f"{'rank':>4}  {'name':<{width}}  {'I':>4}  {'C':>4}  {'E':>4}  "
          f"{'ICE':>6}  meets_threshold")
    for rank, r in enumerate(rows, 1):
        if r not in shown:
            continue
        meets = "yes" if r["ice"] >= threshold else "no"
        print(f"{rank:>4}  {r['name']:<{width}}  {r['impact']:>4}  "
              f"{r['confidence']:>4}  {r['effort']:>4}  {r['ice']:>6}  {meets}")

    passing = sum(1 for r in rows if r["ice"] >= threshold)
    print(f"{passing}/{len(rows)} candidates meet the pre-registered threshold")
    return 0


if __name__ == "__main__":
    sys.exit(main())
