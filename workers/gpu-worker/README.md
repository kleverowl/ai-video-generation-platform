# workers/gpu-worker — Cloud Run GPU job

ONE image: ComfyUI + ComfyUI-LTXVideo (pinned commits), headless `worker_entrypoint.py`.
Rules: stage models from GCS to ephemeral disk (never the in-memory FS); tasks ≤45 min; checkpoint every clip to `gs://work/{job}/clips/{i}.mp4`; deterministic seeds; auto-download blocked; prompt enhancer off; writes only to GCS (no internet).
