"""Fail packaging unless the exact authored XCTest suite and UI evidence passed.

The expected total comes from the checked-out test sources, not a stale release
constant. Project checks separately require each test source in a compile phase.
Every UI test must retain a successful PNG so a skipped launch cannot masquerade
as native UI validation. This does not establish physical LiveContainer support.
"""
from pathlib import Path
import argparse
import json
import re
import sys


def expected_tests(root):
    result = {"unit": [], "ui": []}
    for kind, folder in (("unit", "InvokeTests"), ("ui", "InvokeUITests")):
        for path in sorted((root / folder).rglob('*.swift')):
            text = path.read_text(encoding='utf-8')
            classes = list(re.finditer(r'\bclass\s+(\w+)\s*:\s*XCTestCase\b', text))
            for method in re.finditer(r'\bfunc\s+(test\w+)\s*\(', text):
                enclosing = [item for item in classes if item.start() < method.start()]
                if not enclosing:
                    raise ValueError(f'Test method has no XCTestCase class: {path.name}:{method[1]}')
                identifier = f'{enclosing[-1][1]}/{method[1]}()'
                if identifier in result[kind]:
                    raise ValueError(f'Duplicate authored test: {identifier}')
                result[kind].append(identifier)
    return result


def validate(root, build):
    expected = expected_tests(root)
    contract = json.loads((root / 'Tools/test_contract.json').read_text(encoding='utf-8'))
    if contract.get('schemaVersion') != 1:
        raise ValueError('Unknown native-test contract version')
    for kind, key in (('unit', 'minimumUnitTests'), ('ui', 'minimumUITests')):
        if len(expected[kind]) < contract[key]:
            raise ValueError(f'The {kind} test suite fell below the release contract')
    simulator = json.loads((build / 'simulator-info.json').read_text())
    if simulator.get('runtimeVersion') != '27.0' or simulator.get('testStatus') != 'passed':
        raise ValueError('Native test execution did not pass on exact iOS 27.0')
    summary = json.loads((build / 'test-summary.json').read_text())
    expected_count = sum(len(items) for items in expected.values())
    if (summary.get('result') != 'Passed' or summary.get('passedTests') != expected_count
            or summary.get('totalTestCount') != expected_count
            or summary.get('failedTests') != 0 or summary.get('skippedTests') != 0):
        raise ValueError(f'All {expected_count} authored tests must pass with zero failures/skips; '
                         f'actual result={summary.get("result")}, passed={summary.get("passedTests")}, '
                         f'total={summary.get("totalTestCount")}, failed={summary.get("failedTests")}, '
                         f'skipped={summary.get("skippedTests")}')
    devices = summary.get('devicesAndConfigurations', [])
    if not devices or any(item.get('device', {}).get('osVersion') != '27.0' for item in devices):
        raise ValueError('Test summary does not establish exact iOS 27.0 for every test device')

    directory = build / 'ui-screenshots'
    manifest = json.loads((directory / 'manifest.json').read_text())
    screenshots = []
    for test in manifest:
        for attachment in test.get('attachments', []):
            filename = attachment.get('exportedFileName', '')
            if (not filename.endswith('.png') or '/' in filename or '\\' in filename
                    or Path(filename).name != filename or attachment.get('isAssociatedWithFailure')):
                continue
            screenshot = directory / filename
            if not screenshot.is_file() or screenshot.read_bytes()[:8] != b'\x89PNG\r\n\x1a\n':
                continue
            screenshots.append({
                'testIdentifier': test['testIdentifier'],
                'name': attachment.get('suggestedHumanReadableName', ''),
                'exportedFileName': filename,
                'deviceName': attachment.get('deviceName'),
            })
    observed = {item['testIdentifier'] for item in screenshots}
    missing_flows = set(expected['ui']) - observed
    if missing_flows:
        raise ValueError(f'Missing retained screenshots from UI flows: {sorted(missing_flows)}')
    for name in contract['requiredScreenshots']:
        if not any(item['name'] == name or item['name'].startswith(name + '_') for item in screenshots):
            raise ValueError(f'Missing required native screen capture: {name}')
    return {'simulatorValidation': simulator, 'testResults': summary,
            'authoredTests': expected, 'nativeUIScreenshots': screenshots}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--build', type=Path)
    args = parser.parse_args()
    build = args.build or args.root / 'build'
    try:
        evidence = validate(args.root, build)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f'Native evidence validation failed: {error}', file=sys.stderr)
        return 1
    (build / 'validation-evidence.json').write_text(json.dumps(evidence, indent=2) + '\n')
    print(f'Native evidence passed: {evidence["testResults"]["passedTests"]} tests, '
          f'{len(evidence["authoredTests"]["ui"])} UI flows, '
          f'{len(evidence["nativeUIScreenshots"])} retained screenshots.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
