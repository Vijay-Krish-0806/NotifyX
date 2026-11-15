# ADR-0002: Gateway as a module, not a separate service

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

The API exposes two surfaces: the public API (`/v1/*`, authenticated with API keys) and the console API (`/console/*`, authenticated with a session and JWT). Every request needs the same cross-cutting handling: authentication, tenant resolution, rate limiting, idempotency and edge validation.

Tenant isolation is a hard requirement (hard rule 4). If each feature handled these concerns itself, the code would be duplicated, and one missed check would expose another tenant's data. The plan calls for a single deployable API (a modular monolith).

## Decision

The gateway is a NestJS module inside `apps/api`. It is built from the framework's request pipeline (guards, interceptors, pipes and middleware), and it is the **only** place where authentication, tenant resolution, rate limiting, idempotency handling and edge validation happen. Feature modules receive an already-authenticated, tenant-scoped context and never read a tenant id from the client.

## Alternatives considered

### Separate gateway service

- A standalone process in front of the API that authenticates and forwards requests.
- Not chosen: it adds a network hop, a deployable, a failure point, and the need to pass identity and tenant context across a process boundary. No measured need justifies it at this scale.

### Off-the-shelf API gateway product

- A dedicated gateway with plugins for authentication and rate limiting.
- Not chosen: tenant resolution and idempotency depend on the application's own database. Building these is also an explicit learning goal, and the product would add another infrastructure component to run.

### Per-feature handling

- Each feature module performs its own authentication and tenant checks.
- Not chosen: duplicated logic, inconsistent behaviour and a high risk of a missed tenant check.

## Consequences

**Positive**

- One place to implement, test and review every security-critical check.
- In-process calls, with no extra latency or deployment.
- Two authentication strategies behind one consistent pipeline and error format.

**Negative**

- The gateway cannot be scaled or deployed separately from the API, and it shares the API's failure domain.
- "Only in the gateway" is enforced by convention, review and tests, not by a process boundary. A feature module could still bypass it by mistake.
- Gateway concerns that depend on Redis (rate limiting, idempotency fast path) make the API's behaviour depend on Redis health; this needs an explicit fail-open or fail-closed policy.

**Follow-ups**

- M3: design the tenant context (request-scoped provider or AsyncLocalStorage) and add explicit tenant-isolation tests.
- M5: the planned rate-limit algorithm ADR and the planned fail-open vs fail-closed ADR.

## References

- NOTIFYX_BUILD_PLAN.md §5.1 (system view), §5.2 (principles), §7 (API conventions, security).
