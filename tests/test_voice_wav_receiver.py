from __future__ import annotations

import json
import tempfile
import threading
import unittest
import wave
from http.client import HTTPConnection
from io import BytesIO
from pathlib import Path

from tools.voice.receive_wav import VoiceUploadServer


def make_test_wav() -> bytes:
    output = BytesIO()
    with wave.open(output, "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(16_000)
        wav_file.writeframes(b"\x00\x00" * 160)
    return output.getvalue()


class VoiceUploadReceiverTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.output_dir = Path(self.temp_dir.name) / "received"
        self.server = VoiceUploadServer(("127.0.0.1", 0), self.output_dir, "test-token-with-more-than-24-chars")
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.host, self.port = self.server.server_address

    def tearDown(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.temp_dir.cleanup()

    def post(self, payload: bytes, token: str, content_type: str = "audio/wav") -> tuple[int, bytes]:
        connection = HTTPConnection(self.host, self.port)
        connection.request(
            "POST",
            "/upload",
            body=payload,
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Length": str(len(payload)),
                "Content-Type": content_type,
            },
        )
        response = connection.getresponse()
        result = response.status, response.read()
        connection.close()
        return result

    def test_saves_valid_wav_with_generated_name(self) -> None:
        payload = make_test_wav()
        status, response_body = self.post(payload, "test-token-with-more-than-24-chars")

        self.assertEqual(status, 201)
        result = json.loads(response_body)
        saved_path = self.output_dir / result["saved"]
        self.assertTrue(saved_path.is_file())
        self.assertEqual(saved_path.read_bytes(), payload)
        self.assertEqual(saved_path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(result["frames"], 160)

    def test_rejects_bad_token_and_invalid_wav(self) -> None:
        status, _ = self.post(make_test_wav(), "incorrect-token")
        self.assertEqual(status, 401)

        status, _ = self.post(b"not a wav file" * 8, "test-token-with-more-than-24-chars")
        self.assertEqual(status, 400)

    def test_rejects_unsupported_content_type(self) -> None:
        status, _ = self.post(make_test_wav(), "test-token-with-more-than-24-chars", "application/octet-stream")
        self.assertEqual(status, 415)


if __name__ == "__main__":
    unittest.main()