#!/usr/bin/env python3
"""Run every Swift test; isolate cases that share native state."""

import os
import re
import subprocess
import sys

# FaviconMemoryTests selects its own SEARCH_PROBE in class setup. Store.world
# is fixed on first access, so that setup needs a fresh process to take effect.
isolated_suites = (
    "DownloadLifecycleTests",
    "FaviconMemoryTests",
    "FloatUnseenTests",
    "PinStuckTests",
    "SidebarPressTests",
)
suite_pattern = "|".join(isolated_suites)
resources = subprocess.run([sys.executable, "Tests/check-localization.py"])
# WebKit lifecycle journeys and AppKit gesture fixtures interfere when they
# share a process and retain native state between cases.
result = subprocess.run(["swift", "test", "--skip", suite_pattern])
failed = resources.returncode != 0 or result.returncode != 0
listing = subprocess.run(
    ["swift", "test", "list"], check=True, capture_output=True, text=True
)
cases = [
    line.strip()
    for line in listing.stdout.splitlines()
    if re.fullmatch(rf"SearchTests\.(?:{suite_pattern})/test\w+", line.strip())
]
for suite in isolated_suites:
    if not any(case.startswith(f"SearchTests.{suite}/") for case in cases):
        raise RuntimeError(f"No isolated tests found for {suite}")
for index, case in enumerate(cases):
    print(f"Isolated case: {case}", flush=True)
    env = dict(os.environ, SEARCH_PROBE=f"ci-isolated-{os.getpid()}-{index}")
    result = subprocess.run(
        ["swift", "test", "--skip-build", "--filter", f"^{re.escape(case)}$"], env=env
    )
    failed |= result.returncode != 0
sys.exit(1 if failed else 0)
