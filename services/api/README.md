# services/api — Backend orchestrator

API, auth, validation/moderation, quotas, Postgres job state machine, **dispatcher** (write-ahead `dispatching` + idempotency key → Cloud Run `RunJob`) and **reconciler** (1–2 min cron).
Language pending: FastAPI vs Node/TS (ADR-0002). See `architecture-review/04-final-architecture.md` §4, §9.
