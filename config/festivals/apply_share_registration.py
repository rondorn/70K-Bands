#!/usr/bin/env python3
"""Apply share-file OS registration from a festival JSON file.

iOS Info.plist document types / UTIs and Android flavor intent filters are not
read from JSON at runtime. This script writes them at build time so a new
festival cannot ship with a mismatched or missing .xyzshare handler.

Usage:
  apply_share_registration.py --festival-json mmf.json --ios-plist Info.plist
  apply_share_registration.py --festival-json mmf.json --android-manifest AndroidManifest.xml
"""

from __future__ import annotations

import argparse
import json
import plistlib
import re
import sys
from pathlib import Path
from urllib.parse import urlparse
from xml.sax.saxutils import escape


def load_festival(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    for key in ("shareFileExtension", "shareTypeIdentifier", "shareMimeType", "appName"):
        value = data.get(key)
        if not isinstance(value, str) or not value.strip():
            raise SystemExit(f"{path}: missing required share field {key!r}")
    ext = data["shareFileExtension"].strip().lstrip(".")
    if not re.fullmatch(r"[A-Za-z0-9]+", ext):
        raise SystemExit(f"{path}: invalid shareFileExtension {ext!r}")
    data["shareFileExtension"] = ext
    return data


def apply_ios_plist(plist_path: Path, festival: dict) -> None:
    with plist_path.open("rb") as handle:
        plist = plistlib.load(handle)

    ext = festival["shareFileExtension"]
    uti = festival["shareTypeIdentifier"].strip()
    mime = festival["shareMimeType"].strip()
    desc = f"{festival['appName'].strip()} Shared Preferences"

    plist["CFBundleDocumentTypes"] = [
        {
            "CFBundleTypeExtensions": [ext],
            "CFBundleTypeName": desc,
            "CFBundleTypeRole": "Editor",
            "LSHandlerRank": "Owner",
            "LSIsAppleDefaultForType": True,
            "LSItemContentTypes": [uti],
            "LSSupportsOpeningDocumentsInPlace": True,
        }
    ]
    plist["LSSupportsOpeningDocumentsInPlace"] = True
    plist["QLSupportedContentTypes"] = [uti]

    exported = {
        "UTTypeIdentifier": uti,
        "UTTypeDescription": desc,
        "UTTypeConformsTo": ["public.json", "public.text"],
        "UTTypeIconFiles": [],
        "UTTypeTagSpecification": {
            "public.filename-extension": [ext],
            "public.mime-type": ["application/json", mime],
        },
    }
    imported = {key: value for key, value in exported.items() if key != "UTTypeIconFiles"}
    plist["UTExportedTypeDeclarations"] = [exported]
    plist["UTImportedTypeDeclarations"] = [imported]

    with plist_path.open("wb") as handle:
        plistlib.dump(plist, handle, fmt=plistlib.FMT_XML, sort_keys=False)


def _path_patterns(ext: str) -> list[str]:
    return [
        f".*\\\\.{ext}",
        f".*\\\\.{ext}.*",
        f".*\\\\..*\\\\.{ext}",
        f".*\\\\..*\\\\..*\\\\.{ext}",
    ]


def _intent_filter(body: str) -> str:
    return (
        '            <intent-filter android:label="@string/app_name">\n'
        f"{body}"
        "            </intent-filter>\n"
    )


def _data_lines(attrs: list[str]) -> str:
    return "".join(f"                <data {attr} />\n" for attr in attrs)


def android_manifest_xml(festival: dict) -> str:
    ext = festival["shareFileExtension"]
    mime = escape(festival["shareMimeType"].strip(), {"\"": "&quot;"})
    patterns = _path_patterns(ext)
    common_actions = (
        '                <action android:name="android.intent.action.VIEW" />\n'
        '                <action android:name="android.intent.action.EDIT" />\n'
        '                <action android:name="android.intent.action.PICK" />\n'
        '                <category android:name="android.intent.category.DEFAULT" />\n'
        '                <category android:name="android.intent.category.BROWSABLE" />\n'
    )

    filters = [
        _intent_filter(
            common_actions
            + _data_lines(['android:scheme="file"', 'android:host="*"'] + [f'android:pathPattern="{p}"' for p in patterns])
        ),
        _intent_filter(
            common_actions
            + _data_lines(['android:scheme="content"', 'android:host="*"'] + [f'android:pathPattern="{p}"' for p in patterns])
        ),
        _intent_filter(
            common_actions
            + _data_lines(
                [
                    'android:scheme="file"',
                    'android:scheme="content"',
                    'android:mimeType="*/*"',
                    f'android:pathPattern="{patterns[0]}"',
                ]
            )
        ),
        _intent_filter(
            '                <action android:name="android.intent.action.VIEW" />\n'
            '                <action android:name="android.intent.action.SEND" />\n'
            '                <category android:name="android.intent.category.DEFAULT" />\n'
            '                <category android:name="android.intent.category.BROWSABLE" />\n'
            + _data_lines([f'android:mimeType="{mime}"'])
        ),
    ]

    guide = (festival.get("scheduleQRGuideURL") or "").strip()
    if guide:
        parsed = urlparse(guide)
        if not parsed.scheme:
            raise SystemExit(f"scheduleQRGuideURL is not a valid URL: {guide!r}")
        quote = {"\"": "&quot;"}
        scheme = escape(parsed.scheme, quote)
        host_attr = f' android:host="{escape(parsed.netloc, quote)}"' if parsed.netloc else ""
        filters.append(
            _intent_filter(
                '                <action android:name="android.intent.action.VIEW" />\n'
                '                <category android:name="android.intent.category.DEFAULT" />\n'
                '                <category android:name="android.intent.category.BROWSABLE" />\n'
                + _data_lines([f'android:scheme="{scheme}"{host_attr}'])
            )
        )

    body = "".join(filters)
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
        "    <!-- Generated from festival JSON by apply_share_registration.py. Do not edit. -->\n"
        "    <application>\n"
        '        <activity android:name=".showBands">\n'
        f"{body}"
        "        </activity>\n"
        "    </application>\n"
        "</manifest>\n"
    )


def apply_android_manifest(manifest_path: Path, festival: dict) -> None:
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(android_manifest_xml(festival), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--festival-json", required=True, type=Path)
    parser.add_argument("--ios-plist", type=Path)
    parser.add_argument("--android-manifest", type=Path)
    args = parser.parse_args()

    if args.ios_plist is None and args.android_manifest is None:
        parser.error("pass --ios-plist and/or --android-manifest")

    festival = load_festival(args.festival_json)
    if args.ios_plist is not None:
        if not args.ios_plist.is_file():
            raise SystemExit(f"iOS Info.plist not found: {args.ios_plist}")
        apply_ios_plist(args.ios_plist, festival)
        print(f"✅ Share types written to {args.ios_plist} ({festival['shareFileExtension']})")
    if args.android_manifest is not None:
        apply_android_manifest(args.android_manifest, festival)
        print(f"✅ Share intent filters written to {args.android_manifest} ({festival['shareFileExtension']})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
