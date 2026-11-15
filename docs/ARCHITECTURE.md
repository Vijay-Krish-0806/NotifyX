# Architecture

How NotifyX is put together. Grows with each milestone. Decisions behind it are in [adr/](adr/); the target design is in [NOTIFYX_BUILD_PLAN.md](../NOTIFYX_BUILD_PLAN.md) §5.

## Process view (local development)

The apps run on the host (`pnpm dev`, from M1 step 9). The infrastructure runs in Docker Compose ([infra/docker/docker-compose.yml](../infra/docker/docker-compose.yml)), started with `pnpm infra:up`.

| Service | Role | Host address (apps on the host) | Container address (compose network) |
|---|---|---|---|
| postgres | Source of truth ([ADR-0003](adr/0003-postgres-as-primary-store.md)) | `127.0.0.1:5433` | `postgres:5432` |
| redis | Rate limits, cache, idempotency fast path, pub/sub (plan §5.4) | `127.0.0.1:6379` | `redis:6379` |
| kafka | Event transport, single node, KRaft mode | `127.0.0.1:9092` (HOST listener) | `kafka:19092` (DOCKER listener) |
| kafka-ui | Web UI for topics, partitions, consumer groups | http://127.0.0.1:8080 | `kafka-ui:8080` |
| mailpit | Local SMTP sink and web UI | SMTP `127.0.0.1:1025`, UI http://127.0.0.1:8025 | `mailpit:1025`, `mailpit:8025` |

- Every published port is bound to `127.0.0.1`, so the services are not reachable from the local network.
- Postgres uses host port **5433** because 5432 is often taken by a locally installed PostgreSQL.
- Each service has a healthcheck; `pnpm infra:up` waits until all are healthy (`docker compose up --wait`).
- Data lives in named volumes (`pgdata`, `redisdata`, `kafkadata`, `mailpitdata`), so it survives `pnpm infra:down`.

### Use 127.0.0.1, not localhost

On Windows, `localhost` resolves to the IPv6 address `::1` first, but Docker publishes the ports on IPv4 `127.0.0.1` only. Some clients fall back to IPv4 and some don't. In a measured run, the Kafka client bootstrapping via `localhost` failed 2 out of 5 times and was slow in 2 more, while `127.0.0.1` succeeded 5 out of 5 times (ADR-0005, Verification). So every host URL in `.env.example` uses `127.0.0.1`.

### Kafka listeners

A Kafka client connects in two steps. First it bootstraps: it contacts any address it was given and asks for the cluster metadata. Then it reconnects to the address the broker **advertises** for the listener it came in on. So the advertised address must be reachable from where the client runs, not from where the broker runs.

| Listener | Opens | Advertises | Used by |
|---|---|---|---|
| `DOCKER` | `:19092` | `kafka:19092` | Other containers (Kafka UI) and broker-internal traffic |
| `HOST` | `:9092` (published to `127.0.0.1:9092`) | `127.0.0.1:9092` | Apps on the host |
| `CONTROLLER` | `:29093` | not advertised | KRaft controller traffic only |

Observed but not fully understood: while the broker still advertised `localhost`, bootstrapping via `127.0.0.1` worked even though the follow-up connection should have gone to `localhost`. We do not know exactly how librdkafka selects and falls back between addresses, so the design does not rely on this. The broker advertises an address that needs no name lookup.

## Configuration

Config comes from environment variables (12-factor). The template is [.env.example](../.env.example); copy it to `.env`, which is never committed. Apps validate their variables at boot with zod and fail fast ([ADR-0006](adr/0006-validation-library.md)).

### Docker Compose

| Variable | Default | Purpose |
|---|---|---|
| `POSTGRES_USER` | `notifyx` | Postgres superuser created on first start (local only) |
| `POSTGRES_PASSWORD` | `notifyx` | Its password (local development only) |
| `POSTGRES_DB` | `notifyx` | Default database |
| `POSTGRES_HOST_PORT` | `5433` | Host port for Postgres |
| `REDIS_HOST_PORT` | `6379` | Host port for Redis |
| `KAFKA_HOST_PORT` | `9092` | Host port for Kafka; also used in the HOST advertised listener |
| `KAFKA_UI_HOST_PORT` | `8080` | Host port for Kafka UI |
| `MAILPIT_SMTP_HOST_PORT` | `1025` | Host port for Mailpit SMTP |
| `MAILPIT_UI_HOST_PORT` | `8025` | Host port for the Mailpit web UI |

Compose reads the root `.env` (`--project-directory .` in the `infra:*` scripts). Every variable has a default, so `pnpm infra:up` works without a `.env`. Credentials changed after the first start only apply to a fresh `pgdata` volume, because Postgres sets them up once.

### Apps (read from M1 step 4/6)

| Variable | Example | Read by | Purpose |
|---|---|---|---|
| `DATABASE_URL` | `postgresql://notifyx:notifyx@127.0.0.1:5433/notifyx` | API, worker | Postgres connection |
| `REDIS_URL` | `redis://127.0.0.1:6379` | API, worker | Redis connection |
| `KAFKA_BROKERS` | `127.0.0.1:9092` | API, worker | Kafka bootstrap servers (comma-separated) |

More variables (for example `NODE_ENV`, `LOG_LEVEL`, `API_PORT`) are added here in the change that introduces them.
