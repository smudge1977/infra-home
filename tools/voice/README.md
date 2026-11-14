# Temporary WAV upload receiver

The Python standard-library `http.server` serves files but does not accept WAV
uploads. This small receiver accepts authenticated `POST /upload` requests and
saves validated mono, 16 kHz, 16-bit PCM WAV files using generated filenames.
It has no transcription or Home Assistant integration.

From the infra-home repository root, start it on the Mac with a private token
matching `voice_upload_token` in the ESPHome secrets file:

```sh
VOICE_UPLOAD_TOKEN='replace-with-a-random-token-at-least-24-characters' \
  /bin/python3 -m tools.voice.receive_wav --host 0.0.0.0 --port 8765 \
  --output-dir ./received-wav
```

Use the Mac's LAN address in HeatMesh `secrets.yaml` as
`voice_upload_url: http://MAC-LAN-IP:8765/upload`, and set the matching
`voice_upload_token`. Keep this temporary HTTP service on a trusted LAN only;
the bearer token is not encrypted in transit. Stop with Ctrl+C. Audio is stored
locally under `received-wav/`; delete recordings when no longer needed.

The ESPHome test firmware is isolated in HeatMesh's `voice-prototype.yaml`.
It begins a fixed four-second capture after “Okay Nabu” and sends that WAV once.
This is a plumbing test only: no VAD, transcription, or playback is included.