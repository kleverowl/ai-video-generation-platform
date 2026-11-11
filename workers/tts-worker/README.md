# workers/tts-worker — Cloud Run CPU job

Narration TTS (engine called directly — NOT the VoiceStudio app, AGPL). Outputs audio + measured durations to GCS work bucket. Placement (CPU vs first GPU stage) decided by POC-6.
