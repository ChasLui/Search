#!/usr/bin/env python3
"""Check translated resources and list new interface strings for review."""

import argparse
import json
import plistlib
import re
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RESOURCES = ROOT / "Sources/Search/Resources"
LANGUAGES = ("en", "zh-Hans")
FORMAT = re.compile(r"%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?(?:hh|ll|h|l|z|t|j)?[@diuoxXfFeEgGaAcCsSp%]")
UI_LITERAL = re.compile(
    r'\b(?:Text|Button|Menu|Pill|Line|Door|Caption|Nothing|Label|Toggle|Picker|TextField|SecureField|'
    r'announce|help|accessibilityLabel|accessibilityHint|Ask\.name|Ask\.sure)\(\s*"((?:\\.|[^"\\])*)"'
)
RESOURCE_KEY = re.compile(
    r'(?:(?:Language\.shared|language)\.(?:text|format)\(\s*|localizedKey:\s*)"([a-z][a-z0-9_.-]+)"'
)


def strings(path):
    output = subprocess.check_output(["plutil", "-convert", "json", "-o", "-", str(path)])
    return json.loads(output)


def formats(value):
    return sorted(token for token in FORMAT.findall(value) if token != "%%")


def review_changes(base):
    diff = subprocess.check_output(
        ["git", "diff", "--no-ext-diff", "--no-color", "--unified=0", base, "--", "Sources/Search"],
        cwd=ROOT, text=True,
    )
    path = ""
    for line in diff.splitlines():
        if line.startswith("+++ b/"):
            path = line[6:]
        elif line.startswith("+") and not line.startswith("+++"):
            for match in UI_LITERAL.finditer(line):
                value = match.group(1)
                if not value.startswith("ui.") and re.search(r"[A-Za-z\u4e00-\u9fff]", value):
                    print(f"Review new interface text in {path}: {value}")

    old = {}
    for language in LANGUAGES:
        path = f"Sources/Search/Resources/{language}.lproj/Localizable.strings"
        result = subprocess.run(["git", "show", f"{base}:{path}"], cwd=ROOT, capture_output=True)
        if result.returncode == 0:
            output = subprocess.run(["plutil", "-convert", "json", "-o", "-", "-"],
                                    input=result.stdout, capture_output=True, check=True)
            old[language] = json.loads(output.stdout)
    if len(old) == 2:
        current = {language: strings(RESOURCES / f"{language}.lproj/Localizable.strings") for language in LANGUAGES}
        for key in sorted(current["en"].keys() - old["en"].keys()):
            print(f"Review added English resource: {key}")
        for key in sorted(old["en"].keys() - current["en"].keys()):
            print(f"Review removed English resource: {key}")
        for key in sorted(current["en"].keys() & old["en"].keys()):
            if current["en"][key] != old["en"][key] and current["zh-Hans"].get(key) == old["zh-Hans"].get(key):
                print(f"Review Chinese translation after English changed: {key}")

    old_plurals = {}
    for language in LANGUAGES:
        path = f"Sources/Search/Resources/{language}.lproj/Localizable.stringsdict"
        result = subprocess.run(["git", "show", f"{base}:{path}"], cwd=ROOT, capture_output=True)
        if result.returncode == 0:
            old_plurals[language] = plistlib.loads(result.stdout)
    if len(old_plurals) == 2:
        current_plurals = {}
        for language in LANGUAGES:
            with (RESOURCES / f"{language}.lproj/Localizable.stringsdict").open("rb") as source:
                current_plurals[language] = plistlib.load(source)
        for key in sorted(current_plurals["en"].keys() - old_plurals["en"].keys()):
            print(f"Review added English plural: {key}")
        for key in sorted(old_plurals["en"].keys() - current_plurals["en"].keys()):
            print(f"Review removed English plural: {key}")
        for key in sorted(current_plurals["en"].keys() & old_plurals["en"].keys()):
            if (current_plurals["en"][key] != old_plurals["en"][key]
                    and current_plurals["zh-Hans"].get(key) == old_plurals["zh-Hans"].get(key)):
                print(f"Review Chinese plural after English changed: {key}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", help="also list interface text and English changes since this Git revision")
    args = parser.parse_args()
    resources = {language: strings(RESOURCES / f"{language}.lproj/Localizable.strings") for language in LANGUAGES}
    english, chinese = resources["en"], resources["zh-Hans"]
    errors = []
    for language in LANGUAGES:
        path = RESOURCES / f"{language}.lproj/Localizable.strings"
        seen = set()
        for encoded in re.findall(r'^\s*("(?:\\.|[^"\\])*")\s*=', path.read_text(), re.MULTILINE):
            try:
                key = json.loads(encoded)
            except json.JSONDecodeError:
                errors.append(f"String key needs manual review in {language}: {encoded}")
                continue
            if key in seen:
                errors.append(f"Duplicate key in {language}: {key}")
            seen.add(key)
    for key in sorted(english.keys() ^ chinese.keys()):
        errors.append(f"Missing translation for {key}")
    for key in sorted(english.keys() & chinese.keys()):
        if formats(english[key]) != formats(chinese[key]):
            errors.append(f"Different format arguments for {key}")

    plurals = {}
    for language in LANGUAGES:
        path = RESOURCES / f"{language}.lproj/Localizable.stringsdict"
        for dictionary in ET.parse(path).iter("dict"):
            seen = set()
            for child in dictionary:
                if child.tag != "key":
                    continue
                if child.text in seen:
                    errors.append(f"Duplicate plural key in {language}: {child.text}")
                seen.add(child.text)
        with path.open("rb") as source:
            plurals[language] = plistlib.load(source)
    if plurals["en"].keys() != plurals["zh-Hans"].keys():
        errors.append("Plural keys differ between languages")
    for key in plurals["en"].keys() & plurals["zh-Hans"].keys():
        for language in LANGUAGES:
            entry = plurals[language][key]
            if entry.get("NSStringLocalizedFormatKey") != "%#@count@" or "other" not in entry.get("count", {}):
                errors.append(f"Invalid plural entry {language}: {key}")
            elif entry["count"].get("NSStringFormatValueTypeKey") != "ld":
                errors.append(f"Invalid plural argument {language}: {key}")
            elif entry["count"].get("NSStringFormatSpecTypeKey") != "NSStringPluralRuleType":
                errors.append(f"Invalid plural rule {language}: {key}")
            else:
                for category in ("zero", "one", "two", "few", "many", "other"):
                    if category in entry["count"] and formats(entry["count"][category]) not in ([], ["%ld"]):
                        errors.append(f"Invalid plural format {language}: {key}.{category}")

    for path in (ROOT / "Sources/Search").glob("*.swift"):
        source = path.read_text()
        for key in set(RESOURCE_KEY.findall(source)):
            if "." in key and key not in english:
                errors.append(f"Missing resource {key} in {path.relative_to(ROOT)}")
        for key in re.findall(r'"(ui\.[a-z0-9_.-]+)"', source):
            if key != "ui.language" and key not in english:
                errors.append(f"Missing resource {key} in {path.relative_to(ROOT)}")
        for key in re.findall(r'"(count\.[a-z0-9_.-]+)"', source):
            if key not in plurals["en"]:
                errors.append(f"Missing plural resource {key} in {path.relative_to(ROOT)}")
    updates = (ROOT / "Sources/Search/WhatsNew.swift").read_text()
    toggle_entries = re.findall(
        r'Toggle\(key: "([a-z0-9_]+)", title: "([^"\n]*)", detail: "([^"\n]*)"', updates
    )
    if len(toggle_entries) != updates.count("Toggle(key:"):
        errors.append("An update-card entry needs manual localization review")
    for key, title, detail in toggle_entries:
        for field, value in (("title", title), ("detail", detail)):
            resource = f"whatsnew.toggle.{key}.{field}"
            if english.get(resource) != value:
                errors.append(f"Update-card English changed or is missing: {resource}")

    notes = updates.split("static let notes: [Notes] = [", 1)[1].split("\n    ]", 1)[0]
    version = section = None
    position = 0
    for line in notes.splitlines():
        found = re.search(r'version: "([^"]+)", date: ', line)
        if found:
            version, section = found.group(1), None
        found = re.search(r'headline: "([^"\n]*)"', line)
        if "headline:" in line and not found:
            errors.append(f"Release-note headline needs manual localization review: {version}")
        if found:
            resource = f"whatsnew.notes.{version}.headline"
            if english.get(resource) != found.group(1):
                errors.append(f"Release-note English changed or is missing: {resource}")
        found = re.match(r'\s*(new|better|fixed): \[', line)
        if found:
            section, position = found.group(1), 0
            continue
        found = re.match(r'\s*("(?:\\.|[^"\\])+")[,]?\s*$', line)
        if found and section:
            resource = f"whatsnew.notes.{version}.{section}.{position}"
            try:
                source = json.loads(found.group(1))
            except json.JSONDecodeError:
                errors.append(f"Release-note line needs manual localization review: {resource}")
                position += 1
                continue
            if english.get(resource) != source:
                errors.append(f"Release-note English changed or is missing: {resource}")
            position += 1
        elif section and line.lstrip().startswith('"'):
            errors.append(f"Release-note line needs manual localization review: {version}.{section}.{position}")
    for error in errors:
        print(error)
    if args.base:
        review_changes(args.base)
    if errors:
        raise SystemExit(1)
    print(f"Checked {len(english)} strings and {len(plurals['en'])} plural entries in both languages.")


if __name__ == "__main__":
    main()
