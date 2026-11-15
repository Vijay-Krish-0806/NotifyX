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

## Verification (spike, 2026-11-15)

A throwaway spike, outside the repo and since deleted, installed `@confluentinc/kafka-javascript@1.11.0` with pnpm 12.21.0 and connected to the local broker. Results:

- **pnpm blocks the native build by default.** Without permission, `pnpm add` fails with `ERR_PNPM_IGNORED_BUILDS` (exit 1). The package's install script (`node-pre-gyp install --fallback-to-build`) never runs, so `require` fails with "Could not locate the bindings file".
- **Fix: allow only this package.** Add `allowBuilds: { '@confluentinc/kafka-javascript': true }` in `pnpm-workspace.yaml` (pnpm.io/settings). Do not use `dangerouslyAllowAllBuilds`. Other packages' build scripts stay blocked.
- **The install needs access to github.com.** The install script downloads the prebuilt binary from the project's GitHub releases. Nothing was compiled. CI and any fresh install need network access to github.com.
- **Windows x64 (host, Node 24.10.0):** downloaded `node-v137-win32-unknown-x64`; `require` loads librdkafka 2.16.0.
- **Linux x64 (`node:24.22.3-bookworm-slim`, glibc 2.36):** downloaded `node-v137-linux-glibc-x64` in 2.9 s; `require` loads librdkafka 2.16.0. Each step was run as a separate command in the container (not an attached interactive terminal).
- **Connections:**
  - From the host to `127.0.0.1:9092` (the HOST listener): an admin `listTopics` succeeded 5 out of 5 times, in 169-194 ms.
  - From a container on the compose network to `kafka:19092` (the DOCKER listener): succeeded in 158 ms.
- **`localhost` is unreliable on Windows.**
  - `localhost` resolves to `::1` first, but Docker publishes the port on `127.0.0.1` only.
  - With the broker advertising `localhost`, the client failed. After switching the advertised address to `127.0.0.1`, bootstrapping via `localhost` still succeeded only 3 out of 5 times: two runs took about 2.3 s, and two failed with "Broker transport failure".
  - Decision: the HOST listener advertises `127.0.0.1`, and every host URL uses `127.0.0.1` (see ARCHITECTURE.md).
- **Not fully understood:** while the broker still advertised `localhost`, bootstrapping via `127.0.0.1` succeeded even though the follow-up connection should have used `localhost`. We don't know librdkafka's exact address-selection and fallback behavior. The design does not rely on it.
- **License: MIT.** Checked 2026-11-15 in the npm metadata for 1.11.0, `LICENSE.txt` at tag `v1.11.0`, and GitHub's license detection. The bundled librdkafka and its dependencies carry their own licenses, which were not reviewed here.

This verification does not change the decision.

## References

- https://github.com/confluentinc/confluent-kafka-javascript (README, INTRODUCTION.md)
- https://github.com/tulios/kafkajs
- NOTIFYX_BUILD_PLAN.md §4, §5.5, M6.
