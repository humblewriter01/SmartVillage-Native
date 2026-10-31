#!/usr/bin/env python3
"""Regenerate `tool/flutter_icons.txt` from the Flutter framework source.

`lib/screens/water_quality_screen.dart` once used `Icons.boil`, which does not
exist; the Dart front-end only noticed at `flutter build apk` time, ten minutes
into a Codemagic run. `check_dart.py` now validates every `Icons.<name>` against
this list, so the same typo fails locally in a second.

Run after upgrading Flutter so newly added icons are recognised:

    python3 tool/refresh_icons.py            # uses the `stable` branch
    python3 tool/refresh_icons.py --ref 3.35.0

Only the GitHub REST API is required (no Flutter SDK).
"""

from __future__ import annotations

import argparse
import base64
import json
import pathlib
import re
import urllib.request

API = "https://api.github.com/repos/flutter/flutter"
ICONS_PATH = "packages/flutter/lib/src/material/icons.dart"
OUT = pathlib.Path(__file__).with_name("flutter_icons.txt")


def get_json(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=60) as response:
        return json.load(response)


def fetch_source(ref: str) -> str:
    """Return icons.dart. Files over 1 MB come back as a git blob instead."""
    meta = get_json(f"{API}/contents/{ICONS_PATH}?ref={ref}")
    content = meta.get("content")
    if content:
        return base64.b64decode(content).decode("utf-8")
    blob = get_json(f"{API}/git/blobs/{meta['sha']}")
    return base64.b64decode(blob["content"]).decode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ref", default="stable", help="branch or tag")
    args = parser.parse_args()

    source = fetch_source(args.ref)
    names = sorted(set(re.findall(r"static const IconData ([A-Za-z0-9_]+)", source)))
    if len(names) < 1000:
        raise SystemExit(f"only {len(names)} icons parsed - wrong file?")
    OUT.write_text(
        "# Material icon names, extracted from\n"
        f"# {ICONS_PATH} ({args.ref}).\n"
        "# Used by tool/check_dart.py to reject `Icons.<name>` typos without the SDK.\n"
        "# Refresh with: python3 tool/refresh_icons.py\n"
        + "\n".join(names)
        + "\n",
        encoding="utf-8",
    )
    print(f"wrote {OUT} ({len(names)} icons, {OUT.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
