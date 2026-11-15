# Stack: pinned and verified versions

Every dependency is pinned to an exact version. A row is added in the same change that introduces the dependency, with how and when it was verified. "Latest" means the npm `latest` dist-tag on the verification date.

## Runtime and tooling

| Tool | Version | Verified | Notes |
|---|---|---|---|
| Node.js | `>=24.0.0 <25` (engines) | 2026-11-15, nodejs.org/dist/index.json: v24.22.3 is the current LTS ("Krypton") | Local machine: v24.10.0. Target ES2024: ES2023-2024 features were checked with `node -e` on v24.10.0. ES2025 features were only sampled, so not used yet. |
| pnpm | 12.21.0 (`packageManager`) | 2026-11-15, npm latest; pnpm.io/settings | pnpm reads only auth/registry/proxy/TLS settings from `.npmrc`; all other settings go in `pnpm-workspace.yaml`. Native build scripts must be allowed with `allowBuilds` (relevant for the Kafka client in step 6/7). |
| Docker / Compose | 29.6.2 / v5.3.1 | 2026-11-15, local `docker --version` | Local only; images are pinned in the compose file (M1 step 3). |

## Infrastructure images (infra/docker/docker-compose.yml)

Tags were checked on 2026-11-15 against the Docker Hub tag lists. The healthcheck tools were confirmed by running them inside each image.

| Image | Tag | Notes |
|---|---|---|
| postgres | `18.7-alpine` | 18+ images: the volume is mounted at `/var/lib/postgresql` (PGDATA is `/var/lib/postgresql/18/docker`, from the Docker Hub page). Healthcheck: `pg_isready`. |
| redis | `8.10.3-alpine` | The current stable 8.x (`latest` maps to 8.10.3). Redis 8 is offered under RSALv2, SSPLv1 or AGPLv3; local development use only. Healthcheck: `redis-cli ping`. |
| apache/kafka | `4.4.0` | Official Apache image, KRaft mode. Runs as non-root `appuser`, so data goes in `/var/lib/kafka/data`: the image default `/tmp/kraft-combined-logs` is not writable on a fresh named volume (tested). Healthcheck: `kafka-broker-api-versions.sh`. |
| ghcr.io/kafbat/kafka-ui | `v1.5.0` | Maintained fork of the original kafka-ui (provectus, last release v0.7.2 in 2024-04). Healthcheck: `/actuator/health`. |
| axllent/mailpit | `v1.33.1` | Healthcheck: `/mailpit readyz` (a subcommand built into the binary). |

## Root dev dependencies

| Package | Version | Verified | Notes |
|---|---|---|---|
| typescript | 6.0.3 | 2026-11-15 | **Pinned to 6.0.x on purpose; latest is 7.0.2.** See below. |
| eslint | 10.15.0 | 2026-11-15, npm latest | Flat config (`eslint.config.mjs`), `defineConfig` and `globalIgnores` from `eslint/config`. |
| @eslint/js | 10.0.1 | 2026-11-15, npm latest; peer `eslint ^10.0.0` | |
| typescript-eslint | 8.72.2 | 2026-11-15, npm latest; typescript-eslint.io getting-started and typed-linting | `strictTypeChecked` + `stylisticTypeChecked`, `parserOptions.projectService: true`. Typed rules are disabled for plain JS files. |
| prettier | 3.10.1 | 2026-11-15, npm latest | Markdown is excluded (`.prettierignore`) so hand-written docs keep their layout. |
| eslint-config-prettier | 10.1.8 | 2026-11-15, npm latest; README (flat import `eslint-config-prettier/flat`) | Last in the config; only turns rules off. |

## Why TypeScript 6.0.x, not 7

Checked on 2026-11-15 with `npm view <package> peerDependencies` / `dependencies`:

| Package | Supported TypeScript |
|---|---|
| typescript-eslint 8.72.2 | `>=4.8.4 <6.1.0` |
| @nestjs/cli 12.0.13 | bundles `~6.0.2` |
| ts-jest 29.4.15 | `>=4.3 <7` |

TypeScript 7.0.2 is outside all three ranges.

TypeScript 6.0 changes some compiler defaults. `strict` is now `true`, `types` is now `[]` and `rootDir` is now `.`. Each package sets these explicitly so the configs don't depend on defaults. 6.0 also deprecates `moduleResolution: node`/`node10` and `baseUrl`, which are removed in 7.0. Neither is used.

**Revisit when** `npm view typescript-eslint peerDependencies` allows TypeScript 7 (and @nestjs/cli and ts-jest do too).
