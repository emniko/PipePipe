#!/usr/bin/env python3
"""Tap a view on the emulator by its text, content description or resource id.

usage: ui_tap.py <regex> [--id] [--index N]
Exits 1 if nothing matches, so callers can treat it as optional with `|| true`.
"""
import re
import subprocess
import sys
import xml.etree.ElementTree as ET


def dump():
    subprocess.run(["adb", "shell", "uiautomator", "dump", "/sdcard/ui.xml"],
                   capture_output=True)
    out = subprocess.run(["adb", "shell", "cat", "/sdcard/ui.xml"],
                         capture_output=True, text=True).stdout
    return ET.fromstring(out[out.index("<"):])


def main():
    pattern = re.compile(sys.argv[1], re.IGNORECASE)
    by_id = "--id" in sys.argv
    index = int(sys.argv[sys.argv.index("--index") + 1]) if "--index" in sys.argv else 0
    matches = []
    for node in dump().iter("node"):
        keys = [node.get("resource-id", "")] if by_id else \
            [node.get("text", ""), node.get("content-desc", "")]
        if any(k and pattern.search(k) for k in keys):
            b = re.findall(r"\d+", node.get("bounds", ""))
            if len(b) == 4:
                matches.append(((int(b[0]) + int(b[2])) // 2, (int(b[1]) + int(b[3])) // 2))
    if len(matches) <= index:
        print(f"no match for {sys.argv[1]}")
        sys.exit(1)
    x, y = matches[index]
    print(f"tap {sys.argv[1]} at {x},{y}")
    subprocess.run(["adb", "shell", "input", "tap", str(x), str(y)])


if __name__ == "__main__":
    main()
