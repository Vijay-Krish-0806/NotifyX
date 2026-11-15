# NotifyX: project context

One-page summary for every session. The full source of truth is [NOTIFYX_BUILD_PLAN.md](../NOTIFYX_BUILD_PLAN.md); section numbers below point into it.

## What it is (§1)

A multi-tenant notification infrastructure platform, similar in scope to a small Novu or Courier. A developer signs up, creates an organization, gets an API key, defines templates and sends notifications (email, SMS, push, in-app) through a REST API. NotifyX accepts the request immediately and delivers it asynchronously, with retries, provider failover, rate limiting, preferences, scheduling, digests and live delivery tracking in a dashboard.

Goals, in priority order: (1) learn production-grade system design hands-on; (2) be genuinely usable; (3) be a strong portfolio project, where every claim is implemented and measured.

| Actor | Uses |
|---|---|
| Platform developer (tenant member) | Dashboard: API keys, templates, providers, logs, analytics |
| Customer application | Public REST API, authenticated with an API key |
| End user (recipient) | Receives notifications, sets preferences, reads the in-app inbox |

## Non-goals (§2)

Kubernetes, service mesh, many microservices, custom database, event sourcing, schema registry, ClickHouse or data lake, RAG or chatbots, autonomous agents, GraphQL, multi-region. Any of these needs an approved ADR. MCP is an optional stretch (M12) and is not scaffolded earlier.

## Architecture in brief (§5)

- **Shape:** a modular monolith (NestJS API) plus one worker process (NestJS standalone). See [ADR-0004](adr/0004-modular-monolith-plus-worker.md).
- **Request path:** client → **gateway module** (authentication, tenant resolution, rate limiting, idempotency, edge validation; [ADR-0002](adr/0002-gateway-as-module.md)) → feature modules → PostgreSQL.
- **Delivery path (from M6):** the notification and an outbox event are written in one transaction → the outbox relay publishes to Kafka → channel workers deliver through provider adapters → status events reach the dashboard through Redis pub/sub (SSE and WebSocket).
- **Data roles:** PostgreSQL is the source of truth ([ADR-0003](adr/0003-postgres-as-primary-store.md)). Kafka moves events. Redis accelerates: rate limits, cache-aside, idempotency fast path, pub/sub.
- **Code layout:** `apps/{api,worker,dashboard}` and `packages/{core,infrastructure,contracts}` ([ADR-0001](adr/0001-monorepo-layout.md)). `core` holds the domain, the state machine, use cases and ports, with no framework dependencies (hexagonal architecture).
- **Delivery guarantee:** at-least-once delivery with idempotent consumers. No dual writes; the transactional outbox is used instead.
- **Lifecycle (§5.6):** `ACCEPTED → QUEUED → PROCESSING → SENT → DELIVERED`. On failure: `PROCESSING → FAILED → RETRYING`, back to processing; or `FAILED → DEAD_LETTER` after max attempts or a non-retryable error. Only the `core` state machine changes status, and every transition is recorded with a timestamp.

## Stack (§4)

TypeScript (strict), pnpm workspaces, NestJS, Next.js (App Router), PostgreSQL with Prisma, Kafka (single broker, KRaft), Redis, Mailpit, pino, Jest, Testcontainers, k6, GitHub Actions, Docker Compose. Exact versions are verified and pinned in `STACK.md` from M1.

## Hard rules

The nine hard rules are in [CLAUDE.md](../CLAUDE.md#hard-rules). They are not repeated here, so there is one copy to maintain.

## Milestones (§8)

M0 workflow and docs → M1 foundation and infra → M2 domain and database → M3 auth, multi-tenancy, API keys → M4 synchronous MVP and dashboard → M5 gateway hardening (Redis) → M6 Kafka and outbox → M7 reliability and channel workers → M8 preferences, routing, scheduling, digests → M9 real-time and in-app inbox → M10 partitioning, indexing, analytics → M11 observability, load testing, hardening → M12 (stretch) MCP server.

The current milestone is stated in [CLAUDE.md](../CLAUDE.md#current-milestone).

## Where things are documented

See the [docs index](README.md).
