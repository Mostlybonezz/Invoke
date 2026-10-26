#!/bin/bash
# Keep this script in LF format for the macOS build runner.
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
echo "Testing on exact iOS 27.0 simulator $simulator_id with a 25-minute suite deadline"
python3 - "$simulator_id" <<'PY'
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

simulator = sys.argv[1]

def diagnostics(reason):
    print(f'Simulator diagnostic capture: {reason}', flush=True)
    commands = [
        ('build/simulator-state-failure.log', ['xcrun', 'simctl', 'list', 'devices', '--json'], 30),
        ('build/simulator-error-failure.log', ['xcrun', 'simctl', 'spawn', simulator, 'log', 'show',
          '--last', '5m', '--style', 'compact', '--predicate',
          'process == "testmanagerd" OR eventMessage CONTAINS[c] "failed" OR eventMessage CONTAINS[c] "error"'], 45),
        ('build/simulator-processes-failure.log', ['ps', '-axo', 'pid,ppid,etime,stat,comm'], 15),
    ]
    for name, command, timeout in commands:
        with open(name, 'w') as log:
            log.write(reason + '\n')
            log.flush()
            try:
                result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
                print(f'{name}: command exit {result.returncode}', flush=True)
            except (OSError, subprocess.TimeoutExpired) as error:
                log.write(f'\nDiagnostic command did not complete: {error}\n')
                print(f'{name}: {error}', flush=True)

def signal_process_group(process, signal_number):
    try:
        os.killpg(process.pid, signal_number)
    except ProcessLookupError:
        pass  # The process may finish just before the timeout signal.

command = [
    'xcodebuild', 'test', '-project', 'Invoke.xcodeproj', '-scheme', 'Invoke',
    '-configuration', 'Debug', '-sdk', 'iphonesimulator27.0',
    '-destination', f'platform=iOS Simulator,id={simulator}', '-destination-timeout', '180',
    '-derivedDataPath', 'build/SimulatorDerivedData', '-resultBundlePath', 'build/TestResults.xcresult',
    '-parallel-testing-enabled', 'NO', '-test-timeouts-enabled', 'YES',
    '-default-test-execution-time-allowance', '240', '-maximum-test-execution-time-allowance', '300',
    'IPHONEOS_DEPLOYMENT_TARGET=17.0', 'CODE_SIGNING_ALLOWED=NO',
    'CODE_SIGNING_REQUIRED=NO', 'CODE_SIGN_IDENTITY=',
]
started = time.monotonic()
timed_out = False
with open('build/tests.log', 'wb') as log, open('build/tests.log', 'r', errors='replace') as reader:
    process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    while process.poll() is None:
        output = reader.read()
        if output:
            print(output, end='', flush=True)
        if time.monotonic() - started >= 1500:
            timed_out = True
            print('\nXCTest exceeded the 25-minute wall-clock limit; interrupting to preserve xcresult.', flush=True)
            signal_process_group(process, signal.SIGINT)
            try:
                process.wait(timeout=30)
            except subprocess.TimeoutExpired:
                signal_process_group(process, signal.SIGTERM)
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    signal_process_group(process, signal.SIGKILL)
                    process.wait(timeout=10)
            break
        time.sleep(0.5)
    print(reader.read(), end='', flush=True)
return_code = 124 if timed_out else process.returncode
if return_code:
    diagnostics(f'xcodebuild test exited {return_code}; elapsed {time.monotonic() - started:.0f}s')
    raise SystemExit(return_code if return_code > 0 else 1)
print(f'All tests completed successfully in {time.monotonic() - started:.0f}s.', flush=True)
# Successful XCUITest flows already launched Invoke and retained native screenshots.
# The next CI step exports them; build_ipa.sh verifies those files and the test summary.
metadata_path = Path('build/simulator-info.json')
metadata = json.loads(metadata_path.read_text())
metadata['testStatus'] = 'passed'
metadata['nativeLaunchScreenshot'] = 'XCTest attachments'
metadata['nativeLaunchValidation'] = 'XCTest passed; retained UI evidence is verified before packaging'
metadata_path.write_text(json.dumps(metadata, indent=2) + '\n')
PY
