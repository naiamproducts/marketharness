---
name: brief-intake
description: Turn a raw founder brief into a structured goal/context/audience/success-criteria document and route it to the right workstream. Use when the founder drops a raw brief, an objective, a launch plan, or a vague "we need marketing for X" request; use when marketing-lead receives an objective via the marketagents-brief command; use to structure an incoming request before delegating to research/growth/community.
tags:
  - brief
  - intake
  - routing
  - marketing-lead
  - structuring
version: 0.1.0
author: marketagents
license: MIT
---

# brief-intake

## When to Use

- The founder drops a raw brief: a pasted message, a file path, or a spoken objective like "we need to launch on LinkedIn next month".
- `marketagents-brief` needs to structure an objective before routing it.
- Any request arrives too vague to delegate: the skill forces goal/context/audience/success-criteria into shape first.

## Do not use

- For audience questions already scoped (use `audience-research`).
- For positioning or experiment drafting (use `positioning` / `experiment-design`).
- For community comments or replies (use `community-triage` / `response-drafting`).
- Never for publishing: this skill produces a document, never a connector action.

## Prerequisites

1. Workspace files readable (`workspace.yaml`, `companies/<company>/company.yaml`, `companies/<company>/projects/<project>/project.yaml`).
2. The raw brief text or file path.
3. Loaded context entities (see Workflow step 1). If Company or Project is unresolved after checking the files, ask — never guess.

## Workflow

1. **Resolve context.** Read `workspace.yaml`, then the company and project files. Declare the working context as `Company / Project / Account` (Account may be `none` at intake). If exactly one company and one project exist, you may state them and confirm; if more than one exists or files are missing, ask — one question at a time. On a project switch, re-resolve all three entities from files and state them fresh — nothing carries over. No structuring proceeds on unresolved entities.
2. **Capture the raw brief verbatim.** Paste the founder's own words into the draft document before interpreting anything. This is the ground truth for later verdicts.
3. **Extract the four structure fields**, quoting the founder's text for each:
   - **Goal** — what launch/position/audience outcome is wanted.
   - **Context** — why now, what has been tried, competitive situation.
   - **Audience** — who this is for, as stated (gaps become questions, not assumptions).
   - **Success criteria** — measurable outcome or deadline, as stated.
4. **Gap questions.** For every field with no founder statement, write ONE question. Ask them one at a time, only for gaps. Never fill a gap with a guess.
5. **Evidence pass.** Label each extracted field with exactly one of `EVIDENCE | INTERPRETATION | HYPOTHESIS`, citing the source:
   - `EVIDENCE` — directly quoted from the brief or a cited workspace file (path).
   - `INTERPRETATION` — your reading of an ambiguous founder statement (say what else it could mean).
   - `HYPOTHESIS` — anything not in the brief at all (should only be the questions you generated).
6. **Route.** Decide workstream(s): audience questions → `research`; positioning or experiments → `growth`; posts/replies/triage → `community`. State the dispatch plan in one line. (The marketing lead owns the actual delegation; here you only record the routing decision.)
7. **Write the deliverable** to the campaign's `brief.md` (see Output Shape). If no campaign exists yet for this brief, create `campaigns/<slug-of-brief>/` under the project.

## Output Shape

Deliverable path (relative to project dir):

```
campaigns/<campaign>/brief.md
```

Document shape:

```markdown
# Brief — <campaign slug>

Context: Company / Project / Account

## Raw brief (verbatim)
<founder's words>

## Goal
<EVIDENCE | INTERPRETATION>: ...

## Context
<EVIDENCE | INTERPRETATION>: ...

## Audience
<EVIDENCE | INTERPRETATION | HYPOTHESIS>: ...

## Success criteria
<EVIDENCE | HYPOTHESIS>: ...

## Open questions (one per gap)
1. ...

## Routing
- research: <what>
- growth: <what>
- community: <what>
```

Plus the chat summary: verdict `READY / NEEDS-INPUT` → evidence → deliverable path → next steps.
