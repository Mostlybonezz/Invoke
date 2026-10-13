#!/usr/bin/env python3
"""Create an AltStore-compatible source from a compiled Invoke IPA.

The output is published as a GitHub Release asset. Do not run against a source
archive: version, bundle identifier, minimum OS and permissions come from the
compiled app's Info.plist, and download size comes from the actual IPA.
"""

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import plistlib
import re
import sys
from urllib.parse import quote
import zipfile


def build_source(ipa, repository, tag, date, entitlements=None):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("repository must be owner/repository")
    if not re.fullmatch(r"v\d+\.\d+\.\d+", tag):
        raise ValueError("tag must be vMAJOR.MINOR.PATCH")
    if ipa.suffix.lower() != ".ipa":
        raise ValueError("input must be a compiled .ipa")

    with zipfile.ZipFile(ipa) as archive:
        info_paths = [name for name in archive.namelist()
                      if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", name)]
        if len(info_paths) != 1:
            raise ValueError("IPA must contain exactly one Payload/*.app/Info.plist")
        info = plistlib.loads(archive.read(info_paths[0]))
        executable = info_paths[0].rsplit("/", 1)[0] + "/" + info.get("CFBundleExecutable", "")
        if executable not in archive.namelist():
            raise ValueError("IPA is missing its declared app executable")
        if info.get("CFBundleSupportedPlatforms") != ["iPhoneOS"]:
            raise ValueError("IPA must contain an iPhoneOS device build, not a simulator build")

    required = ("CFBundleIdentifier", "CFBundleShortVersionString", "CFBundleVersion", "MinimumOSVersion")
    for key in required:
        if not isinstance(info.get(key), str) or not info[key] or "$" in info[key]:
            raise ValueError(f"Compiled Info.plist has missing/unresolved {key}")
    if info["CFBundleShortVersionString"] != tag[1:]:
        raise ValueError("release tag does not match the compiled app version")

    root_url = f"https://github.com/{repository}"
    release_url = f"{root_url}/releases/download/{quote(tag, safe='')}"
    icon_url = (f"https://raw.githubusercontent.com/{repository}/{quote(tag, safe='')}/"
                "Invoke/Assets.xcassets/AppIcon.appiconset/Invoke.png")
    download_url = f"{release_url}/{quote(ipa.name, safe='')}"
    size = ipa.stat().st_size
    privacy = {key: value for key, value in info.items()
               if key.startswith("NS") and key.endswith("UsageDescription") and isinstance(value, str)}
    entitlements = entitlements or {}
    # AltStore documents these as universal signing metadata, not permissions.
    universal = {"application-identifier", "com.apple.developer.team-identifier",
                 "com.app.developer.team-identifier"}
    permission_names = sorted(key for key, value in entitlements.items()
                              if key not in universal and value is not False)
    version = {
        "version": info["CFBundleShortVersionString"],
        "buildVersion": info["CFBundleVersion"],
        "date": date,
        "localizedDescription": "Invoke iPhone release for LiveContainer or a compatible sideloading tool.",
        "downloadURL": download_url,
        "size": size,
        "minOSVersion": info["MinimumOSVersion"],
    }
    app = {
        "name": info.get("CFBundleDisplayName", "Invoke"),
        "bundleIdentifier": info["CFBundleIdentifier"],
        "developerName": repository.split("/", 1)[0],
        "subtitle": "A personal sanctuary for your next chapter",
        "localizedDescription": (
            "Organize stories, beliefs, manifestations, rituals, scenes, and physical relics. "
            "Three native themes, local storage, and portable backups. Requires iOS 17 or later. "
            "This IPA requires LiveContainer or re-signing with a compatible sideloading tool; "
            "Safari cannot install it directly."
        ),
        "iconURL": icon_url,
        "tintColor": "#6C2938",
        "category": "lifestyle",
        "versions": [version],
        "appPermissions": {"entitlements": permission_names, "privacy": privacy},
        # Keep the legacy single-version fields for basic AltSource clients.
        "version": version["version"],
        "versionDate": date,
        "versionDescription": version["localizedDescription"],
        "downloadURL": download_url,
        "size": size,
        "minOSVersion": version["minOSVersion"],
    }
    return {
        "name": "Invoke",
        "identifier": f"io.github.{repository.replace('/', '.').lower()}",
        "subtitle": "Invoke releases for iPhone",
        "description": "Official Invoke builds published from this repository's GitHub Actions workflow.",
        "website": root_url,
        "iconURL": icon_url,
        "tintColor": "#6C2938",
        "apps": [app],
        "news": [],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ipa", type=Path, required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--date", default=datetime.now(timezone.utc).date().isoformat())
    parser.add_argument("--entitlements", type=Path,
                        help="Optional entitlements plist extracted from the final signed app")
    args = parser.parse_args()
    try:
        datetime.fromisoformat(args.date.replace("Z", "+00:00"))
        entitlements = plistlib.loads(args.entitlements.read_bytes()) if args.entitlements else {}
        source = build_source(args.ipa, args.repository, args.tag, args.date, entitlements)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(source, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    except (OSError, ValueError, KeyError, zipfile.BadZipFile, plistlib.InvalidFileException) as error:
        print(f"Source generation failed: {error}", file=sys.stderr)
        return 1
    app = source["apps"][0]
    print(f"Created {args.output}: {app['bundleIdentifier']} {app['version']}, {app['size']} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
