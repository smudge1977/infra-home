import ipaddress
import re
import unittest
from pathlib import Path


FILTER_PATHS = {
    "login": Path(__file__).with_name("nginx-wordpress-login.conf"),
    "xmlrpc": Path(__file__).with_name("nginx-wordpress-xmlrpc.conf"),
}


def load_failregexes(filter_path):
    """Load the candidate Fail2ban expressions for syntax/scope unit tests."""
    in_definition = False
    collecting = False
    patterns = []
    for raw_line in filter_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if line.startswith("["):
            in_definition = line == "[Definition]"
            collecting = False
            continue
        if not in_definition or not line or line.startswith("#"):
            continue
        if line.startswith("failregex ="):
            collecting = True
            expression = line.removeprefix("failregex =").strip()
            if expression:
                patterns.append(expression)
            continue
        if collecting and raw_line[:1].isspace():
            patterns.append(line)
            continue
        collecting = False

    return [
        re.compile(pattern.replace("<HOST>", r"(?P<host>\S+)"))
        for pattern in patterns
    ]


class CandidateFilterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.patterns = {
            name: load_failregexes(path) for name, path in FILTER_PATHS.items()
        }

    def matching_hosts(self, line, filter_name):
        hosts = []
        for pattern in self.patterns[filter_name]:
            match = pattern.search(line)
            if match:
                hosts.append(str(ipaddress.ip_address(match.group("host"))))
        return hosts

    def test_matches_login_post_with_or_without_query(self):
        for target in ("/wp-login.php", "/wp-login.php?redirect_to=%2Fwp-admin"):
            line = (
                '203.0.113.8 - - [01/Nov/2026:12:34:56 +0000] '
                f'"POST {target} HTTP/1.1" 200 123 "-" "Example browser"'
            )
            self.assertEqual(self.matching_hosts(line, "login"), ["203.0.113.8"])

    def test_matches_both_xmlrpc_slash_forms(self):
        for target in ("/xmlrpc.php", "//xmlrpc.php?x=1"):
            line = (
                '2001:db8::8 - - [01/Nov/2026:12:34:56 +0000] '
                f'"POST {target} HTTP/2.0" 200 0 "-" "Example browser"'
            )
            self.assertEqual(self.matching_hosts(line, "xmlrpc"), ["2001:db8::8"])

    def test_does_not_match_gets_or_unrelated_paths(self):
        examples = [
            '203.0.113.8 - - [01/Nov/2026:12:34:56 +0000] "GET /xmlrpc.php HTTP/1.1" 200 10 "-" "agent"',
            '203.0.113.8 - - [01/Nov/2026:12:34:56 +0000] "GET /wp-login.php HTTP/1.1" 200 10 "-" "agent"',
            '203.0.113.8 - - [01/Nov/2026:12:34:56 +0000] "POST /other?next=/wp-login.php HTTP/1.1" 200 10 "-" "agent"',
            '203.0.113.8 - - [01/Nov/2026:12:34:56 +0000] "POST /xmlrpc.php/extra HTTP/1.1" 200 10 "-" "agent"',
        ]
        for line in examples:
            with self.subTest(line=line):
                self.assertEqual(self.matching_hosts(line, "login"), [])
                self.assertEqual(self.matching_hosts(line, "xmlrpc"), [])

    def test_rejects_bad_host_even_if_shape_matches(self):
        line = (
            'not-an-ip - - [01/Nov/2026:12:34:56 +0000] '
            '"POST /wp-login.php HTTP/1.1" 200 10 "-" "agent"'
        )
        with self.assertRaises(ValueError):
            self.matching_hosts(line, "login")


if __name__ == "__main__":
    unittest.main()
