#!/usr/bin/python3 -I
"""Restricted, read-only SSH forced-command gateway for the host-exec POC."""

from __future__ import annotations

import datetime as dt
import getpass
import os
import platform
import secrets
import shlex
import subprocess
import sys
import syslog
import time
from dataclasses import dataclass


ALLOWED_SERVICES = frozenset({"zabbix-agent", "zabbix-agent2"})
MAX_REQUEST_LENGTH = 512
MAX_OUTPUT_BYTES = 16_384
MAX_LOG_MINUTES = 60
MAX_LOG_LINES = 200
COMMAND_TIMEOUT_SECONDS = 10
COMMAND_ENV = {"PATH": "/usr/sbin:/usr/bin:/sbin:/bin", "LC_ALL": "C"}


class RequestError(ValueError):
    """The SSH request is outside the gateway's deliberately small protocol."""


@dataclass(frozen=True)
class Request:
    operation: str
    target: str = "none"
    minutes: int | None = None


def parse_request(command: str) -> Request:
    """Parse SSH_ORIGINAL_COMMAND without evaluating it as a shell command."""
    if not command or len(command) > MAX_REQUEST_LENGTH:
        raise RequestError("request is empty or too long")
    if any(ord(char) < 32 or ord(char) == 127 for char in command):
        raise RequestError("control characters are not permitted")

    try:
        args = shlex.split(command, posix=True)
    except ValueError as exc:
        raise RequestError("malformed request") from exc

    if not args:
        raise RequestError("request is empty")
    operation = args[0]
    if operation in {"facts", "processes", "sockets"} and len(args) == 1:
        return Request(operation=operation)
    if operation == "service-status" and len(args) == 2:
        service = args[1]
        if service not in ALLOWED_SERVICES:
            raise RequestError("service not permitted")
        return Request(operation=operation, target=service)
    if operation == "logs" and len(args) == 4 and args[2] == "--minutes":
        service, minutes_text = args[1], args[3]
        if service not in ALLOWED_SERVICES:
            raise RequestError("service not permitted")
        if not minutes_text.isascii() or not minutes_text.isdecimal():
            raise RequestError("--minutes must be an integer between 1 and 60")
        minutes = int(minutes_text)
        if not 1 <= minutes <= MAX_LOG_MINUTES:
            raise RequestError("--minutes must be an integer between 1 and 60")
        return Request(operation=operation, target=service, minutes=minutes)

    if operation not in {"facts", "service-status", "logs", "processes", "sockets"}:
        raise RequestError("operation not permitted")
    raise RequestError("invalid arguments")


def bounded_output(value: str) -> str:
    """Limit bytes emitted to the SSH client, preserving valid UTF-8 output."""
    encoded = value.encode("utf-8", errors="replace")
    if len(encoded) <= MAX_OUTPUT_BYTES:
        return value
    marker = b"\n[output truncated by host-exec gateway]\n"
    kept = encoded[: MAX_OUTPUT_BYTES - len(marker)]
    return kept.decode("utf-8", errors="ignore") + marker.decode("ascii")


def run_readonly(argv: list[str], timeout: int = COMMAND_TIMEOUT_SECONDS) -> tuple[int, str]:
    """Run one fixed argv without a shell and return bounded stdout only."""
    try:
        result = subprocess.run(
            argv,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
            shell=False,
            env=COMMAND_ENV,
        )
    except subprocess.TimeoutExpired:
        return 124, "ERROR: operation timed out\n"
    except OSError:
        return 127, "ERROR: required diagnostic command is unavailable\n"

    output = bounded_output(result.stdout or "")
    if not output and result.returncode:
        output = f"ERROR: diagnostic command failed (exit {result.returncode})\n"
    return result.returncode, output


def facts_output() -> str:
    """Return a small, fixed set of non-secret host facts."""
    try:
        with open("/proc/uptime", encoding="ascii") as uptime_file:
            uptime_seconds = float(uptime_file.read().split()[0])
        uptime = str(dt.timedelta(seconds=int(uptime_seconds)))
    except (OSError, ValueError, IndexError):
        uptime = "unavailable"

    try:
        release = platform.freedesktop_os_release()
        os_name = release.get("PRETTY_NAME", "Linux")
    except (AttributeError, OSError):
        os_name = platform.system()

    now = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")
    return (
        f"hostname: {platform.node()}\n"
        f"os: {os_name}\n"
        f"kernel: {platform.release()}\n"
        f"uptime: {uptime}\n"
        f"utc: {now}\n"
    )


def execute(request: Request) -> tuple[int, str]:
    """Map a validated request to a fixed diagnostic implementation."""
    if request.operation == "facts":
        return 0, facts_output()
    if request.operation == "service-status":
        return run_readonly(["systemctl", "is-active", request.target])
    if request.operation == "logs":
        return run_readonly(
            [
                "journalctl",
                f"--unit={request.target}",
                f"--since={request.minutes} minutes ago",
                f"--lines={MAX_LOG_LINES}",
                "--no-pager",
                "--output=short-iso",
            ],
            timeout=COMMAND_TIMEOUT_SECONDS + 5,
        )
    if request.operation == "processes":
        return run_readonly(
            ["ps", "-eo", "pid=,comm=,etimes=,%cpu=,%mem=", "--sort=-%cpu"]
        )
    if request.operation == "sockets":
        return run_readonly(["ss", "-lntu"])
    return 2, "ERROR: operation not permitted\n"


def audit(operation: str, target: str, result: int, duration_ms: int, op_id: str) -> None:
    """Write metadata only; never log the request text or diagnostic output."""
    user = getpass.getuser()
    message = (
        f"op={op_id} user={user} operation={operation} target={target} "
        f"result={result} duration_ms={duration_ms}"
    )
    syslog.openlog("host-exec-gateway", syslog.LOG_PID, syslog.LOG_AUTHPRIV)
    syslog.syslog(syslog.LOG_NOTICE, message)


def main() -> int:
    started = time.monotonic()
    op_id = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    op_id += f"-{secrets.token_hex(3)}"
    operation, target = "invalid", "none"

    try:
        request = parse_request(os.environ.get("SSH_ORIGINAL_COMMAND", ""))
        operation, target = request.operation, request.target
        result, output = execute(request)
    except RequestError as exc:
        result, output = 2, f"ERROR: {exc}\n"
    except Exception:
        result, output = 70, "ERROR: internal gateway failure\n"

    duration_ms = int((time.monotonic() - started) * 1000)
    try:
        audit(operation, target, result, duration_ms, op_id)
    except OSError:
        sys.stderr.write("ERROR: audit logging unavailable; request denied\n")
        return 70

    stream = sys.stdout if result in {0, 3} else sys.stderr
    stream.write(bounded_output(output))
    stream.flush()
    return result


if __name__ == "__main__":
    raise SystemExit(main())