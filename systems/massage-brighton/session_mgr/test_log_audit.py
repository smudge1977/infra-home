import unittest
from datetime import datetime

from log_audit import analyze, parse_line


class ParseLineTests(unittest.TestCase):
    def test_parses_nginx_combined_line_and_strips_query(self):
        line = (
            '203.0.113.8 - - [01/Nov/2026:12:34:56 +0000] '
            '"POST /wp-login.php?redirect_to=%2Fwp-admin HTTP/1.1" '
            '403 123 "-" "Example browser"'
        )
        self.assertEqual(
            parse_line(line),
            (
                "203.0.113.8",
                datetime.fromisoformat("2026-11-01T12:34:56+00:00"),
                "POST",
                "/wp-login.php",
                403,
            ),
        )

    def test_rejects_non_ip_and_non_access_lines(self):
        self.assertIsNone(parse_line("not an access log line"))
        self.assertIsNone(
            parse_line(
                'not-an-ip - - [01/Nov/2026:12:34:56 +0000] '
                '"GET / HTTP/1.1" 200 1 "-" "agent"'
            )
        )


class AnalyzeTests(unittest.TestCase):
    def test_groups_by_client_and_fixed_time_window(self):
        rows = [
            '203.0.113.8 - - [01/Nov/2026:12:00:01 +0000] "GET /?x=1 HTTP/1.1" 200 10 "-" "agent"',
            '203.0.113.8 - - [01/Nov/2026:12:04:59 +0000] "GET /treatments/ HTTP/1.1" 499 0 "-" "agent"',
            '203.0.113.8 - - [01/Nov/2026:12:05:00 +0000] "GET / HTTP/1.1" 200 10 "-" "agent"',
            '203.0.113.9 - - [01/Nov/2026:12:00:01 +0000] "GET / HTTP/1.1" 200 10 "-" "agent"',
        ]
        candidates, parsed, rejected = analyze(rows, window_minutes=5, min_requests=2)
        self.assertEqual((parsed, rejected), (4, 0))
        self.assertEqual(len(candidates), 1)
        address, _bucket_start, bucket = candidates[0]
        self.assertEqual(address, "203.0.113.8")
        self.assertEqual(bucket.requests, 2)
        self.assertEqual(bucket.status_counts[499], 1)
        self.assertEqual(bucket.requests_by_method_path[("GET", "/")], 1)
        self.assertNotIn(("GET", "/?x=1"), bucket.requests_by_method_path)

    def test_counts_malformed_lines_as_rejected(self):
        candidates, parsed, rejected = analyze(
            ["not a log", '203.0.113.8 - - [01/Nov/2026:12:00:01 +0000] "GET / HTTP/1.1" 200 10 "-" "agent"'],
            window_minutes=5,
            min_requests=1,
        )
        self.assertEqual((parsed, rejected), (1, 1))
        self.assertEqual(len(candidates), 1)

    def test_no_candidate_below_threshold(self):
        rows = ['203.0.113.8 - - [01/Nov/2026:12:00:01 +0000] "GET / HTTP/1.1" 200 10 "-" "agent"']
        candidates, _parsed, _rejected = analyze(rows, window_minutes=5, min_requests=2)
        self.assertEqual(candidates, [])


if __name__ == "__main__":
    unittest.main()
