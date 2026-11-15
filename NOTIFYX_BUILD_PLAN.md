# NotifyX: Build Plan (for Claude Code)

> Place this file at the repo root. Claude Code reads it, then proposes its own `CLAUDE.md`, rules, skills, subagents and hooks (see Section 9).
> Owner: Vijay (full-stack, Next.js + NestJS). Claude Code writes the code; Vijay reviews, questions and learns the architecture. **Understanding is the product, not just the code.**

---

## 0. How to use this document

**For Vijay:** work one milestone at a time (Section 8). Never ask for "the whole project". For every milestone follow the loop in Section 10: *design first → approve → build in small steps → verify → teach-back → write notes.*

**For Claude Code:** this is the source of truth for scope, stack, architecture and order of work. Read Sections 1-7 before any change, then the current milestone in Section 8. If something here conflicts with what you see in the code, stop and tell the user instead of guessing.

---

## 1. Product

**NotifyX** is a multi-tenant notification infrastructure platform (a small Novu / Courier / OneSignal). A developer signs up, creates an organization, gets an API key, defines templates, and sends notifications (email, SMS, push, in-app) via a REST API. NotifyX handles asynchronous delivery, retries, provider failover, rate limiting, preferences, scheduling, digests, and live delivery tracking in a dashboard.

Three goals, in priority order:
1. **Learn production-grade backend/system design hands-on** (architecture, patterns, distributed-systems basics).
2. **Be genuinely usable** by real end users (a real person can sign up, send an email to a Mailpit/real SMTP inbox, see it delivered live).
3. **Be a strong resume/interview project** for product-based companies. Every claim must be implemented *and measured*.

### Who uses it
| Actor | What they do |
|---|---|
| Platform developer (tenant member) | Uses the dashboard: API keys, templates, providers, logs, analytics |
| Customer application | Calls the public API with an API key |
| End user (recipient) | Receives notifications; sets preferences; sees the in-app inbox |

---

## 2. Non-goals (do NOT build unless an ADR approves it)

Kubernetes, service mesh, 10+ microservices, custom database, event sourcing, schema registry, ClickHouse/data lake, RAG/chatbots, autonomous agents, GraphQL, multi-region. Keep it a **modular monolith plus a worker process**. Split further only when a documented, measured reason exists.

MCP/AI integration is an **optional stretch (M12)**. Do not scaffold any MCP code earlier.

---

## 3. Working agreement for Claude Code

### 3.1 Teaching mode (the user learns from your output)
1. **Explain before building.** For every non-trivial piece: state the problem, the options considered, the choice, and the trade-off, in plain language, *before* writing code.
2. **Small steps.** One reviewable change at a time (one use-case, one adapter, one migration). Keep the project runnable after every step.
3. **Name the concept.** When you apply a pattern/principle (Strategy, Outbox, Cache-aside, DIP...) say so and say *why here*.
4. **Teach-back.** At the end of each milestone, ask the user 5 questions (Section 10) and correct gaps.
5. **Record decisions.** Any architectural choice becomes an ADR in `docs/adr/` (context, decision, alternatives, consequences).

### 3.2 Anti-hallucination rules
1. **Verify before using any library/API.** Check the installed version and current docs (official docs or a docs-lookup tool). Never write code against a remembered API. Pin versions. State the version you verified.
2. **Do not invent** tables, topics, endpoints, env vars, or config keys that are not defined in `docs/`. Add them to the relevant doc **in the same change**.
3. **Inspect before editing.** Read the existing files/modules first; follow existing conventions; do not duplicate logic.
4. **Do not build ahead** of the current milestone, and do not add dependencies that the milestone doesn't need.
5. **Run it.** After each step run typecheck, lint, tests and the relevant command (migration, docker compose, curl). Report real output. Never claim something works without running it.
6. **Say "I don't know / I couldn't verify"** rather than guessing. If requirements are ambiguous, ask.
7. **No silent architecture changes.** If a decision in this plan seems wrong, propose an ADR and wait for approval.
8. **Never fabricate benchmark numbers.** Only report measured results, with the method.

### 3.3 Production-grade defaults
Typed everything (TypeScript strict), validated input at the edge, structured logs with correlation IDs, config via validated env, no secrets in the repo, migrations for every schema change, tests for meaningful behavior, small commits with conventional messages.

---

## 4. Tech stack and decisions

| Concern | Choice | Why (and what Claude Code should explain) |
|---|---|---|
| Language | TypeScript (strict) everywhere | Shared contracts between API, worker, dashboard |
| Package manager / monorepo | pnpm workspaces (+ Turborepo optional) | Fast, simple; ask Claude Code whether Turborepo is worth it at this size |
| API | NestJS (latest stable, verify) | DI, modules, guards/interceptors map to gateway concepts |
| Worker | NestJS standalone application (no HTTP) | Same code/DI, separate process, independently scalable |
| Dashboard | Next.js App Router, Tailwind, shadcn/ui, TanStack Query, react-hook-form + zod, Recharts | Real product UI |
| Primary DB | **PostgreSQL** | Relational data, transactions, constraints, partitioning, row locking |
| ORM | Prisma (raw SQL where needed: outbox `SKIP LOCKED`, partitioning) | Verify current Prisma behavior for partitioned tables before use |
| Broker | **Kafka**, single broker, **KRaft mode** (no ZooKeeper), Kafka UI | Local, free; learn partitions/keys/consumer groups/offsets |
| Kafka client | A maintained Node client (e.g. kafkajs or Confluent's JS client: **verify maintenance status and pick one with an ADR**) | Avoid abandoned libs |
| Cache / rate limit / idempotency / pub-sub | **Redis** (Docker) | Each use has a defined role (Section 5.4) |
| Real-time | **SSE** (dashboard delivery-status stream) + **WebSocket/Socket.IO** (in-app inbox/bell) | Right protocol for the job; both fed by Redis pub/sub |
| Local email | **Mailpit** (SMTP sink + web UI) | Real SMTP flow without paid services |
| Auth | Dashboard: email+password (argon2id), short-lived JWT access + rotating refresh token in httpOnly cookie. Public API: API keys | Two auth strategies, one gateway |
| Validation | zod (shared schemas in `packages/contracts`) or class-validator: pick one via ADR | One validation source of truth |
| Logging | pino, JSON, correlation/trace IDs | Observability from day 1 |
| Testing | Jest, Supertest, **Testcontainers** (Postgres/Redis/Kafka), k6 for load | Real integration tests, not mocks only |
| CI | GitHub Actions: lint, typecheck, test, build | Basic but real |
| Infra | Docker Compose only | No paid services |
| Stretch DB | MongoDB sharded cluster (local) for a mirrored `delivery_events` collection | Learn **sharding** (distinct from partitioning) |

> Tell Claude Code to pin and record exact verified versions in `docs/STACK.md`.

---

## 5. Architecture

### 5.1 System view

```text
 Customer app ──(API key)──▶ ┐
                             │        ┌──────────────────────── NestJS API (modular monolith) ────────────────────────┐
 Dashboard (Next.js) ─(cookie/JWT)─▶ │  GATEWAY MODULE: authN, tenant resolution, rate limit, idempotency, validation │
        ▲  ▲                 │        │              │                                                                 │
        │  │ SSE / WS        │        │   Feature modules (templates, end-users, notifications, preferences, ...)       │
        │  └─────────────────┤        └──────────────┬──────────────────────────────────────────────────────────────────┘
        │                    │                       │ (same DB transaction)
        │                    │                       ▼
        │                    │              PostgreSQL  ── notifications + outbox_events (source of truth)
        │                    │                       │
        │                    │             Outbox relay (polls, publishes)
        │                    │                       ▼
        │                    │                     Kafka ──▶ routing ──▶ channel topics (email | sms | push | in-app)
        │                    │                                                 │
        │                    │                              Worker process (consumer groups per channel)
        │                    │                                                 │ provider ports/adapters
        │                    │                                                 ▼
        │                    │                              Providers (Mailpit SMTP, mock SMS/push, flaky test provider)
        │                    │                                                 │
        └────── Redis pub/sub ◀────────── delivery status events ──────────────┘
                  Redis also: rate limit, cache, idempotency fast-path
```

### 5.2 Principles
- **Postgres is the source of truth.** Kafka moves events; Redis accelerates/coordinates. Neither is ever the only record of a notification.
- **Pragmatic hexagonal architecture ("core + adapters").** Domain and use-cases do not import NestJS, Prisma, Kafka, Redis, HTTP, or provider SDKs. They depend on **ports** (interfaces). Adapters implement ports. NestJS is the composition root (DI wiring).
- **Gateway is a module inside the monolith** (ADR-0002). It is the *only* place for authentication, tenant resolution, rate limiting, idempotency handling and edge validation. Feature modules receive an already-authenticated, tenant-scoped context.
- **At-least-once delivery + idempotent consumers.** Duplicates are expected and made harmless.
- **No dual writes.** Never "write to DB and then publish to Kafka" as two independent steps. Use the **transactional outbox** (M6).

### 5.3 Repository layout

```text
notifyx/
├── apps/
│   ├── api/            NestJS HTTP: gateway module + feature modules + controllers
│   ├── worker/         NestJS standalone: Kafka consumers, outbox relay, scheduler
│   └── dashboard/      Next.js developer console
├── packages/
│   ├── core/           Domain entities, value objects, state machine, use-cases, PORTS (no framework deps)
│   ├── infrastructure/ Adapters: Prisma repos, Redis, Kafka producer/consumer, provider adapters
│   └── contracts/      Shared zod schemas/types: REST DTOs, Kafka event envelopes
├── infra/
│   └── docker/         compose files, Kafka/Redis/Mailpit config, (later) prometheus/grafana
├── docs/
│   ├── PROJECT_CONTEXT.md  ARCHITECTURE.md  DATABASE.md  API.md  KAFKA.md  REDIS.md
│   ├── SECURITY.md  FAILURE_MODES.md  STACK.md  adr/  learning-journal/
├── .github/workflows/
├── CLAUDE.md           (generated by Claude Code, see Section 9)
└── NOTIFYX_BUILD_PLAN.md
```

> If Claude Code believes this split is too heavy for the project size, it must **propose an ADR with trade-offs**, not silently flatten it. Keeping `core` framework-free is a learning goal.

### 5.4 Redis responsibilities (fixed list)
1. **Rate limiting**: atomic token bucket via Lua script.
2. **Cache-aside**: templates, preferences, provider configs.
3. **Idempotency fast-path**: Postgres unique constraint is the truth; Redis avoids hitting DB for obvious replays.
4. **Pub/Sub**: delivery-status events → SSE/WebSocket fan-out (M9).
5. **Digest buffers / scheduling help**: only in M8, only if justified.

### 5.5 Kafka design (initial; evolve via `docs/KAFKA.md`)
- **Event envelope** (versioned, validated in `packages/contracts`): `eventId, type, version, occurredAt, organizationId, traceId, payload`.
- **Topics:** `notification.requested`, `notification.email`, `notification.sms`, `notification.push`, `notification.inapp`, `notification.status` (status changes), `*.retry.<tier>`, `*.dlq`.
- **Partition key:** `organizationId:endUserId` (ordering per recipient, spreads load across tenants). Claude Code must explain why *not* just `organizationId` (hot-tenant partition) and why *not* random (no per-recipient ordering for digests).
- **Consumer groups:** one per channel worker; scale independently.
- No schema registry (non-goal); document the trade-off.

### 5.6 Notification lifecycle (state machine)

```text
ACCEPTED ─▶ QUEUED ─▶ PROCESSING ─▶ SENT ─▶ DELIVERED
                          │  ▲
                          ▼  │
                        FAILED ─▶ RETRYING
                          │
                          ▼ (max attempts / non-retryable)
                      DEAD_LETTER
```
Rules: transitions live in one domain function in `packages/core`; invalid transitions throw; every transition is recorded with a timestamp and (for failures) a reason. **Nothing else writes `status`.**

---

## 6. Domain model (initial; extend only when a milestone requires)

| Table | Key columns / notes |
|---|---|
| `organizations` | id, name, plan (free/pro: drives rate limits) |
| `members` | id, organization_id, email, password_hash (argon2id), role (owner/admin/developer) |
| `refresh_tokens` | id, member_id, token_hash, family_id, expires_at, revoked_at (rotation + reuse detection) |
| `api_keys` | id, organization_id, name, key_prefix, key_hash, environment (live/test), last_used_at, revoked_at |
| `end_users` | id, organization_id, external_id (UNIQUE per org), email, phone, locale, timezone |
| `templates` | id, organization_id, key (UNIQUE per org+channel), channel, subject, body, version, status |
| `provider_configs` | id, organization_id, channel, type, priority, encrypted_credentials, enabled |
| `preferences` | id, organization_id, end_user_id, category, channel, enabled |
| `notifications` | id, organization_id, end_user_id, template_id, event, channel, status, priority, idempotency_key (UNIQUE per org), scheduled_at, created_at |
| `delivery_attempts` | id, notification_id, provider, attempt_no, status, error_code, retryable, latency_ms, created_at |
| `outbox_events` | id, aggregate_id, type, payload, created_at, published_at (M6) |
| `inbox_messages` | id, organization_id, end_user_id, title, body, read_at, created_at (M9) |
| `audit_logs` | id, organization_id, actor, action, target, metadata, created_at |

Rules: every tenant-owned table has `organization_id` and composite indexes lead with it; every query is tenant-scoped from the authenticated context, **never from a client-supplied tenant id**; every schema change is a reviewed migration.

---

## 7. Cross-cutting standards

**API conventions**
- Two surfaces: **Public API** `/v1/*` (API key auth) and **Console API** `/console/*` (session/JWT auth). One gateway, two auth strategies.
- Consistent error format (RFC 7807-style problem JSON), stable error codes, request IDs in responses.
- Cursor (keyset) pagination for lists; never offset on large tables.
- `POST /v1/notifications` returns **202 Accepted** with the notification id; never waits for the provider.
- Rate-limit headers (`X-RateLimit-*`, `Retry-After` on 429).
- OpenAPI generated and kept in sync.

**Security (see `docs/SECURITY.md`)**
- Passwords: argon2id. API keys: high-entropy random, stored as **hash only** (constant-time compare), prefix for lookup/display, shown once. Refresh tokens: rotated, hashed at rest, reuse detection.
- Templates rendered with a **logic-less, escaping** engine (no code execution) to prevent template injection and XSS.
- Provider credentials **encrypted at rest** (envelope/app-level key from env; document key rotation).
- Tenant isolation tested explicitly (Tenant A cannot read/write Tenant B, even with guessed IDs). Optional stretch: Postgres Row-Level Security as defense in depth.
- Never log secrets, raw keys, tokens, or full PII.
- Helmet, strict CORS, input validation at the edge, audit logs for sensitive actions.

**Observability from M1:** pino JSON logs, correlation ID propagated API → outbox → Kafka headers → worker; `/health/live` and `/health/ready`.

**Testing pyramid:** unit (domain, state machine, routing, retry math) → integration with Testcontainers (Postgres/Redis/Kafka) → e2e (tenant → key → user → template → send → worker → delivered) → **failure tests** (Section 8, M7) → load tests (k6, M11).

**Git:** trunk-based with short branches, conventional commits, one milestone = a series of small PRs (even solo, so history is reviewable). Tag each milestone (`m1-foundation`...).

---

## 8. Milestones

Pacing assumes ~1-2 hrs/day of *review and learning* time (Claude Code does the typing). Estimates are guidance, not promises. Each milestone ends with something working and demoable.

| # | Milestone | Est. | Demo at the end |
|---|---|---|---|
| M0 | Workflow + docs skeleton | 1-2 d | Claude Code tooling configured |
| M1 | Foundation + infra | 3-5 d | `docker compose up` + API/dashboard/worker boot, health green |
| M2 | Domain + database | 1 wk | State machine unit-tested; migrations apply cleanly |
| M3 | Auth + multi-tenancy + API keys | 1-1.5 wk | Sign up, log in, create API key; tenant isolation tests pass |
| M4 | Synchronous notification MVP + dashboard v1 | 1.5-2 wk | Send an email via API, see it in Mailpit and in dashboard |
| M5 | Gateway hardening (Redis) | 1-1.5 wk | Rate limiting, cache, idempotency proven |
| M6 | Async with Kafka + outbox | 2 wk | API returns 202; worker delivers; crash-safe |
| M7 | Reliability + channel workers | 2 wk | Provider failure demo: retry → breaker → failover → DLQ |
| M8 | Preferences, routing, scheduling, digests | 2 wk | Scheduled + digested notifications |
| M9 | Real-time (SSE + WebSocket) + in-app inbox | 1.5 wk | Live status in dashboard; bell updates instantly |
| M10 | Data scale: partitioning, indexing, analytics (+ sharding stretch) | 1.5-2 wk | EXPLAIN before/after; analytics dashboard |
| M11 | Observability, load test, hardening, docs | 1.5-2 wk | Grafana dashboards, k6 report, final README |
| M12 | (Stretch) MCP server | optional | Agent answers "why did deliveries fail?" |

---

### M0: Workflow + docs skeleton
**Goal:** set up how you and Claude Code work together before any product code.

**Build**
1. Create the repo; commit this plan.
2. Ask Claude Code to read this file and generate `CLAUDE.md`, rules, skills, subagents, hooks (Section 9), **showing each for your approval**.
3. Create `docs/` skeleton (`PROJECT_CONTEXT.md` ≈ 1-page distilled summary, `adr/0000-template.md`, `learning-journal/`).
4. Write ADR-0001 (monorepo layout), ADR-0002 (gateway as module), ADR-0003 (Postgres primary), ADR-0004 (modular monolith + worker).

**Done when:** a fresh Claude Code session, given only the repo, can state the project's rules and the current milestone correctly.

---

### M1: Foundation + infra
**Learn:** monorepo tooling, Docker networking and healthchecks, 12-factor config, structured logging.

**Build**
1. pnpm workspace; shared tsconfig/eslint/prettier; strict TS.
2. `infra/docker/docker-compose.yml`: Postgres, Redis, Kafka (KRaft), Kafka UI, Mailpit, with healthchecks and named volumes.
3. NestJS `apps/api` (config module with env validation, pino logger with request ID, `/health/live`, `/health/ready` checking Postgres/Redis/Kafka).
4. NestJS `apps/worker` (standalone app context; boots, connects, logs).
5. Next.js `apps/dashboard` (layout shell, API client, env config).
6. `.env.example`, Makefile/scripts (`pnpm dev`, `pnpm infra:up`), GitHub Actions (lint, typecheck, test, build).

**Done when:** one command brings up infra; all three apps run; `/health/ready` reflects real dependency state (stop Redis → it reports unhealthy); CI is green.

**Teach-back:** Why KRaft over ZooKeeper? Difference between liveness and readiness? Why validate env at boot?

---

### M2: Domain + database
**Learn:** hexagonal architecture, aggregates, state machines, relational modeling, indexes, migrations.

**Build**
1. `packages/core`: entities/value objects, `NotificationStatus` state machine with transition table, domain errors, repository **ports**.
2. Prisma schema for the Section 6 tables (excluding outbox/inbox), migrations, seed script.
3. `packages/infrastructure`: Prisma repository adapters implementing the ports.
4. Composite indexes leading with `organization_id`; unique constraints (`org+external_id`, `org+idempotency_key`).
5. Unit tests for the state machine (every valid and invalid transition); integration tests for repositories with Testcontainers.

**Done when:** core has zero framework imports (enforce with a lint rule/dependency-cruiser); invalid transitions are impossible via the public API.

**Teach-back:** Why must `core` not import Prisma? What does a composite index `(organization_id, created_at)` serve? Where could the status be corrupted today?

---

### M3: Auth + multi-tenancy + API keys
**Learn:** password hashing, JWT + refresh rotation, API key design, tenant context propagation, authorization.

**Build**
1. `gateway` module skeleton: `TenantContext` (request-scoped or AsyncLocalStorage), guards for session auth and API-key auth.
2. Console auth: register (creates org + owner), login, refresh (rotation + reuse detection), logout. Argon2id.
3. API keys: generate (`nx_live_<prefix>_<secret>`, shown once), list (prefix only), revoke; lookup by prefix then constant-time hash compare; `last_used_at` update that does not slow the request path.
4. Roles/permissions guard (owner/admin/developer).
5. Dashboard: sign up/login, protected layout, API keys page.
6. Audit log entries for key creation/revocation.
7. **Tenant isolation test suite**: for every resource endpoint, Tenant A cannot access Tenant B by guessing IDs.

**Done when:** isolation tests pass; raw keys never appear in DB or logs (verify by grep + test); refresh-token reuse revokes the family.

**Teach-back:** Why hash API keys with SHA-256 but passwords with argon2id? What does refresh rotation protect against? How would a bug in one controller leak another tenant's data, and what stops it?

---

### M4: Synchronous notification MVP + dashboard v1
**Learn:** use-case design, Strategy/Adapter/Factory, template rendering safety, SOLID in practice.

**Build**
1. End users CRUD (`external_id` is the stable key; upsert endpoint).
2. Templates CRUD with versioning and a logic-less, escaping renderer; preview endpoint.
3. `NotificationProvider` **port** with `send(message): Promise<DeliveryResult>` (result distinguishes retryable vs non-retryable). Adapters: `SmtpProvider` (Mailpit), `MockSmsProvider`, `MockPushProvider`. `ProviderFactory`/registry selects by channel + tenant config.
4. Use-case `SendNotification`: resolve user → template → render → create notification (`ACCEPTED`) → send synchronously → record `delivery_attempts` → transition status. **Clearly marked as the MVP that M6 will replace.**
5. `POST /v1/notifications`, `GET /v1/notifications(/:id)` with keyset pagination and filters.
6. Dashboard v1: end users, templates (with preview), notifications table + detail timeline (status history), simple overview cards.

**Done when:** a curl with an API key sends a real email visible in Mailpit; the dashboard shows it with its timeline.

**Teach-back:** Which SOLID principle does the provider port satisfy and how would you add Provider B without editing `SendNotification`? Why is a logic-less template engine safer? What *breaks* about this design under load (preview of why Kafka)?

---

### M5: Gateway hardening (Redis)
**Learn:** token bucket vs fixed/sliding window, cache-aside and invalidation, idempotency semantics, failure policy when a dependency is down.

**Build**
1. **Rate limiting:** atomic token bucket via Redis Lua; limits per tenant (by plan) and per API key; `X-RateLimit-*` + `429 Retry-After`. ADR comparing algorithms; ADR for **fail-open vs fail-closed** when Redis is down.
2. **Caching:** cache-aside for templates, preferences, provider configs; invalidate on update; TTL jitter; protect against stampede (single-flight/lock). Measure hit rate.
3. **Idempotency:** `Idempotency-Key` header. Postgres unique `(organization_id, idempotency_key)` is the truth; Redis is a fast path; a replay returns the **original** response. Document and test the crash case: *DB committed, API died before responding, client retries.*
4. Request validation and consistent problem+json errors centralised in the gateway.
5. Dashboard: rate-limit usage meter, API key last-used.

**Done when:** a script firing 2,000 requests shows 429s with correct headers; duplicate `Idempotency-Key` never creates a second notification, including under **concurrent** duplicates; behavior with Redis stopped matches the ADR.

**Teach-back:** Why must the unique constraint exist even with Redis? Fixed window's burst problem? What goes wrong if cache invalidation is skipped on template update?

---

### M6: Async with Kafka + transactional outbox
**Learn:** why async, partitions/keys/consumer groups/offsets, delivery semantics, the dual-write problem, outbox pattern, idempotent consumers.

**Build**
1. Event envelope + zod schemas in `packages/contracts`; Kafka producer/consumer **ports** and adapters.
2. `outbox_events` table. Change `SendNotification` to: in **one DB transaction** create the notification (`QUEUED`) and insert an outbox row. Return `202`.
3. **Outbox relay** in the worker: poll unpublished rows with `FOR UPDATE SKIP LOCKED` in batches, publish to `notification.requested` (key = `organizationId:endUserId`), mark published. Multiple relay instances must not double-publish concurrently; duplicates across crashes are acceptable.
4. First consumer (single worker for now): consume, transition `PROCESSING`, send via provider port, transition `SENT`/`FAILED`. Manual offset commit **after** the DB state is written.
5. **Idempotent consumer:** reprocessing the same event must not send twice (check status/`processed_events`).
6. Propagate `traceId`/correlation ID through Kafka headers.
7. Kafka UI exercises: inspect topics, partitions, offsets, consumer lag.

**Done when:** killing the worker mid-processing and restarting results in exactly one delivery per notification as observed by the user; killing the API right after the DB commit still results in delivery; API p95 latency improved versus M4 (measure it).

**Teach-back:** What is the dual-write problem and how does the outbox solve it? Why at-least-once rather than exactly-once? What happens to ordering if you change the partition key? What does consumer lag tell you?

---

### M7: Reliability and channel workers
**Learn:** retry classification, exponential backoff with jitter, DLQ, circuit breaker states, provider failover, bulkheads.

**Build**
1. Split consumers per channel (`email`, `sms`, `push`) as independent consumer groups; routing step fans a request into channel topics.
2. **Error taxonomy:** retryable (timeout, 5xx, 429) vs non-retryable (invalid recipient, 4xx). Never retry non-retryable.
3. **Retry** with exponential backoff + jitter using tiered retry topics (Kafka has no per-message delay; Claude Code must explain how the tiers work and the trade-offs vs a DB/Redis-based delay). Max attempts configurable; record every attempt.
4. **DLQ** topic + `DEAD_LETTER` state; dashboard view and a **manual replay** action.
5. **Circuit breaker** (closed/open/half-open) per provider, implemented behind an interface with unit tests (own implementation to learn it; library only via ADR). Document that in-memory state is per worker instance and what that implies.
6. **Provider failover:** primary → fallback by tenant `provider_configs` priority and breaker state.
7. A deliberately **FlakyProvider** (configurable failure rate/latency) for demos and tests.
8. **Failure tests (required):** provider timeout, provider 500, provider 400, duplicate event, worker crash mid-send, Kafka briefly unavailable, DB transaction failure.

**Done when:** a scripted demo shows: primary fails → retries with backoff → breaker opens → fallback delivers; a poison message lands in the DLQ and can be replayed; all failure tests pass.

**Teach-back:** Why is retrying a 400 a bug? Why add jitter? What does half-open do? Why can retry topics reorder messages and does it matter here?

---

### M8: Preferences, routing, scheduling, digests
**Learn:** policy/rules engines, Chain of Responsibility, scheduling at scale, time zones, aggregation windows.

**Build**
1. **Preferences:** categories × channels per end user; API + dashboard preference center; cached (M5).
2. **Routing/policy engine:** chain of rules (preference check → quiet hours in user's time zone → channel priority → critical-override). Chain of Responsibility, each rule independently unit-tested; every skip is recorded with a reason (`SUPPRESSED_BY_PREFERENCE`...).
3. **Scheduling:** `sendAt`. Start with a DB-backed scheduler (`scheduled_at` index, batch claim with `SKIP LOCKED`, recoverable after crash, no duplicate execution). Then document and mitigate the "1M notifications at 10:00:00" burst (batching, smoothing, per-tenant fairness). A Redis sorted-set optimisation only via ADR.
4. **Digests:** collect events per (tenant, user, digest key) in a window; emit one summary notification (e.g. "You have 100 new comments"). Decide the storage (Redis buffer vs Postgres) by ADR; handle window close, restarts, and duplicates.
5. Dashboard: scheduled list, digest configuration, "why was this not sent?" view driven by the suppression reasons.

**Done when:** scheduled sends fire once even with two scheduler instances running; digest of N events produces exactly 1 notification; suppression reasons are visible.

**Teach-back:** Why is "query every second" a bad scheduler and when is it acceptable? How do you guarantee no duplicate scheduled execution? Where do time zones bite?

---

### M9: Real-time (SSE + WebSocket) and in-app inbox
**Learn:** SSE vs WebSocket trade-offs, pub/sub fan-out, connection auth, reconnection and replay, backpressure.

**Build**
1. Workers publish status-change events to Redis pub/sub (`notif:{organizationId}:events`).
2. **SSE** `GET /console/notifications/stream` (dashboard): authenticated by session cookie (explain why `EventSource` can't send custom headers), heartbeats, `Last-Event-ID` resume by replaying missed status events from Postgres.
3. **WebSocket/Socket.IO** for the **in-app inbox/bell**: end-user auth via a **tenant-signed subscriber token** (HMAC from a server-side secret, issued by the customer's backend); rooms per `organizationId:endUserId`; mark-as-read (client → server, the reason WS is used here).
4. `inbox_messages` + inbox REST endpoints; unread counts.
5. Prove **horizontal scaling**: run 2 API instances; an event published by a worker reaches clients connected to either instance.
6. Dashboard: live status timeline without refresh; embeddable `<NotifyXBell />` demo widget (small standalone page/component simulating a customer's app).

**Done when:** sending a notification updates the dashboard live and pops the bell in a second browser; works across two API instances; reconnect after a dropped connection replays missed events.

**Teach-back:** Why SSE for status and WS for the bell? What does Redis pub/sub **not** guarantee (delivery on subscriber downtime) and how does the replay design compensate? How do you stop a malicious user subscribing to another tenant's room?

---

### M10: Data scale: partitioning, indexing, analytics (+ sharding stretch)
**Learn:** query plans, keyset pagination, declarative partitioning, partition pruning, retention, rollups, and the difference between **partitioning** (one DB, many tables) and **sharding** (many DBs).

**Build**
1. Generate realistic volume (seed script: millions of `notifications`/`delivery_attempts`).
2. Capture `EXPLAIN (ANALYZE, BUFFERS)` for the main list/filter/analytics queries; fix with indexes; record before/after in `docs/DATABASE.md`.
3. **Partition** `notifications` and `delivery_attempts` by **range on `created_at` (monthly)**, keeping composite indexes led by `organization_id`. Note and handle: primary/unique keys on partitioned tables must include the partition key, which affects the idempotency unique constraint design: Claude Code must explain this and propose the solution via ADR. Automate creation of future partitions and a retention/detach strategy. **Verify what Prisma can and cannot do with partitioned tables; use raw SQL migrations where needed.**
4. **Analytics:** pre-aggregated hourly/daily rollup table maintained by a worker; dashboard charts (volume, delivery rate, latency percentiles, per-provider health).
5. **Stretch: sharding.** Local MongoDB sharded cluster (config servers, shard replica sets, `mongos`) holding a **mirrored, append-only `delivery_events`** collection fed from Kafka; choose and justify a shard key (e.g. hashed `organizationId` or compound with time), demonstrate chunk distribution and a targeted vs scatter-gather query. It is **not** a second source of truth. If dropped, record that in an ADR.
6. Stretch: Postgres Row-Level Security as tenant isolation defense in depth.

**Done when:** documented before/after query plans show partition pruning working; analytics page loads fast on the large dataset; you can explain partitioning vs sharding using your own cluster as the example.

**Teach-back:** What is partition pruning and when does it fail? Why monthly range partitions for this data? What is a hot shard and how does your shard key avoid it?

---

### M11: Observability, load testing, hardening, docs
**Build**
1. **Metrics** (Prometheus format): HTTP rate/latency, notifications by status, Kafka consumer lag, provider latency/error rate, breaker state, Redis hit rate, outbox backlog, DLQ size. Grafana dashboards provisioned as code.
2. **Tracing** with OpenTelemetry: one trace spanning API → outbox → Kafka → worker → provider (context in Kafka headers).
3. **Load tests (k6):** define scenarios and SLOs first (e.g. target RPS, p95), then measure: sync vs async comparison, effect of cache, effect of partitioning, behavior at rate limit. Report only measured numbers with the machine and method.
4. **Hardening review:** security checklist pass (Section 7), dependency audit, graceful shutdown (drain consumers, finish in-flight), config for timeouts everywhere, backpressure.
5. **Docs for interviews:** `ARCHITECTURE.md` with diagrams, trade-offs and alternatives; `FAILURE_MODES.md` (what breaks, how it's detected, how it recovers); `SCALING.md` (what you'd do at 10× and 100×); README with demo GIF, quickstart, API examples.
6. **Final demos (scripted):** normal delivery; provider failure → failover; duplicate request; tenant isolation; worker crash; live dashboard.

**Done when:** a stranger can clone, run one command, follow the README, and reproduce every demo; the resume claims in Section 12 are each backed by something in the repo.

---

### M12 (stretch): MCP server
Only after M1-M11 are complete. A thin MCP adapter over the **same use-cases** (no duplicated business logic) exposing read-only operational tools first (`get_notification_analytics`, `list_failed_deliveries`, `get_delivery_status`, `get_provider_health`), with scoped authentication, tool-level permissions, audit logging, and human approval for any mutating tool. Write `docs/MCP.md` and an ADR before building.

---

## 9. Claude Code tooling to generate (ask Claude Code to propose, then approve each)

Ask Claude Code to read this file and propose the following. Have it **verify current Claude Code conventions in the official docs** (memory files, rules, skills, subagents, hooks, slash commands) before creating anything.

**`CLAUDE.md` (keep short, under ~150 lines):** project summary, the non-goals, current milestone pointer, the anti-hallucination and teaching-mode rules from Section 3, commands (dev, test, migrate, infra), and pointers to `docs/`. Details live in `docs/`, not in `CLAUDE.md`.

**Rules (scoped by path if supported):**
- `core` purity: no framework/infra imports in `packages/core`.
- Tenant safety: every query tenant-scoped; no tenant id from the client.
- Migrations: every schema change via migration; never edit applied migrations.
- Kafka: new topics/keys documented in `docs/KAFKA.md` in the same change.
- Security: never log secrets; hash-only API keys.

**Skills (suggested):** `adr-writer`, `add-nestjs-module`, `add-prisma-migration`, `add-kafka-topic`, `add-provider-adapter`, `milestone-kickoff` (design-first checklist), `milestone-teachback` (generates the 5 questions + journal entry), `failure-test-writer`.

**Subagents (suggested):**
- `architecture-reviewer`: checks changes against Sections 5-7 and flags violations (read-only).
- `security-reviewer`: tenant isolation, secret handling, auth flows (read-only).
- `test-engineer`: writes/extends tests incl. Testcontainers and failure tests.
- `docs-keeper`: ensures docs match code.

**Hooks (suggested):** run typecheck/lint on edited files; block committing `.env`/secrets; remind to update docs when schema/topics change.

**MCP/doc lookup:** a docs-lookup tool for current library documentation, to enforce the "verify before using" rule.

---

## 10. Milestone workflow loop and prompt templates

**The loop (every milestone):**
1. **Kickoff (plan mode):** Claude Code reads the milestone, explains the concepts, lists options and trade-offs, proposes a step list and the ADRs needed. *You approve or challenge.*
2. **Build in small steps:** each step is a reviewable commit with tests; Claude Code explains what it did and why.
3. **Verify:** run everything; demo the "Done when" criteria.
4. **Review:** invoke `architecture-reviewer` and `security-reviewer`.
5. **Teach-back:** Claude Code asks you 5 questions (concept, "why this not that", failure scenario, scaling scenario, "how would you explain this in an interview"). Answer in your own words; it corrects gaps.
6. **Journal:** `docs/learning-journal/Mx.md`: what changed, why, what failed, what I learned, open questions. Tag the milestone.

**Prompt: start a milestone**
> Read `NOTIFYX_BUILD_PLAN.md` Sections 1-7 and milestone M{n}. Enter plan mode. Explain the concepts I need, the design options with trade-offs, your recommended approach, the ADRs required, and a step-by-step implementation list with a test for each step. Do not write code yet. Flag anything in the plan you think is wrong or ambiguous.

**Prompt: build a step**
> Implement step {k} only. First read the existing code. Verify any library API against current docs and tell me the version. Write the code and tests, run typecheck/lint/tests, show real output, and explain the design decisions and patterns used. Update docs in this same change.

**Prompt: explain what you built**
> Explain this module as if I must defend it in a system design interview: the problem, the alternatives you rejected, failure modes, how it scales, and what I'd change at 100× load.

**Prompt: break it on purpose**
> Give me a chaos exercise for this milestone (kill Redis / kill the worker / slow the provider / duplicate the message). Predict what should happen, run it, and compare with what actually happened.

**Prompt: teach-back**
> Quiz me with 5 questions on this milestone. Wait for my answers one at a time, then grade and correct.

---

## 11. Global Definition of Done (every milestone)

- [ ] Typecheck, lint, unit and integration tests pass locally and in CI
- [ ] The "Done when" demo for the milestone has been run for real
- [ ] New config/topics/tables/endpoints are documented in `docs/`
- [ ] ADRs written for each significant decision
- [ ] No secrets in repo/logs; tenant isolation tests still pass
- [ ] Teach-back completed; journal entry written; milestone tagged
- [ ] The project still starts with one command

---

## 12. Resume framing (use only what is implemented and measured)

> Designed and built a multi-tenant, event-driven notification platform (NestJS, PostgreSQL, Kafka, Redis, Next.js): transactional-outbox publishing, idempotent consumers, retry with backoff/DLQ, circuit-breaker provider failover, per-tenant Redis rate limiting, idempotency keys, SSE/WebSocket live delivery tracking, and Postgres partitioning. Load-tested with k6: **{measured result}**.

Interview stories this project gives you: the dual-write problem and outbox; at-least-once vs exactly-once; idempotency under concurrency; partition-key choice and hot partitions; cache invalidation; fail-open vs fail-closed; SSE vs WebSocket; partitioning vs sharding; tenant isolation.

---

## Appendix A: Patterns and principles map

| Pattern / principle | Where it appears | Milestone |
|---|---|---|
| Hexagonal (ports & adapters), DIP | `core` ports, infra adapters | M2+ |
| Repository | Prisma repositories behind ports | M2 |
| State machine | Notification lifecycle | M2 |
| Strategy + Adapter + Factory | Providers, channel selection | M4 |
| Template method / Builder | Message/payload construction | M4 |
| Cache-aside | Templates, preferences | M5 |
| Token bucket | Rate limiter | M5 |
| Idempotent receiver | API + consumers | M5, M6 |
| Transactional outbox | Reliable publishing | M6 |
| Competing consumers / consumer groups | Channel workers | M6, M7 |
| Retry + backoff + jitter, DLQ | Failure handling | M7 |
| Circuit breaker, Bulkhead | Providers | M7 |
| Chain of Responsibility | Routing/policy engine | M8 |
| Observer / Pub-Sub | Status events → real-time | M9 |
| Partitioning, (stretch) Sharding | Data layer | M10 |

## Appendix B: ADRs to write (minimum)

0001 monorepo layout · 0002 gateway as module · 0003 Postgres primary · 0004 modular monolith + worker · 0005 Kafka client library · 0006 validation library · 0007 rate-limit algorithm · 0008 fail-open vs fail-closed · 0009 outbox relay design · 0010 partition key · 0011 retry mechanism · 0012 scheduler design · 0013 digest storage · 0014 real-time transports · 0015 table partitioning strategy · (stretch) 0016 sharding experiment · 0017 MCP.
