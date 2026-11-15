# NotifyX

Multi-tenant, event-driven notification platform (NestJS, PostgreSQL, Kafka, Redis, Next.js).
Built mainly to learn production-grade system design. Claude Code writes the code; the owner reviews and learns the architecture.

## Read first

- docs/PROJECT_CONTEXT.md: one-page summary of scope, architecture and rules. Read it at the start of every session. (Being created in M0.)
- NOTIFYX_BUILD_PLAN.md: the full source of truth. Read the current milestone before any change. Read Sections 1-7 in full at milestone kickoff.

## Current milestone

M0 (workflow + docs skeleton). Done when a fresh session, given only this repo, can state the hard rules, non-goals and current milestone correctly.
Update this section when a milestone is finished.

## Non-goals (only with an approved ADR)

Kubernetes, service mesh, many microservices, custom database, event sourcing, schema registry, ClickHouse or data lake, RAG or chatbots, autonomous agents, GraphQL, multi-region. The shape is a modular monolith plus one worker process.

## Working rules

1. Explain before building: the problem, the options, the choice, the trade-off. Name the pattern and why it fits. Use plain, simple English.
2. Work in small, reviewable steps. Wait for approval between steps. Keep the project runnable after each one.
3. Verify library and framework APIs against current official docs before using them, and state the version. Never code from memory.
4. Run it: typecheck, lint, tests. Show real output. Never claim something works without running it.
5. Say "I don't know" or "I couldn't verify" instead of guessing. Never invent numbers, links, benchmarks, tables, topics, endpoints or env vars.
6. If the plan and the code conflict, or a plan decision looks wrong, stop and ask. Propose an ADR; no silent architecture changes.
7. Don't spawn subagents unless the owner asks.
8. Record significant decisions as ADRs in docs/adr/.

## Git

- Commit at the end of each approved step, with a conventional commit message (feat:, fix:, docs:, chore:, test:, refactor:).
- Pushing to origin after a commit is allowed.
- Never force-push, amend, rebase or rewrite history without asking.
- Never commit .env files, keys or secrets.

## Hard rules

1. PostgreSQL is the source of truth. Kafka moves events; Redis accelerates. Neither is the only record of a notification.
2. packages/core imports no framework, ORM, Kafka, Redis, HTTP or provider SDK. It depends only on ports (interfaces).
3. Auth, tenant resolution, rate limiting and idempotency live only in the gateway module.
4. Every tenant-owned table has organization_id. Every query is tenant-scoped from the authenticated context, never from a client-supplied id.
5. Notification status changes only through the state machine in packages/core.
6. Never store raw API keys (hash only). Never log secrets, tokens or full PII.
7. Every schema change is a migration. Never edit an applied migration.
8. No new table, Kafka topic, Redis key pattern or endpoint without adding it to docs/ in the same change.
9. Do not build ahead of the current milestone, and do not add dependencies it doesn't need. MCP is M12; do not scaffold it earlier.

## Commands

(Fill in at M1 once the scripts exist. Do not guess commands.)

## Docs

docs/README.md is the index (being created in M0). Planned docs: PROJECT_CONTEXT, STACK, ARCHITECTURE, DATABASE, API, KAFKA, REDIS, SECURITY, FAILURE_MODES, adr/, learning-journal/.
Each doc is created when its first real content exists, not as an empty stub.

## Milestone loop

Kickoff (design first, approve) → build in small steps → verify the "Done when" for real → review → teach-back (5 questions) → write docs/learning-journal/Mx.md → tag the milestone (e.g. m1-foundation).
