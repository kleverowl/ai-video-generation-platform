---
name: tts-pronunciation
description: Phonetic respelling of Indian names, places and words for the TTS engine, while captions keep the real spelling. Use when writing or reviewing narration scripts, the narration schema/contract, tts-worker code, caption alignment, or whenever narration contains Indian names.
---

# TTS pronunciation of Indian names

English-trained TTS engines read words phonetically, so they mispronounce Indian names. Give the engine a respelled version, but keep the real spelling everywhere a user can see it.

## Contract
Each narration line in the job contract (`packages/job-contract`, narration schema) has two fields:
- **`text`**: the correct spelling. Captions, alignment and the Whisper prompt all use it.
- **`tts`** (optional): the phonetic respelling. tts-worker sends `tts` to the engine when it is present, and `text` otherwise.

```json
{"id": "L05", "scene": "reveal",
 "text": "Shrikant Deshpande runs a shop in Nashik.",
 "tts":  "Shree-kaant Desh-paan-day runs a shop in Naa-shik."}
```

**QA check (render-worker / qa-security):** caption words come from alignment against `text`, never `tts`. Check that no respelled word leaks into the captions.

## Respelling rules
- Break the word into syllables with hyphens.
- Write the long a (as in "father") as `aa`, long i as `ee`, long u as `oo`, a final "e" sound (as in "day") as `ay`, and a short neutral a as `uh`.
- Spell the same name the same way everywhere, across all lines and all jobs. Keep a per-project glossary if one exists.
- Use Latin letters only: no Devanagari, IPA or accents.
- Respell only Indian names and words. Leave English words and English-pronounced brands or technical terms unchanged (FactoryOS, FANUC, VMC, ERP).

| Written | TTS |
|---|---|
| Deshpande | Desh-paan-day |
| Shrikant | Shree-kaant |
| Nashik | Naa-shik |
| Kulkarni | Kul-kur-nee |
| Aahan | Aa-hun |

If you are unsure how a name is pronounced, ask the user instead of guessing. Listen to every respelled line before the final render.

_Origin: rule carried over from the user's earlier VoiceStudio/OmniVoice video project._
