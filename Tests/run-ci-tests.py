#!/usr/bin/env python3
"""Run every Swift test; isolate WebKit download journeys in fresh processes."""
import os
import re
import subprocess
import sys

suite = "DownloadLifecycleTests"
resources = subprocess.run([sys.executable, "Tests/check-localization.py"])
# The rest of the suite runs together; native WebKit state is never reused by
# two download journeys. No retry or skipped download assertion is involved.
result = subprocess.run(["swift", "test", "--skip", suite])
failed = resources.returncode != 0 or result.returncode != 0
listing = subprocess.run(["swift", "test", "list"], check=True, capture_output=True, text=True)
cases = [line.strip() for line in listing.stdout.splitlines()
         if re.fullmatch(r"SearchTests\.DownloadLifecycleTests/test\w+", line.strip())]
if not cases:
    raise RuntimeError(f"No WebKit download tests found for {suite}")
for index, case in enumerate(cases):
    print(f"Isolated WebKit case: {case}", flush=True)
    env = dict(os.environ, SEARCH_PROBE=f"ci-download-{os.getpid()}-{index}")
    result = subprocess.run(["swift", "test", "--skip-build", "--filter", f"^{re.escape(case)}$"], env=env)
    failed |= result.returncode != 0
sys.exit(1 if failed else 0)
