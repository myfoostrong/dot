---
description: Conducts deep multi-source web research — clarifies via the question tool, consults prior tix research/plans, spawns parallel web-search-researcher subagents (z.ai web search), cross-verifies claims, and saves a cited report to tix/research/.
---

# Deep Research

Research topic: $ARGUMENTS

You are a lead research agent. Orchestrate parallel `@web-search-researcher`
workers and synthesize their findings into a verified, cited report saved to
`tix/research/`. If no research topic was supplied in `$ARGUMENTS`, ask the
user for the topic before Phase 1.

---

## Phase 1: Clarify (mandatory — do not skip)

Before searching anything, ask the user these questions. Use the `question`
tool to ask all of them in one batched interaction (a single call containing
three questions). If the `question` tool is unavailable, fall back to asking
them in one prose message.

1. What aspect matters most — breadth across the topic, or depth on a specific angle?
2. Any time range, geography, or domain to focus on or exclude?
3. What should the final output look like? (executive summary, detailed report, bullet list, etc.)

Wait for the user's answers before proceeding to Phase 2.

---

## Phase 2: Prior context

Before decomposing, check for prior work on this topic in the tix store:

1. Spawn `@tix-locator` to find related documents in `tix/research/` and `tix/plans/` (and `tix/issues/` or `tix/handoffs/` if relevant).
2. From its results, spawn `@tix-analyzer` on the 1–3 most relevant documents to extract decisions, constraints, and prior findings.
3. Fold what you learn into decomposition (Phase 3), and cite the prior documents in a short "Related prior work" note in the final report.

If no relevant prior work is found, proceed to Phase 3 and note that no prior tix context was available.

---

## Phase 3: Decompose

Break the research question into 3–6 independent sub-questions that:
- Cover distinct angles (e.g. technical, historical, economic, critical)
- Do not overlap — each agent should surface different information
- Are specific enough that a focused search can answer them

Write out your decomposition before spawning any agents, so the user can see your plan.

---

## Phase 4: Spawn parallel researchers

Launch one `@web-search-researcher` subagent per sub-question using the `task` tool, in parallel — a single message with multiple `task` tool calls. Do **not** run them sequentially.

Each worker spawn prompt must include:
- **Objective**: the specific sub-question (from Phase 3), restated in full.
- **Constraints**: any scope from the user's Phase 1 answers (time range, geography, domain, exclusions).
- **Source priorities**: which source types to prioritize — primary/official/academic sources first, then reputable secondary sources.
- **Exclusions**: sources to avoid (anything from Phase 1, plus SEO/content-farm pages and low-quality aggregators).
- **Output format**: the worker's structured return format (already defined in the `web-search-researcher` agent).
- **Confidence**: an explicit request for a confidence rating (high / medium / low) and any single-source or disputed-claim flags.

**Spawn all agents before waiting for any results.**

---

## Phase 5: Adversarial verification

Once all agents report back, maintain a claim ledger as you read the results, then do the following before writing the report:

- **Corroborated**: a claim supported by two or more independent sources → report normally.
- **Disputed**: two agents/sources found conflicting information → note both positions and their sources; do not pick a winner.
- **Unverified, single source**: an important claim appearing in only one agent's findings → mark as "unverified, single source" in the report.
- **Critical claims**: for any claim that is central to the user's question and high-stakes, spawn one additional `@web-search-researcher` agent specifically tasked with verifying or refuting it. Frame the task neutrally — do not anchor it with the desired answer.

---

## Phase 6: Synthesize and save

Write the final report in this format (frontmatter + header follow the `research_codebase` convention; the body keeps the deep-research structure):

```markdown
---
date: [ISO 8601 datetime with timezone]
researcher: [git user.name]
git_commit: [short hash]
branch: [branch name]
repository: [repo name]
topic: "[research topic]"
tags: [research, web, deep-research, <topic-keywords>]
status: complete
last_updated: [YYYY-MM-DD]
last_updated_by: [git user.name]
---

# Research Report: [Topic]

**Date**: [ISO datetime with timezone]
**Researcher**: [git user.name]
**Subagents deployed**: [N] | **Sources**: [N]

## Summary
[3–5 sentence overview of the main findings]

## [Section heading for each major theme]
[Prose. Cite inline: claim ([Source Name](URL)). Prefer primary/official/
academic sources; avoid SEO/content-farm pages; trace secondary claims to
originals where feasible.]

## Conflicts and Uncertainties
[Disputed claims with both positions + sources; claims marked
"unverified, single source". If none: "All major findings were corroborated
across sources."]

## Sources
1. [URL]
2. [URL]
[complete numbered list]
```

Gather the frontmatter metadata **before** writing — never use placeholders:
- `date`: `date -Iseconds`
- `researcher`: `git config user.name`
- `git_commit`: `git rev-parse --short HEAD`
- `branch`: `git branch --show-current`
- `repository`: basename of `git rev-parse --show-toplevel`

Save the report using the `write` tool:
- Location: `tix/research/` (create the directory first if it does not exist).
- Filename: `YYYY-MM-DD-RESEARCH-<topic-slug>.md`, where `<topic-slug>` is the topic in lowercase, hyphenated form (e.g. `solid-state-ev-batteries`).
- Writing requires the `edit` permission; if it is not granted, stop and tell the user.

Tell the user where the file was saved.

### Follow-up protocol

If the user asks a follow-up question after the report is written, do **not** create a new file. Instead, append to the same report:
- Add a `## Follow-up Research [timestamp]` section answering the follow-up (spawn new `@web-search-researcher` agents as needed, verifying claims with the Phase 5 rules).
- Update the frontmatter: bump `last_updated` to today's date, set `last_updated_by` to the current `git user.name`, and add `last_updated_note: "Added follow-up research for [brief description]"`.

## Success Criteria

- Phase 1 clarification ran before any search.
- Prior tix research/plans were checked (Phase 2) and folded into the report.
- Subagents ran in parallel (not sequentially), each on a non-overlapping sub-question with a full delegation contract.
- Single-source and conflicting claims are explicitly marked via the claim ledger.
- A cited markdown report with valid frontmatter was written to `tix/research/` and its path reported to the user.
