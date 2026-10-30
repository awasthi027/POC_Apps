# Event Service

Receives events from the analytics SDK, queues them in Kafka, stores them in Postgres, and shows a chart page.

```
SDK ──POST /v1/analytics/events──▶ IngestController ──▶ Kafka (analytics.events) ──▶ EventConsumer ──▶ Postgres
                                         │                                                              │
                                  200 + accepted ids                                       StatsController ◀── chart page (/)
```

## Run with Podman (or Docker)

Postgres listens on **5433** on your Mac (not 5432), so it cannot clash with a Postgres you installed yourself.
If you see `FATAL: role "analytics" does not exist`, the service reached a *different* Postgres. Check with `lsof -i :5432 -i :5433`.

**Option A: Postgres + Kafka in a pod, service from Maven**
```bash
podman kube play podman/pod.yaml
mvn spring-boot:run
./scripts/send-sample-events.sh      # optional: 200 demo events
```

**Option B: everything in one pod**
```bash
podman build -t event-service -f podman/Containerfile .
podman kube play podman/pod-full.yaml
```

Stop with `podman kube down podman/pod.yaml` (or `pod-full.yaml`). Data stays in the volume `analytics-pgdata`;
add `--force` to `kube down` to delete it too.
`docker compose up -d` also works (`docker-compose.yml`, or `podman compose up -d`).

Open **http://localhost:8080/** for the chart page. Point the SDK at `http://localhost:8080/v1/analytics/events`.
Settings are in `src/main/resources/application.yml`; the main ones can be set with environment variables:
`DB_URL`, `DB_USER`, `DB_PASSWORD`, `KAFKA_BOOTSTRAP`, `INGEST_TOKEN` (if set, the SDK must send `Authorization: Bearer <token>`).

## How it works

1. **Ingest** (`ingest/`): checks each event, writes the good ones to Kafka, and waits until Kafka confirms (`acks=all`).
   Only then does it answer `200` with `accepted_event_ids`. Bad events are listed in `rejected_events` with `retryable: false`.
   If Kafka does not confirm, it answers `503` and the SDK retries later.
2. **Consumer** (`kafka/EventConsumer`): reads batches and inserts them into Postgres.
   `INSERT ... ON CONFLICT (project_id, event_id) DO NOTHING` means the same event can arrive twice (SDK retry, Kafka redelivery) and is stored once.
   Offsets are committed only after the insert. If Postgres is down, the consumer retries every 2 seconds and loses nothing.
   Messages that cannot be read, or that Postgres refuses, go to the topic `analytics.events.dlt`.
3. **Chart page** (`static/index.html` + `stats/`): events over time, top events, totals, latest events. Refreshes every 15 seconds.

## API

| Endpoint | Purpose |
|---|---|
| `POST /v1/analytics/events` | SDK upload (see ../AnalyticsSDK/docs/BACKEND_CONTRACT.md) |
| `GET /api/projects` | projects that have events |
| `GET /api/stats/summary?project=&from=&to=` | totals |
| `GET /api/stats/timeseries?project=&from=&to=&bucket=minute\|hour\|day&event=` | counts per bucket |
| `GET /api/stats/top-events?project=&from=&to=&limit=` | most frequent events |
| `GET /api/events/recent?project=&limit=` | newest events |
| `GET /actuator/health` | health check |

`from` and `to` are ISO times such as `2026-10-30T10:00:00Z`.
The service accepts the field names of both SDKs (`event_id`/`id`, `event_name`/`name`, `timestamp`/`time`, ...).

## Limits (kept simple on purpose)
- No authentication on the chart page and `/api`. Put it behind your login before using real data.
- `accepted_event_ids` means "safely in Kafka"; duplicates are removed later, so `duplicate_event_ids` is always empty.
- One Postgres table with no partitioning or retention job. Add partitioning by `event_time` and a cleanup when data grows.
- Single-node Kafka and Postgres in `docker-compose.yml` are for development only.
- Not tested here: no automated tests were written, as requested.
