# Workers rules (Cloud Run jobs)

- **GPU job (`gpu-worker`)**
  - It is one image, and LTX is the only GPU work it does. Only one container can hold the GPU.
  - Stage models from GCS to the **ephemeral disk**. Never use the in-memory filesystem, because it counts against RAM.
  - Verify the SHA-256 manifest before any GPU work. Fail fast on a mismatch.
  - Block ComfyUI and Hugging Face auto-downloads. Keep the LTX prompt enhancer off.
- **Task shape**
  - Keep each task to 45 minutes or less.
  - Write `gs://work/{job}/clips/{i}.mp4` plus a done-marker after **every** clip.
  - Use deterministic seeds, and skip clips that already exist.
  - Handle SIGTERM: Cloud Run gives about 10 s.
- **Exit codes** must map to the classes in `packages/job-contract`: capacity, oom, timeout, validation, internal.
- **GPU-worker storage:** the GPU worker writes to GCS only and needs no internet access. The render worker is the only component holding an R2 write token.
- **Structured JSON logs** include `job_id`, `stage_seconds`, `te_seconds`, `dit_s_per_clip`, `vae_seconds`, `peak_vram` and `peak_rss`.
- **Narration lines** carry `text` (captions) plus an optional `tts` (phonetic respelling). Follow the `/tts-pronunciation` skill.
- **LTX prompts:** follow `/ltx-2-5-prompter`. It is also the basis for the pre-dispatch prompt enhancer (OQ-8).
- **Licences:** TTS uses an engine called directly, not the VoiceStudio app (AGPL). Keep LTX watermark and provenance intact (licence item 19).
