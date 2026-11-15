# ADR-0007: Redis client library

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

The API connects to Redis from M1 (readiness check). Later uses are fixed by the plan (§5.4): rate limiting with an atomic Lua script (M5), cache-aside (M5), the idempotency fast path (M5) and pub/sub for real-time status (M9). The client must support Lua scripts and pub/sub, and be maintained.

Facts checked on 2026-11-15:

- redis.io: "`node-redis` is the recommended JavaScript client library for most use cases", and "For new projects, node-redis is the recommended choice."
- redis.io on ioredis: "an older library that is still supported, but lacks some of the newer features", and "Redis actively maintains and supports `ioredis` since it is in widespread use, but for new projects, we recommend using our newer Node.js client."
- The ioredis README: "maintenance is done on a best-effort basis for relevant issues."
- node-redis docs cover pub/sub and Lua scripts (`defineScript`).
- Latest versions: `redis` (node-redis) 6.3.1; `ioredis` 6.0.0.

## Decision

The system uses **node-redis** (the `redis` npm package). Access goes through our own adapters in `packages/infrastructure`. The exact version is pinned when it is first installed (M1 step 6).

## Alternatives considered

### ioredis

- Mature, widely used client with built-in Lua helpers (`defineCommand`), common in NestJS community examples.
- Not chosen: Redis recommends node-redis for new projects, and ioredis maintenance is best-effort.

## Consequences

**Positive**

- The client Redis itself recommends and maintains for new work.
- Lua scripts and pub/sub are documented, covering M5 and M9.

**Negative**

- Some NestJS community examples and libraries assume ioredis. We may need to write small adapters ourselves; the rate limiter is our own code anyway (plan M5).
- Pub/sub details (for example, whether a subscribing connection must be separate from the command connection) are verified in M9, not assumed.

**Follow-ups**

- M1 step 6: connect and `PING` with a timeout for readiness.
- M5: verify `defineScript` usage for the token-bucket Lua script.
- M9: verify the pub/sub connection model.

## References

- https://redis.io/docs/latest/develop/clients/
- https://redis.io/docs/latest/develop/clients/nodejs/
- https://redis.io/docs/latest/develop/clients/ioredis/
- https://github.com/redis/node-redis (docs/pub-sub.md, docs/programmability.md)
- NOTIFYX_BUILD_PLAN.md §5.4.
