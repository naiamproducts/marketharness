---
name: experiment-design
description: Falsifiable hypotheses, minimal tests, and pre-registered success/kill thresholds; ranks candidate ideas with scripts/ice_score.py. Use when the founder wants to test a positioning, a channel, or a growth idea; use when marketharness-experiment designs a test; use before any campaign whose result must be judgeable — a negative result is a first-class finding.
tags:
  - experiments
  - hypotheses
  - thresholds
  - ice
  - growth
version: 0.1.0
author: marketharness
license: MIT
---

# experiment-design

## When to Use

- The founder wants to test a claim, channel, or growth idea.
- `marketharness-experiment` designs a test with pre-registered thresholds.
- Multiple candidate ideas exist and need prioritization (ICE scoring).
- A campaign must be judgeable later by `results-review` — which requires thresholds written BEFORE data collection.

## Do not use

- For reading results of already-run experiments (use `results-review`).
- For producing the test content itself (posts/replies are drafted by `content-adaptation` / `response-drafting` and published only via the connector confirm flow — never here).
- Never for publishing: this skill produces experiment specs, never connector actions.

## Prerequisites

1. Workspace files readable: `strategy/positioning.md` when it exists, `research/` for audience evidence, `knowledge/approved-claims.md`.
2. Context entities resolvable. Declare `Company / Project / Account`; if unresolved, ask — one question at a time. On project switch, re-resolve from files.
3. The metric that will decide success, and a timebox — if either is missing after asking the founder, verdict is `NEEDS-INPUT`.

## Workflow

1. **Resolve and declare context.** `Company / Project / Account` from workspace files.
2. **State the hypothesis as falsifiable:** "<audience> will <action> because <reason>, measured by <metric>." If it cannot be proven false, rewrite it until it can.
3. **Design the minimal test** that can falsify the hypothesis: the single channel, the smallest content set, the shortest timebox. Name the channel and content needed; note that content drafting is a community-workstream job (`content-adaptation` → `marketharness-publish`), not this skill's output.
4. **Pre-register BOTH thresholds BEFORE any data is collected** — this is the skill's core rule:
   - **Success threshold**: the metric value that means VALIDATED.
   - **Kill threshold**: the metric value that means REJECTED.
   - Record the timebox end date. Post-hoc threshold edits invalidate the experiment — `results-review` will flag them.
5. **Optional: ICE-rank a batch of candidates.** When several ideas compete, run the script (python3 stdlib) to rank and threshold-check them:

   ```bash
   python3 skills/experiment-design/scripts/ice_score.py --threshold 6.0 <<'CSV'
   name,impact,confidence,effort
   linkedin-founder-voice,8,6,3
   paid-ads-test,7,5,5
   CSV
   ```

   The script prints the ranked list with ICE scores and a `meets_threshold` flag per row. Score each dimension 1-10; effort is inverted (low effort = high score).
6. **Cite every assumption** with a label from `EVIDENCE | INTERPRETATION | HYPOTHESIS`. Audience assumptions cite `research/` or are HYPOTHESIS; metric baselines cite a file or are recorded as "no baseline — first run defines it".
7. **Write the deliverable** and summarize chat as: verdict at design time (`READY / NEEDS-INPUT`) → assumptions with citations → experiment spec → next steps.

## Output Shape

Deliverable path (relative to project dir):

```
experiments/<name>.md
```

Document shape:

```markdown
# Experiment — <name>

Context: Company / Project / Account
Status: DESIGNED
Owner: <who reads the results>

## Hypothesis
<audience> will <action> because <reason>, measured by <metric>.
(Audience evidence: <path | HYPOTHESIS>)

## Minimal test
- Channel: ...
- Content needed: <drafted by community via marketharness-publish>
- Timebox: <start> → <end>

## Pre-registered thresholds (fixed before data)
- Metric: <name, definition, source>
- Baseline: <value + citation | "none — first run defines it">
- Success threshold (VALIDATED): <value>
- Kill threshold (REJECTED): <value>
- In-between: PROMISING / UNVALIDATED per results-review vocabulary

## ICE ranking (optional)
<ice_score.py output, or omitted>
```
