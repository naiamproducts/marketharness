#!/usr/bin/env python3
"""Metric delta for results-review.

Compares baseline vs current metrics and gives a threshold verdict against
an experiment's pre-registered success/kill thresholds.

Single mode (args):
    metric_delta.py --metric clicks --baseline 120 --current 187 \
        --success-threshold 1.5 --kill-threshold 0.8

Batch mode (stdin CSV, header: metric,baseline,current):
    metric_delta.py --success-threshold 1.5 --kill-threshold 0.8 < metrics.csv

Verdict (relative change, relative = current/baseline):
    current/baseline >= success-threshold  -> VALIDATED
    current/baseline <= kill-threshold     -> REJECTED
    else                                   -> PROMISING
Batch rows without a current value are UNVALIDATED (missing data).

Thresholds are the experiment's PRE-REGISTERED ones — pass the values from
experiments/<name>.md; never choose them after seeing the data.

Exit codes: 0 ok, 1 input/validation error.
"""
import argparse
import csv
import io
import sys


def parse_args(argv=None):
    p = argparse.ArgumentParser(
        prog="metric_delta.py",
        description="Compute baseline-vs-current delta and a "
                    "VALIDATED/PROMISING/UNVALIDATED/REJECTED verdict against "
                    "pre-registered thresholds.",
        epilog="Single mode uses --baseline/--current; batch mode reads "
               "CSV (metric,baseline,current) from stdin.",
    )
    p.add_argument("--metric", help="Metric name (single mode)")
    p.add_argument("--baseline", type=float, help="Baseline value (single mode)")
    p.add_argument("--current", type=float, help="Current value (single mode)")
    p.add_argument("--success-threshold", type=float, required=True,
                   help="Pre-registered success threshold as a ratio "
                        "current/baseline (e.g. 1.5 = +50%%)")
    p.add_argument("--kill-threshold", type=float, required=True,
                   help="Pre-registered kill threshold as a ratio "
                        "(e.g. 0.8 = -20%%)")
    p.add_argument("--direction", choices=["up", "down"], default="up",
                   help="Whether higher is better (up, default) or lower "
                        "(down, e.g. churn, cost-per-lead)")
    return p.parse_args(argv)


def verdict(ratio, success_t, kill_t, direction):
    if ratio is None:
        return "UNVALIDATED"
    if direction == "up":
        if ratio >= success_t:
            return "VALIDATED"
        if ratio <= kill_t:
            return "REJECTED"
    else:  # down: improvement means ratio below success threshold
        if ratio <= success_t:
            return "VALIDATED"
        if ratio >= kill_t:
            return "REJECTED"
    return "PROMISING"


def evaluate(metric, baseline, current, success_t, kill_t, direction):
    if baseline is None or current is None:
        return {"metric": metric, "baseline": baseline, "current": current,
                "delta": None, "relative": None, "ratio": None,
                "verdict": "UNVALIDATED"}
    delta = current - baseline
    if baseline == 0:
        ratio = None if current == 0 else float("inf")
        relative = None if current == 0 else "undefined (baseline=0)"
    else:
        ratio = current / baseline
        relative = f"{(ratio - 1) * 100:+.1f}%"
    v = verdict(ratio, success_t, kill_t, direction) if ratio is not None else \
        ("UNVALIDATED" if current == 0 else verdict(
            float("inf") if direction == "up" else 0.0, success_t, kill_t, direction))
    return {"metric": metric, "baseline": baseline, "current": current,
            "delta": delta, "relative": relative, "ratio": ratio, "verdict": v}


def fmt(v):
    ratio = "n/a" if v["ratio"] is None else (
        "inf" if v["ratio"] == float("inf") else f"{v['ratio']:.3f}")
    rel = v["relative"] if v["relative"] is not None else "n/a"
    delta = "n/a" if v["delta"] is None else f"{v['delta']:+g}"
    return (f"{v['metric']}: baseline {v['baseline']} -> current {v['current']} "
            f"(delta {delta}, relative {rel}, ratio {ratio}) -> {v['verdict']}")


def main(argv=None):
    args = parse_args(argv)
    s_t, k_t = args.success_threshold, args.kill_threshold
    single = args.baseline is not None or args.current is not None

    if single:
        if not (args.metric and args.baseline is not None and args.current is not None):
            print("error: single mode needs --metric, --baseline and --current "
                  "together (or use stdin CSV batch mode)", file=sys.stderr)
            return 1
        results = [evaluate(args.metric, args.baseline, args.current, s_t, k_t,
                            args.direction)]
    else:
        try:
            text = sys.stdin.read()
        except OSError as e:
            print(f"error: {e}", file=sys.stderr)
            return 1
        reader = csv.DictReader(io.StringIO(text))
        if reader.fieldnames is None:
            print("error: empty stdin (expected header: metric,baseline,current)",
                  file=sys.stderr)
            return 1
        results = []
        for i, raw in enumerate(reader, start=2):
            row = {k.strip().lower(): (v or "").strip() for k, v in raw.items() if k}
            metric = row.get("metric", "")
            if not metric:
                print(f"error: line {i}: empty metric name", file=sys.stderr)
                return 1
            try:
                baseline = float(row["baseline"]) if row.get("baseline") else None
                current = float(row["current"]) if row.get("current") else None
            except ValueError:
                print(f"error: line {i} ({metric}): baseline/current must be numbers "
                      "or empty", file=sys.stderr)
                return 1
            results.append(evaluate(metric, baseline, current, s_t, k_t,
                                    args.direction))
        if not results:
            print("error: CSV has a header but no rows", file=sys.stderr)
            return 1

    print(f"Pre-registered thresholds: success ratio {s_t}, kill ratio {k_t}, "
          f"direction {args.direction}")
    for v in results:
        print(fmt(v))
    return 0


if __name__ == "__main__":
    sys.exit(main())
