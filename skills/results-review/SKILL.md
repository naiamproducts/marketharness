---
name: results-review
description: Judge experiment outcomes — verdict per experiment (VALIDATED / PROMISING / UNVALIDATED / REJECTED) from the connector action log and metric files against pre-registered thresholds; writes reports/. Use when the founder asks how experiments performed; use when marketagents-report consolidates results; use at experiment timebox end. Read-only plus a report file — never prepares or executes connector actions.
tags:
  - results
  - review
  - metrics
  - verdict
  - reporting
version: 0.1.0
author: marketagents
license: MIT
---

# results-review

## When to Use

- The founder asks "how did that experiment go?".
- `marketagents-report` consolidates results across experiments.
- An experiment's timebox ended and a verdict is due.

## Do not use

- For designing experiments (use `experiment-design`; results-review judges against the thresholds that skill pre-registered).
- For publishing or any connector mutation. Connector usage here is read-only: `status <action_id>` to check recorded external actions, under the ask gate. Never `prepare`, never `execute`. Deleting content is forbidden.

## Prerequisites

1. Workspace files readable: each `experiments/<name>.md` in scope, the connector action log `<workspace>/.connector-log.jsonl`, and metric files (paths recorded in the experiment spec).
2. Context entities resolvable: declare `Company / Project / Account`; if unresolved, ask — one question at a time. On project switch, re-resolve from files.
3. Pre-registered thresholds present in the experiment file. Missing thresholds → verdict `UNVALIDATED` and flag the experiment as needing redesign; never invent post-hoc thresholds.

## Workflow

1. **Resolve and declare context.** `Company / Project / Account` from workspace files; identify the reporting scope (one experiment / one project / all).
2. **Read the experiment specs.** For each experiment, extract: hypothesis, metric definition, baseline, success threshold, kill threshold, timebox end, status.
3. **Read the action log.** Parse `<workspace>/.connector-log.jsonl`; confirm which experiment content actually shipped (dedup on `action_id`; a PREPARED-but-never-executed action means the test never ran).
4. **Read the metrics — from files, never invented.** Numbers come from the metric file paths the experiment spec recorded, or from `status` on the relevant action_ids. Every number carries a citation (`path:line` when possible) and one label from `EVIDENCE | INTERPRETATION | HYPOTHESIS`; uncited numbers are HYPOTHESIS and cannot support a verdict.
5. **Compute deltas deterministically** with the script (python3 stdlib):

   ```bash
   python3 skills/results-review/scripts/metric_delta.py \
     --metric clicks --baseline 120 --current 187 \
     --success-threshold 1.5 --kill-threshold 0.8
   ```

   The script prints absolute delta, relative change, and the threshold verdict. It accepts baseline/current as args or CSV on stdin (`metric,baseline,current`).
6. **Assign the verdict per experiment** — vocabulary is fixed:
   - `VALIDATED` — metric reached/exceeded the pre-registered success threshold within the timebox.
   - `PROMISING` — moved in the right direction, between kill and success thresholds.
   - `UNVALIDATED` — insufficient data (timebox too short, sample too small, action never executed) or metrics missing/uncited.
   - `REJECTED` — metric hit the pre-registered kill threshold.
   A negative result (`REJECTED`) is a first-class finding — report it plainly.
7. **Flag threshold drift.** If an experiment file's thresholds were edited after data collection started (compare file history/dates when visible), the verdict is downgraded to `UNVALIDATED` with the reason.
8. **Write the report deliverable** (see Output Shape) and summarize chat as: one-paragraph snapshot → one verdict line per experiment with threshold evidence → next steps (continue / iterate / kill, owning workstream).

## Output Shape

Deliverable path (relative to project dir):

```
reports/<scope-slug>.md
```

Report shape:

```markdown
# Results report — <scope>

Context: Company / Project / Account
Period: <from> → <to>

## Snapshot
<one paragraph>

## Verdicts
- <experiment>: VALIDATED | PROMISING | UNVALIDATED | REJECTED
  - Metric: <name> baseline <v> → current <v> (source: path:line)
  - Threshold evidence: success <v> / kill <v> (source: experiments/<name>.md)
  - Shipped evidence: action_id <id>, external_id <id> (.connector-log.jsonl)

## Next steps
- <experiment>: continue | iterate | kill → <owning workstream>
```
