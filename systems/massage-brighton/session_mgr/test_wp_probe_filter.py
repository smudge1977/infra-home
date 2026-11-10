import ipaddress
import re
import unittest
from pathlib import Path


FILTER_PATH = Path(__file__).with_name("nginx-wp-probes.conf")


def load_failregexes():
    in_definition = False
    patterns = []
    for raw_line in FILTER_PATH.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if line.startswith("["):
            in_definition = line == "[Definition]"
            continue
        if in_definition and line.startswith("failregex ="):
            pattern = line.removeprefix("failregex =").strip()
            if pattern:
                pattern = pattern.replace("%%", "%")
                patterns.append(re.compile(pattern.replace("<HOST>", r"(?P<host>\S+)")))
    return patterns


class WordPressProbeFilterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.patterns = load_failregexes()

    def matching_hosts(self, line):
        hosts = []
        for pattern in self.patterns:
            match = pattern.search(line)
            if match:
                hosts.append(str(ipaddress.ip_address(match.group("host"))))
        return hosts

    def access_line(self, request, status=404, host="203.0.113.8"):
        return (
            f'{host} - - [10/Nov/2026:09:10:11 +0000] "{request}" '
            f'{status} 123 "-" "Example browser"'
        )

    def test_matches_high_confidence_sensitive_and_exploit_paths(self):
        targets = [
            "/.env",
            "/.env.production",
            "/app/.env.local?probe=1",
            "/.git/config",
            "/site/.svn/entries",
            "/.hg/store",
            "/wp-config.php",
            "/wp-config.php.bak",
            "/wp-config.php~",
            "/vendor/phpunit/phpunit/src/Util/PHP/eval-stdin.php",
            "/phpunit/phpunit/src/Util/PHP/eval-stdin.php",
            "/phpinfo.php",
            "/info.php?x=1",
            "/GponForm/diag_Form?images/",
            "/remote/login",
            "/cgi-bin/%3B/bin/busybox$%7BIFS%7Dwget",
            "/cgi-bin/%24%7BIFS%7Dcurl",
        ]
        for target in targets:
            with self.subTest(target=target):
                self.assertEqual(self.matching_hosts(self.access_line(f"GET {target} HTTP/1.1")), ["203.0.113.8"])

    def test_matches_ipv6_and_redirect_responses(self):
        line = self.access_line("HEAD /.env HTTP/1.1", status=301, host="2001:db8::8")
        self.assertEqual(self.matching_hosts(line), ["2001:db8::8"])

    def test_does_not_match_legitimate_or_non_specific_paths(self):
        targets = [
            "/.envrc",
            "/.gitignore",
            "/wp-login.php",
            "/wp-admin/",
            "/wp-json/wp/v2/pages",
            "/wp-cron.php",
            "/xmlrpc.php",
            "/cgi-bin/status",
            "/cgi-bin/healthcheck",
            "/search?q=/.env",
            "/assets/info.php.css",
            "/remote/login-help",
        ]
        for target in targets:
            with self.subTest(target=target):
                self.assertEqual(self.matching_hosts(self.access_line(f"GET {target} HTTP/1.1")), [])

    def test_does_not_match_unrelated_methods(self):
        for method in ("PUT", "OPTIONS", "DELETE"):
            with self.subTest(method=method):
                self.assertEqual(self.matching_hosts(self.access_line(f"{method} /.env HTTP/1.1")), [])


if __name__ == "__main__":
    unittest.main()
