# Services rules (API, dispatcher, reconciler)

- **Job state:** jobs follow the state machine in 04 §4.2. Postgres is the source of truth. Worker callbacks are hints only.
- **Dispatching:** write the `dispatching` state and an idempotency key **before** calling `RunJob`. Label every execution with `job_id`.
- **Reconciler:** runs every 1–2 minutes. It cancels orphan executions, fails jobs stuck past their timeout, and dispatches the render step once all clip markers exist.
- **Before any GPU spend**, in this order: moderation and validation, then quota checks, then the user approval gate.
- **Retries**
  - Capacity errors: retry with backoff, then move along the fallback chain.
  - OOM and validation errors: never retry.
- **Credentials:** the dispatcher service account has only `run.jobs.runWithOverrides` and `run.executions.get/list/cancel` on the named jobs.
- **Presigned R2 URLs:** valid for 15–60 minutes, issued only after an ownership check, and served from the S3 endpoint (not a custom domain).
- **Costs:** the dashboard shows two figures, a *live estimate* (seconds × verified rates) and a *reconciled actual* (BigQuery export, which lags). Never call the estimate the actual bill. See OQ-4.
