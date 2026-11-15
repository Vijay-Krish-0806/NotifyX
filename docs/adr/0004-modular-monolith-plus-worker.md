# ADR-0004: Modular monolith plus a worker process

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

The system does two different kinds of work:

- **Request handling:** short, latency-sensitive work. For example, `POST /v1/notifications` must return `202 Accepted` without waiting for a provider.
- **Delivery:** slow and bursty work that depends on external providers, with retries, backoff and scheduling.

Running both in one process lets slow or failing providers affect API latency, and the two cannot be scaled separately. The project is maintained by one developer, and "many microservices" is an explicit non-goal.

## Decision

The system runs as two processes built from one codebase:

- `apps/api`: a NestJS HTTP application, structured as a modular monolith (gateway module plus feature modules).
- `apps/worker`: a NestJS application with no HTTP server. It runs Kafka consumers, the outbox relay and the scheduler.

Both use the same `packages/core` and `packages/infrastructure`. Any further split into services requires an ADR with a documented, measured reason.

Until M6, delivery runs synchronously in the API. The worker boots from M1 and takes over delivery in M6.

## Alternatives considered

### Single process

- The API performs delivery in-process, for example with background jobs.
- Not chosen: provider latency and retries compete with request handling for the same process resources. A crash affects both, and delivery capacity cannot be scaled separately.

### Microservices by domain

- Separate services for templates, notifications, delivery, preferences and so on.
- Not chosen: an explicit non-goal. It adds network calls between services, distributed consistency problems and operational overhead, with no measured need.

### Serverless functions for delivery

- Delivery handlers run as cloud functions triggered by queue messages.
- Not chosen: the project runs locally on Docker Compose with no paid services, and long-lived Kafka consumer groups are a learning goal.

## Consequences

**Positive**

- Worker instances can be scaled separately, by adding consumers to a consumer group.
- Provider slowness and failures are isolated from API latency.
- Domain logic is shared, not duplicated, and lives in one repository.

**Negative**

- Two processes to configure, run, monitor and deploy.
- Both processes share one database schema, so a schema change affects both.
- Module boundaries inside the API rely on discipline and review.
- Tracing a request requires propagating a correlation ID across the process boundary (through Kafka headers).

**Follow-ups**

- M1: boot both processes; verify the NestJS standalone-application API for the chosen version.
- M6: move delivery to the worker behind the transactional outbox.
- M11: measure under load before considering any further split.

## References

- NOTIFYX_BUILD_PLAN.md §2 (non-goals), §4 (stack), §5.1 (system view), §5.2 (principles).
