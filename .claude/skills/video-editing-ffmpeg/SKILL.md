---
name: video-editing-ffmpeg
description: FFmpeg video editing and assembly recipes for this platform. Covers concatenating generated clips, trimming, 9:16 and 16:9 reframing, burned-in ASS captions, music ducking under narration, two-pass loudness normalisation, crossfades, thumbnails, and automated QA (ffprobe, ebur128, blackdetect, freezedetect). Use when editing, assembling, fixing or QA-checking videos, in the render-worker, or on the production server.
---

# Video editing with FFmpeg

These recipes match the render-worker design (04 §8): FFmpeg only, no Remotion in the MVP.

**Always** build commands as argument arrays (`subprocess.run([...])`). Never interpolate user text into a shell string. Caption text goes into an `.ass` **file**, never into the filter string.

## 1. Inspect first
```bash
ffprobe -v error -show_entries stream=codec_name,width,height,r_frame_rate,pix_fmt,sample_rate,channels \
        -show_entries format=duration -of json in.mp4
```
Concat with `-c copy` works only when every clip has an identical codec, resolution, fps, pix_fmt and audio layout. Otherwise re-encode (§2b).

## 2. Join clips
**a. Identical clips: stream copy (fast, lossless)**
```bash
# list.txt lines:  file 'clips/0001.mp4'
ffmpeg -f concat -safe 0 -i list.txt -c copy joined.mp4
```
**b. Mixed clips: normalise while joining**
```bash
ffmpeg -i a.mp4 -i b.mp4 -filter_complex \
 "[0:v]scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,format=yuv420p[v0]; \
  [1:v]scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,format=yuv420p[v1]; \
  [v0][v1]concat=n=2:v=1:a=0[v]" -map "[v]" -c:v libx264 -crf 18 -preset medium joined.mp4
```
**c. Crossfade between two clips** (`offset` = clip A duration − fade duration)
```bash
ffmpeg -i a.mp4 -i b.mp4 -filter_complex "[0:v][1:v]xfade=transition=fade:duration=0.5:offset=4.5,format=yuv420p[v]" -map "[v]" out.mp4
```

## 3. Trim and reframe
- **Frame-accurate trim** (re-encodes): `ffmpeg -i in.mp4 -ss 2.0 -to 7.5 -c:v libx264 -crf 18 -c:a aac out.mp4`
- **Presets:**
  - Reels/Shorts: 1080×1920 (9:16)
  - YouTube: 1920×1080 (16:9)

  Fit with `scale=…:force_original_aspect_ratio=decrease,pad=…`. Or fill with `scale=…:force_original_aspect_ratio=increase,crop=W:H`.

## 4. Captions (burned in)
- Generate `captions.ass` from the alignment JSON. Use the **`text`** field, never `tts` (see `/tts-pronunciation`).
- Style it in the `.ass` `[V4+ Styles]` section: font, size, outline, `MarginV` for the safe area.
- Burn it in: `ffmpeg -i in.mp4 -vf "subtitles=captions.ass" -c:a copy out.mp4`.
- **Escaping:** in filter strings, the path must escape `:` `,` `[` `]` `'` and `\`. Prefer a simple relative path in the working directory.
- **Safe area for 9:16:** keep captions above the bottom ~20% and away from the right edge, where UI buttons sit.

## 5. Audio: narration, music ducking, loudness
**Duck music under narration** (sidechain):
```bash
ffmpeg -i video.mp4 -i narration.wav -i music.mp3 -filter_complex \
 "[2:a]volume=0.35[m];[m][1:a]sidechaincompress=threshold=0.05:ratio=8:attack=20:release=300[duck]; \
  [duck][1:a]amix=inputs=2:duration=first:normalize=0[a]" \
 -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 192k mixed.mp4
```
**Two-pass loudnorm** (always two passes for files; one pass is for live streams only):
```bash
# pass 1: measure
ffmpeg -i mixed.mp4 -af loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json -f null - 2> pass1.log
# pass 2: apply the measured_* values parsed from the JSON in pass1.log
ffmpeg -i mixed.mp4 -af "loudnorm=I=-14:TP=-1.5:LRA=11:measured_I=<..>:measured_TP=<..>:measured_LRA=<..>:measured_thresh=<..>:offset=<..>:linear=true" \
       -c:v copy -c:a aac -b:a 192k -ar 48000 final.mp4
```
Targets (`I`) are per-platform config values. Verify each platform's current loudness reference before changing the default; don't hard-code a number from memory.

## 6. Delivery encode
```bash
ffmpeg -i final.mp4 -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 18 -preset slow \
       -c:a aac -b:a 192k -ar 48000 -movflags +faststart delivery.mp4
```
- **Thumbnail:** `ffmpeg -ss 3 -i delivery.mp4 -frames:v 1 -q:v 2 thumb.jpg`
- **Preview GIF/WebP:** use `fps=10,scale=480:-1`.

## 7. Automated QA (render-worker, before uploading to R2)
| Check | Command | Fail if |
|---|---|---|
| Duration and resolution | ffprobe (§1) | duration differs from the plan by more than one frame, or the resolution is not the preset |
| Loudness | `ffmpeg -i delivery.mp4 -af ebur128=peak=true -f null -` | integrated loudness is outside target ±1 LU, or true peak > −1 dBTP |
| Black frames | `-vf blackdetect=d=0.5:pix_th=0.10` | any black segment that wasn't planned |
| Frozen frames | `-vf freezedetect=n=0.003:d=2` | a freeze longer than 2 s that wasn't planned |
| A/V sync | compare alignment timestamps against the audio onset | offset > 200 ms |

## Rules
- Measured numbers (render seconds, peak RAM) go through `/poc-record`. Never estimate them.
- Keep intermediates in the GCS `work` bucket. Only the final file and its thumbnails go to R2 (render-worker only).
- Never strip LTX watermark or provenance metadata (licence item 19).
