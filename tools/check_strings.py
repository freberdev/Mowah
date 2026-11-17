#!/usr/bin/env python3
"""Checks the texts of the Mac app.

Every text key the Swift code uses must exist in the string catalog in both
Swedish and English, with the same placeholders, and the catalog must not hold
keys the code no longer uses. Xcode only syncs the catalog when a build is
started from its own window, so a missing translation would otherwise show up
as a bare key in the running app.

Run from the repository root:  python3 tools/check_strings.py
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / "macos" / "Mowah"
CATALOG = SOURCES / "Resources" / "Localizable.xcstrings"
LANGUAGES = ("en", "sv")
# Text keys are namespaced, which is what tells them apart from other strings in the code.
PREFIXES = (
    "status", "duration", "lastAction", "menu", "permission", "group", "field", "method", "unit", "app", "language",
)
KEY = re.compile(r'"((?:%s)\.[A-Za-z]+)"' % "|".join(PREFIXES))
PLACEHOLDER = re.compile(r"%(?:\d+\$)?(?:lld|@|d)")


def main():
    used = set()
    for path in sorted(SOURCES.rglob("*.swift")):
        used.update(KEY.findall(path.read_text(encoding="utf-8")))

    strings = json.loads(CATALOG.read_text(encoding="utf-8"))["strings"]
    problems = []

    for key in sorted(used - strings.keys()):
        problems.append(f"{key}: used in the code but missing from the catalog")
    for key in sorted(strings.keys() - used):
        problems.append(f"{key}: in the catalog but not used in the code")

    for key in sorted(used & strings.keys()):
        values = {}
        for language in LANGUAGES:
            unit = strings[key].get("localizations", {}).get(language, {}).get("stringUnit", {})
            value = unit.get("value", "")
            if not value.strip() or unit.get("state") != "translated":
                problems.append(f"{key}: no finished {language} text")
            values[language] = value
        if len({tuple(PLACEHOLDER.findall(v)) for v in values.values()}) > 1:
            problems.append(f"{key}: the placeholders differ between the languages")

    if problems:
        print("\n".join(problems))
        sys.exit(1)
    print(f"{len(used)} texts, all present in {' and '.join(LANGUAGES)}")


if __name__ == "__main__":
    main()
