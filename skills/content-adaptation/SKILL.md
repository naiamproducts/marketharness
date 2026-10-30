---
name: content-adaptation
description: Turn one canonical message into per-channel variants using brand/voice.md and {{vars}} placeholders. Use when the founder wants one announcement adapted for LinkedIn, X, newsletter, or a blog; use when marketagents-publish needs post variants before prepare; use when a positioning pillar becomes channel-shaped content. Drafts only — publishing goes through the connector confirm flow.
tags:
  - content
  - channels
  - adaptation
  - voice
  - drafts
version: 0.1.0
author: marketagents
license: MIT
---

# content-adaptation

## When to Use

- One canonical message must become variants for several channels (LinkedIn post, X thread, newsletter blurb, blog teaser).
- `marketagents-publish` needs a channel-shaped draft before the connector's `prepare` step.
- A messaging pillar from `strategy/positioning.md` becomes channel content.

## Do not use

- For drafting replies to incoming comments (use `response-drafting`).
- For structuring the brief (use `brief-intake`).
- **Never for publishing.** This skill produces draft files only. Publishing happens ONLY in the `marketagents-publish` flow: connector `prepare` → explicit user confirmation binding account + project + full text + attachments + target → connector `execute`. Any change after approval = new approval. Deleting content is forbidden.

## Prerequisites

1. Workspace files readable: `brand/voice.md`, `brand/identity.md`, `knowledge/approved-claims.md`, `strategy/positioning.md` (when it exists), `policies/publishing.md`.
2. The canonical message (from positioning, brief, or founder text).
3. Context entities resolvable: declare `Company / Project / Account` — the Account matters here, variants are written for a specific connected account and channel. If unresolved, ask — one question at a time. On project switch, re-resolve from files; no drafts carry over.
4. Target channel(s) named. If the founder says "everywhere", ask which channels the workspace actually has accounts for (`accounts/*.yaml`).

## Workflow

1. **Resolve and declare context.** `Company / Project / Account` from workspace files; list the authorized accounts relevant to this campaign.
2. **Extract canonical claims.** Every factual claim in the message must come from `knowledge/approved-claims.md` or a cited source; label anything else HYPOTHESIS and do not ship it as fact in a variant.
3. **Read the voice.** `brand/voice.md` governs tone, word choices, and forbidden phrasing for every variant. Variants differ in shape, not in voice.
4. **Define {{vars}}.** Any slot that changes per variant (hook, length, CTA, hashtags) is a `{{variable}}`. Fill each from workspace facts or the canonical message — never invent values. Unfilled vars stay as open `{{vars}}` and block the draft from being publish-ready.
5. **Adapt per channel**, respecting each channel's conventions (length, format, CTA style), with voice conformance checked against `brand/voice.md`. Each variant states its channel, account handle, and the vars used.
6. **Policy check.** Read `policies/publishing.md`: nothing in a variant may violate it (e.g., claims not approved, required disclosures missing).
7. **Label anything interpretive** in variant notes as `EVIDENCE | INTERPRETATION | HYPOTHESIS` with citations; the drafts themselves contain only approved/cited claims.
8. **Write the deliverables** and summarize chat as: list of variants with paths → open vars if any → next step is `marketagents-publish` (prepare → confirm), owned by the community workstream.

## Output Shape

Deliverable paths (relative to project dir):

```
campaigns/<campaign>/posts/<channel>-<slug>.md   (one file per variant)
```

Each variant file:

```markdown
# Post — <channel>

Context: Company / Project / Account: @<handle>
Campaign: <campaign>
Vars used: {{hook}} = ..., {{cta}} = ...

---

<the variant text, ready for the connector's prepare step>
```

Chat summary: variant list → open `{{vars}}` → "next: marketagents-publish (prepare → confirm → execute by connector)".
