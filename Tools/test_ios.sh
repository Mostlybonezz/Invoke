#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build

# Use an installed iPhone rather than pinning a model or simulator OS.
xcrun simctl list devices available --json > build/simulators.json
simulator_id="$(python3 - <<'PY'
import json
import re
import subprocess

devices = json.load(open('build/simulators.json'))['devices']
sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version'], text=True).strip()
sdk_version = tuple(int(part) for part in sdk.split('.')[:2])
candidates = []
for runtime, entries in devices.items():
    match = re.search(r'iOS-(\d+)-(\d+)', runtime)
    if not match or int(match[1]) < 17:
        continue
    runtime_version = (int(match[1]), int(match[2]))
    if runtime_version > sdk_version:
        continue
    for device in entries:
        if device.get('isAvailable') and device['name'].startswith('iPhone'):
            candidates.append((runtime_version, device['name'], device['udid']))
if not candidates:
    raise SystemExit('No available iPhone simulator running iOS 17+ was found.')
print(max(candidates)[2])
PY
)"
echo "Testing on simulator $simulator_id"
xcodebuild test \
  -project Invoke.xcodeproj -scheme Invoke -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -destination-timeout 180 \
  -derivedDataPath build/SimulatorDerivedData \
  -resultBundlePath build/TestResults.xcresult \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= \
  2>&1 | tee build/tests.log
