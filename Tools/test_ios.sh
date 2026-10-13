#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
developer_dir="$(python3 Tools/select_xcode.py --print-path)"
export DEVELOPER_DIR="$developer_dir"

# Require exact iOS 27.0 while retaining the app's iOS 17 minimum.
xcrun simctl list devices available --json > build/simulators.json
xcrun simctl list runtimes --json > build/simulator-runtimes.json
simulator_id="$(python3 - <<'PY'
import json
from pathlib import Path

devices = json.load(open('build/simulators.json'))['devices']
runtimes = json.load(open('build/simulator-runtimes.json'))['runtimes']
required_runtime = 'com.apple.CoreSimulator.SimRuntime.iOS-27-0'
runtime = next((item for item in runtimes if item['identifier'] == required_runtime
                and item.get('isAvailable') and item.get('version') == '27.0'), None)
if runtime is None:
    raise SystemExit('Required available iOS 27.0 simulator runtime is missing. No older OS was used.')
candidates = [item for item in devices.get(required_runtime, [])
              if item.get('isAvailable') and item['name'].startswith('iPhone')]
if not candidates:
    raise SystemExit('No available iPhone simulator running exact iOS 27.0 was found.')
device = sorted(candidates, key=lambda item: (item['name'], item['udid']))[0]
metadata = {'runtimeIdentifier': required_runtime, 'runtimeVersion': runtime['version'],
            'runtimeBuild': runtime.get('buildversion'), 'deviceName': device['name'],
            'deviceUDID': device['udid'], 'deviceTypeIdentifier': device.get('deviceTypeIdentifier'),
            'sdkName': 'iphonesimulator27.0', 'testStatus': 'pending',
            'nativeLaunchScreenshot': 'pending'}
Path('build/simulator-info.json').write_text(json.dumps(metadata, indent=2) + '\n')
print(device['udid'])
PY
)"
echo "Testing on iOS 27.0 simulator $simulator_id using iphonesimulator27.0"
xcodebuild test \
  -project Invoke.xcodeproj -scheme Invoke -configuration Debug \
  -sdk iphonesimulator27.0 \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -destination-timeout 180 \
  -derivedDataPath build/SimulatorDerivedData \
  -resultBundlePath build/TestResults.xcresult \
  -parallel-testing-enabled NO \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 \
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
metadata_path = Path('build/simulator-info.json')
metadata = json.loads(metadata_path.read_text())
metadata['testStatus'] = 'passed'
metadata['nativeLaunchScreenshot'] = 'Invoke-first-launch.png'
metadata_path.write_text(json.dumps(metadata, indent=2) + '\n')
PY
