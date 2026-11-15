# ADR-0001: Monorepo layout with pnpm workspaces

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

NotifyX has three runnable applications: an HTTP API, a background worker and a web dashboard. The API and the worker share domain logic (entities, the notification state machine, use cases). All three share contracts: REST request and response shapes, and the Kafka event envelope.

A core requirement is that the domain layer stays free of frameworks and infrastructure (hard rule 2), so that business rules can be tested and reasoned about in isolation. The project is maintained by one developer, so tooling overhead must stay low.

## Decision

The system uses a single git repository with pnpm workspaces, laid out as:

- `apps/api`, `apps/worker`, `apps/dashboard`: deployable applications.
- `packages/core`: domain, state machine, use cases and ports. No framework, ORM, broker, cache, HTTP or provider SDK dependencies.
- `packages/infrastructure`: adapters that implement the ports (database, Kafka, Redis, providers).
- `packages/contracts`: shared schemas and types for REST DTOs and event envelopes.

Dependencies point inward. In the list below, `A → B` means "A depends on (imports from) B":

- `apps/*` → `packages/infrastructure`, `packages/core`, `packages/contracts`
- `packages/infrastructure` → `packages/core`, `packages/contracts`
- `packages/core` → no other workspace package (see Open questions)

## Open questions

- **May `packages/core` import `packages/contracts`?** Contracts hold shared schemas (for example zod). Allowing the import avoids duplicating types; forbidding it keeps the domain free of the validation library. To be resolved in M2, recorded in a new ADR, and enforced by the dependency rule.

## Alternatives considered

### Single application with folders

- One NestJS project with `domain/`, `infrastructure/` and similar folders.
- Not chosen: the core boundary would exist only by convention. A separate package makes every dependency of `core` visible in its own `package.json`, and the dashboard is a separate Next.js app in any case.

### Multiple repositories (polyrepo)

- One repository per app, with shared packages published and versioned.
- Not chosen: changing a contract would need coordinated releases across repositories. That is heavy for one developer, and cross-cutting changes could no longer land in a single commit.

### Task-runner-centred monorepo (Nx or Turborepo)

- A monorepo managed mainly by a build orchestration tool.
- Not chosen yet: at this size the benefit (cached and parallel tasks) is unmeasured. Turborepo can be added on top of pnpm workspaces later; that decision is deferred to M1.

## Consequences

**Positive**

- The `core` purity rule is enforced by package boundaries, not just by review.
- Contracts are typed end to end between API, worker and dashboard.
- A change touching the API, the worker and a contract lands as one reviewable commit.

**Negative**

- More configuration: the workspace file, shared and per-package TypeScript configs, and build order between packages.
- NestJS and Next.js tooling inside a pnpm workspace may need extra setup. This is not yet verified for the versions to be used.
- A package boundary alone does not stop a forbidden import of an installed library; a lint rule is still required.

**Follow-ups**

- M1: set up the workspace; decide on Turborepo from measured task times; record versions in `STACK.md`.
- M2: enforce "no framework imports in `core`" with a lint or dependency rule; resolve the open question above.

## References

- NOTIFYX_BUILD_PLAN.md §4 (stack), §5.2 (principles), §5.3 (repository layout).
