# ADR-0005: Kafka client library

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

The worker connects to Kafka from M1, and the readiness endpoint reports Kafka's state. From M6 the system depends on the client for producing (outbox relay), consumer groups, manual offset commits after the database write, message headers (trace ID) and admin operations (topics, metadata). The plan (§4) asks for a maintained client chosen by ADR.

Facts checked on 2026-11-15:

- **kafkajs:** latest npm release 2.2.4, published 2023-02-27. Last commit 2024-05-16; 418 open issues. Not archived and not marked deprecated; the README says it is "maintained by a small group of dedicated volunteers".
- **@confluentinc/kafka-javascript:** latest release 1.11.0, published 2026-10-07; repository updated 2026-11-13. The README says "**Supported** - Commercial support is offered by Confluent", that it is "a lightweight wrapper around librdkafka", and that it is "also API compatible with KafkaJS". It has an admin client.
- Confluent prebuilt binaries are listed for Linux x64/arm64 (glibc and musl), macOS arm64 and Windows x64. A Windows x64 binary for Node 24 (`node-v137`) exists in the 1.11.0 release. The README lists Node 18 to 24.
- The Confluent README also says: "Yarn and pnpm support is experimental." This project uses pnpm.

## Decision

The system uses `@confluentinc/kafka-javascript` through its KafkaJS-compatible (promise-based) API, `require('@confluentinc/kafka-javascript').KafkaJS`. All Kafka access goes through our own adapters in `packages/infrastructure` (behind ports from M6), so no other code imports the client directly.

## Alternatives considered

### kafkajs

- Pure JavaScript client with a friendly API; no native build.
- Not chosen: no release since 2023-02 and no commits since 2024-05. This project runs for many months and will rely on consumer-group behaviour and newer broker versions; an inactive client is a risk we would carry to the end.

### Other Node.js Kafka clients

- Not evaluated in this ADR. If the Confluent client fails in our setup (see Follow-ups), alternatives are evaluated then, in a new ADR.

## Consequences

**Positive**

- Actively maintained, with vendor support, on top of librdkafka, the C library most production Kafka clients are built on.
- The KafkaJS-style API keeps code and examples readable.
- The adapter boundary means a client change touches one package.

**Negative**

- It is a native add-on. Installation depends on a prebuilt binary that matches the platform and Node ABI; a new Node major can break installs until binaries ship. Node 25+ is not listed yet.
- pnpm support is described as experimental by the vendor. pnpm also blocks native build scripts unless the package is listed in `allowBuilds`.
- Errors and configuration come from librdkafka and do not always match KafkaJS semantics (the repository has a migration guide).

**Follow-ups**

- M1 step 6/7: install with pnpm, add the `allowBuilds` entry, and confirm it connects on Windows.
- M1 step 9: confirm the Linux prebuilt binary installs in CI.
- If either install fails, stop and revisit this decision with a new ADR.
- M6: verify the consumer API for manual offset commit and headers before building on it.

## References

- https://github.com/confluentinc/confluent-kafka-javascript (README, INTRODUCTION.md)
- https://github.com/tulios/kafkajs
- NOTIFYX_BUILD_PLAN.md §4, §5.5, M6.
