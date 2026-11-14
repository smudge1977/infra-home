"""LAN-only WAV upload receiver for the HeatMesh voice prototype."""

from __future__ import annotations

import argparse
import hmac
import json
import os
import wave
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from io import BytesIO
from pathlib import Path
from uuid import uuid4

MAX_UPLOAD_BYTES = 320_044  # 10 seconds of 16 kHz, mono, 16-bit PCM plus WAV header.
MAX_DURATION_SECONDS = 10


class VoiceUploadServer(ThreadingHTTPServer):
    """HTTP server that stores validated WAV uploads under generated names."""

    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, address: tuple[str, int], output_dir: Path, token: str) -> None:
        self.output_dir = output_dir
        self.token = token
        super().__init__(address, VoiceUploadHandler)


class VoiceUploadHandler(BaseHTTPRequestHandler):
    server: VoiceUploadServer

    def do_GET(self) -> None:
        if self.path != "/health":
            self.send_error(404)
            return
        self._send_json(200, {"status": "ready"})

    def do_POST(self) -> None:
        if self.path != "/upload":
            self.send_error(404)
            return

        supplied_token = self.headers.get("Authorization", "")
        expected_token = f"Bearer {self.server.token}"
        if not hmac.compare_digest(supplied_token, expected_token):
            self.send_error(401, "Invalid upload token")
            return

        content_type = self.headers.get_content_type()
        if content_type not in {"audio/wav", "audio/x-wav"}:
            self.send_error(415, "Content-Type must be audio/wav")
            return

        try:
            content_length = int(self.headers.get("Content-Length", ""))
        except ValueError:
            self.send_error(411, "A valid Content-Length is required")
            return
        if not 44 < content_length <= MAX_UPLOAD_BYTES:
            self.send_error(413, "WAV size is outside the accepted range")
            return

        payload = self.rfile.read(content_length)
        if len(payload) != content_length:
            self.send_error(400, "Incomplete request body")
            return

        try:
            with wave.open(BytesIO(payload), "rb") as wav_file:
                if (
                    wav_file.getnchannels() != 1
                    or wav_file.getsampwidth() != 2
                    or wav_file.getframerate() != 16_000
                    or wav_file.getcomptype() != "NONE"
                    or not 0 < wav_file.getnframes() <= 16_000 * MAX_DURATION_SECONDS
                ):
                    raise wave.Error("unexpected WAV format or duration")
                frames = wav_file.getnframes()
        except (wave.Error, EOFError):
            self.send_error(400, "Expected mono 16 kHz, 16-bit PCM WAV (max 10 seconds)")
            return

        self.server.output_dir.mkdir(parents=True, exist_ok=True)
        filename = f"{uuid4().hex}.wav"
        destination = self.server.output_dir / filename
        flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
        descriptor = os.open(destination, flags, 0o600)
        with os.fdopen(descriptor, "wb") as wav_file:
            wav_file.write(payload)

        self._send_json(201, {"saved": filename, "frames": frames})

    def _send_json(self, status: int, data: dict[str, object]) -> None:
        body = json.dumps(data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: object) -> None:
        # Do not log request bodies, tokens, or audio-related metadata.
        super().log_message(format, *args)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="0.0.0.0", help="Bind address (default: all interfaces)")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--output-dir", type=Path, default=Path("received-wav"))
    parser.add_argument(
        "--token",
        default=os.environ.get("VOICE_UPLOAD_TOKEN"),
        help="Required bearer token (or set VOICE_UPLOAD_TOKEN)",
    )
    args = parser.parse_args()
    if not args.token or len(args.token) < 24:
        parser.error("provide a bearer token of at least 24 characters via --token or VOICE_UPLOAD_TOKEN")
    return args


def main() -> None:
    args = parse_args()
    server = VoiceUploadServer((args.host, args.port), args.output_dir, args.token)
    print(f"WAV receiver listening on http://{args.host}:{args.port}/upload")
    print(f"Saving uploads under {args.output_dir.resolve()}; press Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping WAV receiver.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()