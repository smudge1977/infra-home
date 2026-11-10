#!/usr/bin/env python3
"""Read-only Nginx access-log burst analyzer; never changes firewall state.

Example:
    tail -n 10000 /var/log/nginx/access.log | python3 log_audit.py

Each row is a review lead, not evidence by itself for blocking an address.
"""

from __future__ import annotations

import argparse
import hashlib
import ipaddress
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from datetime import datetime

LOG_LINE = re.compile(
    r'^(?P<ip>\S+) \S+ \S+ \[(?P<time>[^]]+)\] '
    r'"(?P<method>[A-Z]+) (?P<target>\S+) [^\"]+" '
    r'(?P<status>\d{3}) (?P<bytes>\S+)'
)
LOG_TIME = "%d/%b/%Y:%H:%M:%S %z"


@dataclass
class Bucket:
    requests: int = 0
    status_counts: Counter[int] = field(default_factory=Counter)
    requests_by_method_path: Counter[tuple[str, str]] = field(default_factory=Counter)


def parse_line(line: str) -> tuple[str, datetime, str, str, int] | None:
    """Parse the standard Nginx combined access-log prefix."""
    match = LOG_LINE.match(line)
    if match is None:
        return None
    try:
        address = str(ipaddress.ip_address(match["ip"]))
        timestamp = datetime.strptime(match["time"], LOG_TIME)
        status = int(match["status"])
    except (ValueError, OverflowError):
        return None

    target = match["target"].split("?", 1)[0]
    return address, timestamp, match["method"], target, status


def analyze(lines: list[str], window_minutes: int, min_requests: int):
    """Return per-client time buckets, plus parsed and rejected line counts."""
    window_seconds = window_minutes * 60
    buckets: dict[tuple[str, int], Bucket] = defaultdict(Bucket)
    parsed = 0

    for line in lines:
        record = parse_line(line)
        if record is None:
            continue
        address, timestamp, method, path, status = record
        parsed += 1
        bucket_start = int(timestamp.timestamp()) // window_seconds * window_seconds
        bucket = buckets[(address, bucket_start)]
        bucket.requests += 1
        bucket.status_counts[status] += 1
        bucket.requests_by_method_path[(method, path)] += 1

    candidates = [
        (address, bucket_start, bucket)
        for (address, bucket_start), bucket in buckets.items()
        if bucket.requests >= min_requests
    ]
    candidates.sort(key=lambda item: (-item[2].requests, item[0], item[1]))
    return candidates, parsed, len(lines) - parsed


def display_address(address: str, show_ips: bool) -> str:
    if show_ips:
        return address
    digest = hashlib.sha256(address.encode("ascii")).hexdigest()[:8]
    return f"client-{digest}"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--window-minutes", type=int, default=5)
    parser.add_argument("--min-requests", type=int, default=20)
    parser.add_argument("--top", type=int, default=15)
    parser.add_argument(
        "--show-ips",
        action="store_true",
        help="show source IPs (default output uses stable pseudonyms)",
    )
    args = parser.parse_args(argv)
    if args.window_minutes < 1 or args.min_requests < 1 or args.top < 1:
        parser.error("window, threshold, and top count must be positive")

    lines = list(sys.stdin)
    candidates, parsed, rejected = analyze(
        lines, args.window_minutes, args.min_requests
    )
    print(
        f"Parsed {parsed} access records; ignored {rejected} non-matching lines."
    )
    print(
        f"Review leads: at least {args.min_requests} requests per client "
        f"per {args.window_minutes}-minute bucket."
    )
    print("Volume and HTTP 499 counts alone do not establish abuse; no bans are made.")
    if not candidates:
        print("No buckets met the review threshold.")
        return 0

    print("requests  499  5xx  client          UTC bucket start       top method/path")
    for address, bucket_start, bucket in candidates[: args.top]:
        path_summary = ", ".join(
            f"{method} {path} ({count})"
            for (method, path), count in bucket.requests_by_method_path.most_common(3)
        )
        timestamp = datetime.fromtimestamp(bucket_start).astimezone().isoformat(
            timespec="minutes"
        )
        count_499 = bucket.status_counts[499]
        count_5xx = sum(
            count for status, count in bucket.status_counts.items() if 500 <= status < 600
        )
        print(
            f"{bucket.requests:8} {count_499:4} {count_5xx:4}  "
            f"{display_address(address, args.show_ips):14} {timestamp:22} "
            f"{path_summary}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
