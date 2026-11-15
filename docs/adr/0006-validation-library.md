# ADR-0006: Validation library

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

Untrusted data enters the system at a few edges:

- environment variables at boot (from M1);
- HTTP requests at the gateway (from M3);
- Kafka messages read by the worker (from M6);
- forms in the dashboard (from M3).

The plan (§3.3, §4) requires validated config and input validated at the edge, with one validation source of truth chosen by ADR (zod or class-validator). The dashboard is a Next.js app, so shapes shared with it must work outside NestJS.

## Decision

The system uses **zod** for all edge validation: config, HTTP DTOs and event envelopes. Static types are inferred from the schemas, so a type and its validation cannot drift apart.

- Each app validates its own env config at boot with its own schema and fails fast on error.
- Shapes shared between apps (REST DTOs, the Kafka event envelope) live in `packages/contracts`, from M2.
- Whether `packages/core` may import `packages/contracts` stays the open question in ADR-0001, to be resolved in M2.

The exact version is pinned when zod is first installed (M1 step 4) and recorded in STACK.md.

## Alternatives considered

### class-validator (with class-transformer)

- Decorator-based validation on classes; the default shown in the NestJS docs and used by Nest's built-in `ValidationPipe`.
- Not chosen: it is tied to classes and decorators, which do not fit the Next.js dashboard or plain event envelopes, and it needs two libraries.

### Joi

- Schema-based, and accepted directly by `@nestjs/config` as `validationSchema`.
- Not chosen: it does not infer TypeScript types, so types and schemas would be written twice.

## Consequences

**Positive**

- One schema language across API, worker and dashboard.
- Validated data arrives already typed.
- Works the same in Node and the browser.

**Negative**

- Nest's built-in `ValidationPipe` targets class-validator, so we write a small zod pipe at the gateway (or adopt a library through a later ADR).
- Generating OpenAPI from zod schemas (plan §7) needs extra tooling. That choice is made when the first REST DTOs appear (M3/M4).
- zod major versions have changed the API before; the version is pinned and upgrades are deliberate.

**Follow-ups**

- M1 step 4: env validation for the API, with a unit test that a missing variable fails boot.
- M2: resolve the `core` → `contracts` question.
- M3/M4: zod validation pipe and OpenAPI generation approach.

## References

- NOTIFYX_BUILD_PLAN.md §3.3, §4, §7.
- ADR-0001 (open question on `core` and `contracts`).
