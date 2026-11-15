# ADR-0008: Health check design

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

The plan (§7) requires `/health/live` and `/health/ready` from M1. Its M1 section says readiness checks Postgres, Redis and Kafka, and the M1 "Done when" requires that stopping Redis makes readiness report unhealthy.

Two facts shape the design:

- **Liveness and readiness answer different questions.** Liveness: "is this process stuck and in need of a restart?" Readiness: "should this instance receive traffic right now?" If liveness checked dependencies, a short Redis outage would restart every API instance, which fixes nothing and adds load.
- **From M6 the API does not talk to Kafka on the request path.** It writes the notification and an outbox row in one Postgres transaction; the worker's outbox relay publishes to Kafka (plan §5.2, M6). The outbox exists so that requests are still accepted while Kafka is down. If the API's readiness treated Kafka as critical, a Kafka outage would take the API out of service, defeating that design.

## Decision

- **`GET /health/live`** checks no dependencies. It returns 200 whenever the process can handle a request.
- **`GET /health/ready`** checks each dependency with its own timeout, in parallel:
  - **Postgres: critical.** The source of truth; nothing works without it.
  - **Redis: critical** for now. Whether a Redis outage should fail open or closed is decided in the planned fail-open vs fail-closed ADR (M5), which may change this.
  - **Kafka: non-critical.** Its state is reported in the response body but never causes a 503.
- Readiness returns **503** if any critical dependency is down, otherwise **200**.
- Health endpoints sit outside `/v1` and `/console` and need no authentication. Responses contain only dependency names and up/down status, never connection strings, hostnames or raw error details.
- Implementation: `@nestjs/terminus` with our own probes in `packages/infrastructure`. If terminus cannot express a non-critical check cleanly (verified at M1 step 6), stop and ask before choosing a workaround.
- Timeout values are chosen at M1 step 6 and documented in API.md.
- The worker has no HTTP server in M1; it reports dependency state through logs. A worker health signal is revisited when it runs consumers (M6/M7).

## Alternatives considered

### Kafka critical for API readiness (the plan's literal M1 wording)

- Readiness returns 503 when Kafka is down.
- Not chosen: it couples API availability to Kafka, the dependency the outbox is meant to decouple.

### Readiness checks only Postgres

- Not chosen: it fails the M1 "Done when", and Redis is on the request path from M5 (rate limiting, idempotency).

### Liveness also checks dependencies

- Not chosen: dependency blips would trigger restarts that cannot help.

### Hand-written health controller

- About 50 lines without a library.
- Not chosen: terminus is the standard NestJS health module and gives a consistent response shape; the probes, which carry the real logic, are still our own.

## Consequences

**Positive**

- A Kafka outage does not take the API out of service.
- Liveness stays cheap and stable.
- Critical vs non-critical is explicit and documented, ready for the M5 decision about Redis.

**Negative**

- Before M6 the API does not use Kafka at all, so its Kafka report is informational only.
- Anyone watching only the status code will not see Kafka problems; they must read the body or, later, metrics (M11).
- Frequent readiness polling adds a small load on each dependency.

**Follow-ups**

- M1 step 6: implement, test with fake probes, demo by stopping Redis and Kafka.
- M5: fail-open vs fail-closed ADR revisits Redis.
- M6: revisit whether the API should report Kafka at all.
- M11: expose dependency health as metrics.

## References

- NOTIFYX_BUILD_PLAN.md §5.2, §7, M1, M6.
- ADR-0004 (API and worker as separate processes).
