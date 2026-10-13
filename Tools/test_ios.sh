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

# Capture the actual native first launch after the tests pass. Every simulator
# command has a timeout so a stalled simulator cannot hold CI indefinitely.
python3 - "$simulator_id" <<'PY'
import json
from pathlib import Path
import subprocess
import sys
import time

simulator = sys.argv[1]
app = Path('build/SimulatorDerivedData/Build/Products/Debug-iphonesimulator/Invoke.app')
if not app.is_dir():
    raise SystemExit(f'Simulator app was not built: {app}')
devices = json.loads(subprocess.check_output(
    ['xcrun', 'simctl', 'list', 'devices', '--json'], text=True, timeout=30))['devices']
device = next(item for entries in devices.values() for item in entries if item['udid'] == simulator)
if device['state'] != 'Booted':
    subprocess.run(['xcrun', 'simctl', 'boot', simulator], check=True, timeout=30)
subprocess.run(['xcrun', 'simctl', 'bootstatus', simulator, '-b'], check=True, timeout=120)
subprocess.run(['xcrun', 'simctl', 'install', simulator, str(app)], check=True, timeout=60)
subprocess.run(['xcrun', 'simctl', 'launch', '--terminate-running-process', simulator,
                'app.invoke.personal'], check=True, timeout=30)
time.sleep(8)
subprocess.run(['xcrun', 'simctl', 'io', simulator, 'screenshot',
                'build/Invoke-first-launch.png'], check=True, timeout=30)
print('Native launch screenshot saved to build/Invoke-first-launch.png')
PY
