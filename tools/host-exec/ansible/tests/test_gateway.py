import importlib.util
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

gateway_path = Path(__file__).resolve().parents[1] / "files" / "host_exec_gateway.py"
gateway_spec = importlib.util.spec_from_file_location("host_exec_gateway", gateway_path)
if gateway_spec is None or gateway_spec.loader is None:
    raise RuntimeError("could not load host-exec gateway module")
gateway = importlib.util.module_from_spec(gateway_spec)
sys.modules[gateway_spec.name] = gateway
gateway_spec.loader.exec_module(gateway)
RequestError = gateway.RequestError
parse_request = gateway.parse_request
run_readonly = gateway.run_readonly


class ParseRequestTests(unittest.TestCase):
    def test_accepts_fixed_read_only_operations(self):
        self.assertEqual(parse_request("facts").operation, "facts")
        self.assertEqual(parse_request("processes").operation, "processes")
        self.assertEqual(parse_request("sockets").operation, "sockets")

    def test_accepts_only_allowlisted_services(self):
        request = parse_request("service-status zabbix-agent2")
        self.assertEqual((request.operation, request.target), ("service-status", "zabbix-agent2"))
        with self.assertRaises(RequestError):
            parse_request("service-status ssh")

    def test_bounds_log_lookback(self):
        request = parse_request("logs zabbix-agent --minutes 60")
        self.assertEqual((request.target, request.minutes), ("zabbix-agent", 60))
        for value in ("0", "61", "-1", "1.5", "999999999999"):
            with self.subTest(value=value), self.assertRaises(RequestError):
                parse_request(f"logs zabbix-agent --minutes {value}")

    def test_rejects_shell_syntax_and_extra_arguments(self):
        for command in (
            "exec id",
            "facts; id",
            "facts && whoami",
            "logs zabbix-agent --minutes 5; id",
            "service-status zabbix-agent /etc/shadow",
        ):
            with self.subTest(command=command), self.assertRaises(RequestError):
                parse_request(command)

    def test_rejects_malformed_or_oversized_requests(self):
        for command in ("", "facts 'unterminated", "facts" + " " * 512):
            with self.subTest(command=command), self.assertRaises(RequestError):
                parse_request(command)

    @patch("host_exec_gateway.subprocess.run")
    def test_diagnostic_subprocess_has_fixed_environment_and_no_shell(self, mocked_run):
        mocked_run.return_value = SimpleNamespace(returncode=0, stdout="active\n")

        result = run_readonly(["systemctl", "is-active", "zabbix-agent"])

        self.assertEqual(result, (0, "active\n"))
        self.assertIs(mocked_run.call_args.kwargs["shell"], False)
        self.assertEqual(
            mocked_run.call_args.kwargs["env"],
            {"PATH": "/usr/sbin:/usr/bin:/sbin:/bin", "LC_ALL": "C"},
        )


if __name__ == "__main__":
    unittest.main()