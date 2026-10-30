---
name: positioning
description: Positioning statement and messaging pillars grounded in brand/identity.md and brand/voice.md. Use when the founder asks how to position the product, what the messaging pillars should be, or how to differentiate against competitors; use when marketharness-experiment's growth workstream needs the positioning layer; use before content adaptation needs a canonical message to adapt.
tags:
  - positioning
  - messaging
  - pillars
  - brand
  - growth
version: 0.1.0
author: marketharness
license: MIT
---

# positioning

## When to Use

- The founder asks "how should we position this?", "what are our messaging pillars?", "why us over X?".
- A launch or campaign needs a canonical positioning statement before content work starts.
- `content-adaptation` needs the one message it will adapt per channel.

## Do not use

- For audience discovery itself (use `audience-research` first — positioning needs audience evidence).
- For designing experiments (use `experiment-design`, though positioning often feeds its hypotheses).
- For drafting channel content (use `content-adaptation`).
- Never for publishing: this skill produces strategy documents, never connector actions.

## Prerequisites

1. Workspace files readable: `brand/identity.md`, `brand/voice.md`, `knowledge/product.md`, `knowledge/approved-claims.md`, plus `research/` files when they exist.
2. Context entities resolvable. Declare `Company / Project / Account`; if unresolved, ask — one question at a time. On project switch, re-resolve from files.
3. Audience evidence: if no `research/` file covers the target audience, either run `audience-research` first or mark audience assumptions explicitly as HYPOTHESIS.

## Workflow

1. **Resolve and declare context.** `Company / Project / Account` from workspace files.
2. **Read the brand ground truth:** `brand/identity.md` and `brand/voice.md`. The positioning must be expressible in the existing voice; a positioning the brand cannot say is fiction.
3. **Read product truth:** `knowledge/product.md` and `knowledge/approved-claims.md`. Only approved claims may appear as factual pillars — anything else is HYPOTHESIS until approved.
4. **Gather competitive context** from `research/` files and cited sources; label as in evidence discipline.
5. **Draft the positioning statement** in the classic form, filling each slot with cited content:
   > For **[audience]** who **[need/struggle]**, **[product]** is a **[category]** that **[key benefit]**. Unlike **[alternative]**, **[primary differentiation]**.
6. **Derive 3-5 messaging pillars.** Each pillar: a claim (approved-claims-backed or labeled), the audience need it answers, and one proof point with citation. Pillars must be independently testable in experiments.
7. **Label every element** with exactly one of `EVIDENCE | INTERPRETATION | HYPOTHESIS`:`EVIDENCE` (cited workspace path:line or URL), `INTERPRETATION`, `HYPOTHESIS`. Audience slots filled from uncited assumptions are HYPOTHESIS — say so.
8. **Voice check:** rewrite each pillar in the tone of `brand/voice.md`; flag any pillar the voice doc would forbid.
9. **Write the deliverable** and summarize chat as: verdict → evidence → deliverable path → next steps (typically: test pillars via `experiment-design`).

## Output Shape

Deliverable path (relative to project dir):

```
strategy/positioning.md
```

Document shape:

```markdown
# Positioning — <project>

Context: Company / Project / Account

## Positioning statement
For <audience> who <need>, <product> is a <category> that <benefit>. Unlike <alternative>, <differentiation>.
(<each slot cites a source or is labeled HYPOTHESIS>)

## Messaging pillars
### Pillar 1: <name>
- Claim: <EVIDENCE | HYPOTHESIS> — <path:line | URL>
- Audience need: <ref>
- Proof point: <citation>

... (3-5 pillars)

## Voice conformance
- Checked against brand/voice.md; notes: ...

## Next steps
- <action> → <owning workstream>
```
