# ADR-0003: PostgreSQL as the primary store

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

The system holds relational, tenant-owned data: organizations, members, API keys, end users, templates, preferences, notifications and delivery attempts. These are linked by foreign keys and need per-tenant uniqueness (for example one idempotency key per organization).

Later milestones depend on specific database capabilities:

- writing a notification and its outbox event in one transaction (M6);
- unique constraints that keep idempotency correct under concurrent requests (M5);
- row locking that lets several relay workers claim different outbox rows (M6);
- table partitioning for large, time-ordered tables (M10).

Kafka and Redis are also part of the system, so the design must state which one holds the authoritative record.

## Decision

PostgreSQL is the single source of truth for all tenant and notification data. Kafka carries events and Redis holds accelerating or transient data. Neither is ever the only record of a notification, and both can be rebuilt from PostgreSQL or tolerate data loss.

Every schema change is a migration (Prisma Migrate), with raw SQL where Prisma lacks support. Prisma's support for row locking and partitioned tables is verified before use.

## Alternatives considered

### MongoDB

- A document database, with multi-document transactions on replica sets.
- Not chosen: the data is strongly relational, with many foreign keys and composite uniqueness rules. The planned row-locking queue and declarative table partitioning are relational-database techniques, and learning them is a stated goal. MongoDB is reserved for the optional sharding experiment (M10 stretch).

### Kafka as the system of record (event sourcing)

- Store every change as an event; build current state from projections.
- Not chosen: event sourcing is an explicit non-goal. It adds projection, replay and query complexity that the product does not need.

### Redis as the primary store

- An in-memory store with optional persistence.
- Not chosen: durability depends on persistence configuration, and it lacks relational constraints and multi-row transactions of the kind the outbox needs.

## Consequences

**Positive**

- ACID transactions make the transactional outbox possible (no dual writes).
- Database constraints keep idempotency and tenant uniqueness correct even under concurrency.
- Mature tooling for indexing and query analysis (`EXPLAIN`), which M10 relies on.

**Negative**

- A single primary is the write bottleneck and a single point of failure. The local Docker Compose setup has no high availability.
- Strict migration discipline is required; applied migrations are never edited.
- Some features (row-locking queries, partitioning) may need raw SQL outside the ORM, which bypasses its type safety.

**Follow-ups**

- M2: schema, migrations and indexes that lead with `organization_id`.
- M6: ADR-0009 (outbox relay design). M10: ADR-0015 (partitioning strategy).

## References

- NOTIFYX_BUILD_PLAN.md §4 (stack), §5.2 (principles), §6 (domain model).
