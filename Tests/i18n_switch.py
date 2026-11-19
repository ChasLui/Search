#!/usr/bin/env python3
"""Check language switches against tab and WebView identities in a hidden probe.

Build first (`./build.sh`), then run `python3 Tests/i18n_switch.py`. Set
`SEARCH_BENCH_APP` to test a different app bundle. This uses the same isolated
profile and bench as the split-view tests. Each run
restores 20 or 200 tabs, opens a second window, makes a split, and sleeps a
background tab before switching both ways.
"""
import json
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import split_view as sv  # noqa: E402

sv.APP = os.environ.get("SEARCH_BENCH_APP", sv.APP)
sv.use("i18n-switch")


def snapshot(window):
    state = sv.sp("state", window=window)
    tabs = {tab["id"]: (tab["web"], tab["built"], tab["asleep"]) for tab in state["tabs"]}
    splits = [split["tabs"] for split in state["splits"]]
    return tabs, splits, state["activeID"]


def check(count, test):
    sv.setup(splitView=True)
    os.makedirs(sv.SUPPORT, exist_ok=True)
    tabs = [{"url": f"{sv.BASE}/tab-{i}", "title": f"Tab {i}"} for i in range(count)]
    with open(f"{sv.SUPPORT}/session.json", "w") as session:
        json.dump({"tabs": tabs, "active": 0}, session)
    sv.launch()
    first = sv.sp("state", window=1)
    test.ok(f"{count}: session restored", len(first["tabs"]) == count, len(first["tabs"]))
    a, b, sleeping = [tab["id"] for tab in first["tabs"][:3]]

    sv.sp("select", id=sleeping, window=1)
    sv.cmd({"do": "wait", "id": sleeping, "window": 1, "seconds": 5})
    sv.sp("select", id=a, window=1)
    result = sv.cmd({"do": "sleep", "id": sleeping, "window": 1})
    test.ok(f"{count}: background tab slept", result.get("asleep") is True, result)
    sv.sp("pair", id=b, **{"with": a}, side="right", window=1)
    sv.cmd({"do": "windows", "action": "new"})
    second = sv.sp("open", url=f"{sv.BASE}/other", window=2)["resultID"]
    sv.cmd({"do": "wait", "id": second, "window": 2, "seconds": 5})
    sv.sp("select", id=a, window=1)
    sv.cmd({"do": "wait", "id": a, "window": 1, "seconds": 5})
    sv.ev(a, """document.body.innerHTML = '<div style="height:4000px"><input id="draft"></div>';
        document.querySelector('#draft').value = 'unsent draft'; window.scrollTo(0, 600);
        document.querySelector('#draft').focus({preventScroll:true}); true""")
    page = "JSON.stringify({value:document.querySelector('#draft').value, focus:document.activeElement.id, scroll:window.scrollY})"
    original_page = sv.ev(a, page)
    before = [snapshot(1), snapshot(2)]
    page_state = json.loads(original_page)
    test.ok(f"{count}: split and form prepared", bool(before[0][1]) and page_state["value"] == "unsent draft"
            and page_state["focus"] == "draft" and page_state["scroll"] > 0, (before[0][1], page_state))

    for choice in ("en", "zh-Hans", "en"):
        reply = sv.cmd({"do": "settings", "set": "general.language", "value": choice, "window": 2})
        time.sleep(0.3)
        after = [snapshot(1), snapshot(2)]
        test.ok(f"{count}: {choice} kept both windows' tabs and WebViews", after == before, reply.get("values"))
        test.ok(f"{count}: {choice} kept the form, focus and scroll", sv.ev(a, page) == original_page)
        test.ok(f"{count}: {choice} was selected", reply["values"].get("ui.language") == choice)
    sv.quit()


if __name__ == "__main__":
    t = sv.T()
    try:
        for size in (20, 200):
            check(size, t)
    finally:
        t.done()
        sv.finish()
    sys.exit(1 if t.failed else 0)
