---
name: milestone-teachback
description: Close a NotifyX milestone. Quizzes the owner with 5 questions, grades the answers, drafts the learning-journal entry and checks the Definition of Done.
disable-model-invocation: true
argument-hint: "[milestone, e.g. M1]"
arguments: [milestone]
---

# Milestone teach-back: $milestone

If `$milestone` is empty, use the "Current milestone" in CLAUDE.md.

Read first: the milestone's section in NOTIFYX_BUILD_PLAN.md (including its Teach-back questions), the ADRs and docs written in this milestone, and `git log` since the previous milestone tag.

## Part 1: Quiz (one question at a time)

Ask 5 questions, one of each type, grounded in what was **actually built** (files, ADRs, commits), not generic theory. Use the plan's teach-back questions as seeds.

1. **Concept:** what is X, and what problem does it solve here?
2. **Why this, not that:** why the chosen option over a rejected alternative?
3. **Failure scenario:** what happens when Y breaks, and how does the system react?
4. **Scaling scenario:** what changes at 10x or 100x load?
5. **Interview:** explain one part as if defending it in a system design interview.

Rules:

- Ask **one** question, then wait for the owner's answer. Never reveal the answer first.
- Grade each answer: **correct**, **partly correct** or **gap**. Explain what was missing in plain English, and point to the file or ADR that shows it.
- "I don't know" is a fine answer: teach the concept briefly, then move on.

## Part 2: Learning journal

Draft `docs/learning-journal/$milestone.md` with these sections:

- **What changed:** short list, with commit hashes and ADR links.
- **Why:** the main decisions in one or two lines each.
- **What failed or surprised:** real problems hit during the milestone.
- **What I learned:** taken from the owner's quiz answers, in their words.
- **Open questions:** things still unclear.
- **Teach-back results:** each question, its grade and a one-line note.

No secrets, personal details or proprietary information (the repo may be public). Show the draft, write it after approval, and commit it as `docs: add $milestone learning journal`.

## Part 3: Definition of Done

Check every item in NOTIFYX_BUILD_PLAN.md Section 11. For each, report **done** or **not done** with real evidence (command output, file, commit). Do not mark anything done without evidence.

Then propose, and do only after approval:

- updating "Current milestone" in CLAUDE.md to the next milestone;
- creating the milestone tag (e.g. `m1-foundation`) and pushing it.
