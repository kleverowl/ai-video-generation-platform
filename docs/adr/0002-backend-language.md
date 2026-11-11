# ADR-0002: Backend language for services/api

| Field | Value |
|---|---|
| Status | **Proposed (undecided)** |
| Date | 2026-11-11 |
| Related | Spec §2.1, OQ-5 |

## Context

The spec allows either FastAPI (Python) or Node.js (TypeScript). The project already has these constraints:

- **Frontend:** Next.js (TypeScript).
- **Workers:** Python (ComfyUI, TTS, faster-whisper).
- **Control-plane host:** an Oracle A1 VM on **arm64**, with 12 GB RAM shared by Next.js, the API and Postgres.
- **API responsibilities:** auth, quotas, the Postgres queue and state machine, the Cloud Run Admin API client, R2 presigning, and the billing/BigQuery read.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Node/TS (Next.js route handlers or a separate service) | One language for web and API. Shared types with the frontend. pg-boss is Node-native. One runtime on a small VM. | The job-contract types must also be kept in sync with the Python workers. |
| FastAPI (Python) | Same language as the workers. Pydantic models can share the job contract directly. | Two runtimes on the VM (Node for Next.js plus Python). Queue library choice still to be made [VERIFY]. |

## Decision

_Pending._ Decide before Phase 4.

Whichever wins, `packages/job-contract` stays **JSON-Schema-first**, so both languages generate their types from it.

## Evidence

To be gathered: the team's skills, and a memory-footprint measurement on A1 (POC-style note in `docs/poc/`).
