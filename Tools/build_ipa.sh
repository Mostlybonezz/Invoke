#!/bin/bash
# Builds an arm64 iOS app and applies a local ad-hoc signature for sideload tools.
# This does not produce Apple-provisioned or App Store distribution signing.
set -euo pipefail
cd "$(dirname "$0")/.."
project_root="$PWD"
version="${INVOKE_VERSION:-2.0.0}"
build_number="${INVOKE_BUILD_NUMBER:-1}"
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$build_number" =~ ^[1-9][0-9]*$ ]]; then
  echo "Expected INVOKE_VERSION=major.minor.patch and positive INVOKE_BUILD_NUMBER." >&2
  exit 1
fi
if [[ "$(uname -s)" != Darwin ]]; then
  echo "IPA compilation requires macOS, Xcode 27.0, and iOS 27.0 SDKs. Use GitHub Actions on Windows." >&2
  exit 1
fi
mkdir -p build/release
# Source-derived counts and retained screenshots prevent publishing a partial suite.
python3 Tools/verify_test_evidence.py

developer_dir="$(python3 Tools/select_xcode.py --print-path)"
export DEVELOPER_DIR="$developer_dir"
plutil -lint Invoke.xcodeproj/project.pbxproj
xcodebuild -version | tee build/xcode-version.txt
xcodebuild build \
  -project Invoke.xcodeproj -scheme Invoke -configuration Release \
  -sdk iphoneos27.0 -destination 'generic/platform=iOS' \
  -derivedDataPath build/DeviceDerivedData \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 \
  MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$build_number" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= \
  2>&1 | tee build/device-build.log

app="$project_root/build/DeviceDerivedData/Build/Products/Release-iphoneos/Invoke.app"
test -f "$app/Info.plist"
executable="$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$app/Info.plist")"
xcrun lipo "$app/$executable" -verify_arch arm64
test -f "$app/default.metallib"

# Nested executable bundles must be signed before the containing app.
if [[ -d "$app/Frameworks" ]]; then
  while IFS= read -r -d '' item; do
    codesign --force --sign - --timestamp=none "$item"
  done < <(find "$app/Frameworks" -depth \( -name '*.framework' -o -name '*.dylib' \) -print0)
fi
codesign --force --sign - --timestamp=none "$app"
codesign --verify --deep --strict "$app"

package_dir="$(mktemp -d "${TMPDIR:-/tmp}/invoke-package.XXXXXX")"
trap 'rm -rf "$package_dir"' EXIT
mkdir "$package_dir/Payload"
ditto "$app" "$package_dir/Payload/Invoke.app"
ditto -c -k --norsrc --keepParent "$package_dir/Payload" "$project_root/build/release/Invoke.ipa"
cp Invoke/Assets.xcassets/AppIcon.appiconset/Invoke.png build/release/icon.png

python3 - <<'PY'
import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import zipfile

output = Path('build/release')
ipa = output / 'Invoke.ipa'
with zipfile.ZipFile(ipa) as archive:
    info = plistlib.loads(archive.read('Payload/Invoke.app/Info.plist'))
    assert info['CFBundleIdentifier'] == 'app.invoke.personal', info
    assert info['CFBundlePackageType'] == 'APPL', info
    assert info['MinimumOSVersion'] == '17.0', info
    assert info['DTSDKName'] == 'iphoneos27.0', info
    assert 'Payload/Invoke.app/Invoke' in archive.namelist()
    assert all(name.startswith('Payload/') for name in archive.namelist())
    assert not any(name.endswith('embedded.mobileprovision') for name in archive.namelist())
digest = hashlib.sha256(ipa.read_bytes()).hexdigest()
(output / 'Invoke.ipa.sha256').write_text(f'{digest}  Invoke.ipa\n')
toolchain = json.loads(Path('build/toolchain.json').read_text())
validation = json.loads(Path('build/validation-evidence.json').read_text())
simulator = validation['simulatorValidation']
test_summary = validation['testResults']
ui_screenshots = validation['nativeUIScreenshots']
metadata = {
    'app': info['CFBundleDisplayName'],
    'bundleIdentifier': info['CFBundleIdentifier'],
    'version': info['CFBundleShortVersionString'],
    'buildNumber': info['CFBundleVersion'],
    'minimumOSVersion': info['MinimumOSVersion'],
    'architecture': 'arm64',
    'signature': 'local ad-hoc; no Apple provisioning profile',
    'sourceCommit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
    'builtAtUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'sha256': digest,
    'bytes': ipa.stat().st_size,
    'xcode': Path('build/xcode-version.txt').read_text().strip(),
    'toolchain': toolchain,
    'deviceSDK': {'name': info['DTSDKName'], 'build': info.get('DTSDKBuild'),
                  'version': toolchain['sdks']['iphoneos']['version']},
    'simulatorValidation': simulator,
    'testResults': test_summary,
    'authoredTests': validation['authoredTests'],
    'nativeUIScreenshots': ui_screenshots,
    'workflowRun': os.environ.get('GITHUB_RUN_ID'),
    'deviceValidation': 'Not performed by CI; test on the intended iPhone and LiveContainer version.',
    'intendedHost': {'name': 'LiveContainer', 'ownerReportedVersion': '3.8.10',
                     'physicalRuntimeValidation': 'Not performed; exact host build and signing mode unverified.'},
}
(output / 'build-info.json').write_text(json.dumps(metadata, indent=2) + '\n')
print(json.dumps(metadata, indent=2))
PY
