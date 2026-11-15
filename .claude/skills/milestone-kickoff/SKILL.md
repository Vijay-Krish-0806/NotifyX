---
name: milestone-kickoff
description: Start a NotifyX milestone design-first. Explains concepts, options and trade-offs, the ADRs needed and a step list with checks. Writes no code.
disable-model-invocation: true
argument-hint: "[milestone, e.g. M1]"
arguments: [milestone]
---

# Milestone kickoff: $milestone

If `$milestone` is empty, use the "Current milestone" in CLAUDE.md.

**Do not create or edit any files during kickoff.** This is design only.

## 1. Read first

- CLAUDE.md and docs/PROJECT_CONTEXT.md.
- NOTIFYX_BUILD_PLAN.md: Sections 1-7 in full, the milestone's section in Section 8, Section 11 (Definition of Done) and Appendix B (ADR list).
- Every existing doc in docs/ and ADR in docs/adr/ that the milestone touches.
- The existing code the milestone builds on. Follow its conventions.

## 2. Present the kickoff (in this order, plain English)

1. **Goal and "Done when"** in your own words.
2. **Concepts to learn.** Each with a short explanation and why it matters in NotifyX.
3. **Design decisions.** For each decision point: the options, the trade-offs, and a recommendation. Name the pattern used and why it fits.
4. **ADRs needed.** Number and title (from Appendix B, plus any new ones).
5. **Libraries and versions to verify.** For each: what to check in the official docs. Verify before using; never code from memory.
6. **Step list.** Small, reviewable steps that each leave the project runnable. For every step, a concrete check (command, test or demo) and the commit message it will use.
7. **Docs to create or update.** Every new table, topic, Redis key pattern, endpoint or env var (hard rule 8).
8. **Just-in-time tooling.** Any rule, skill, subagent or hook that this milestone's real code now justifies, with its context cost. Propose only; do not create.
9. **Flags.** Anything in the plan that looks wrong, ambiguous, conflicts with the code, or is too heavy for 1-2 hours a day.

## 3. Finish

End with a short numbered list of the decisions the owner must make. Then wait for approval before building step 1.
