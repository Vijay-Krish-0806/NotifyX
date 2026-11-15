# NotifyX docs index

A doc is created when its first real content exists, not as an empty stub. Every new table, Kafka topic, Redis key pattern, endpoint or env var is documented in the same change that introduces it.

## Documents

| Doc | Purpose | Status |
|---|---|---|
| [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) | One-page summary of scope, architecture and milestones | Done (M0) |
| [adr/](adr/) | Architecture Decision Records | Started (M0) |
| [learning-journal/](learning-journal/) | One entry per milestone: what changed, why, what was learned | Started ([M0](learning-journal/M0.md)) |
| STACK.md | Exact verified and pinned versions | Expected in M1 |
| ARCHITECTURE.md | Modules, ports and adapters, process view | Expected in M1 |
| API.md | Endpoints, error format, auth, pagination | Expected in M1 (health endpoints) |
| FAILURE_MODES.md | What breaks, how the system reacts, how it is tested | Expected in M1 (readiness), grows in M7 |
| DATABASE.md | Tables, indexes, constraints, migrations | Expected in M2 |
| SECURITY.md | Auth, API keys, secrets, tenant isolation | Expected in M3 |
| REDIS.md | Key patterns, TTLs, roles | Expected in M5 |
| KAFKA.md | Topics, partition keys, consumer groups, event envelope | Expected in M6 |

"Expected" milestones are a guide; the real trigger is the first change that needs the doc.

## ADRs

| # | Title | Status |
|---|---|---|
| [0000](adr/0000-template.md) | Template | n/a |
| [0001](adr/0001-monorepo-layout.md) | Monorepo layout with pnpm workspaces | Accepted |
| [0002](adr/0002-gateway-as-module.md) | Gateway as a module, not a separate service | Accepted |
| [0003](adr/0003-postgres-as-primary-store.md) | PostgreSQL as the primary store | Accepted |
| [0004](adr/0004-modular-monolith-plus-worker.md) | Modular monolith plus a worker process | Accepted |
