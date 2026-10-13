"""Select exact Xcode 27.0 with both iOS 27.0 SDKs; never use an older SDK."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

XCODE_VERSION = '27.0'
SDK_VERSION = '27.0'


def command(args, developer_dir=None):
    env = dict(os.environ)
    if developer_dir is not None:
        env['DEVELOPER_DIR'] = str(developer_dir)
    return subprocess.check_output(args, env=env, text=True, stderr=subprocess.STDOUT,
                                   timeout=60).strip()


def inspect_xcode(path):
    description = command(['xcodebuild', '-version'], path)
    match = re.search(r'^Xcode (.+)$', description, re.MULTILINE)
    if not match or match[1].strip() != XCODE_VERSION or 'beta' in str(path).lower():
        raise ValueError(f'{path}: requires stable Xcode {XCODE_VERSION}, found {description!r}')
    build_match = re.search(r'^Build version (.+)$', description, re.MULTILINE)
    sdks = {}
    for platform in ('iphoneos', 'iphonesimulator'):
        name = platform + SDK_VERSION
        version = command(['xcrun', '--sdk', name, '--show-sdk-version'], path)
        if version != SDK_VERSION:
            raise ValueError(f'{path}: {name} reported unexpected version {version!r}')
        sdks[platform] = {
            'name': name, 'version': version,
            'build': command(['xcrun', '--sdk', name, '--show-sdk-build-version'], path),
            'path': command(['xcrun', '--sdk', name, '--show-sdk-path'], path),
        }
    return {'xcodeVersion': XCODE_VERSION, 'xcodeBuild': build_match[1] if build_match else None,
            'xcodeDescription': description, 'developerDirectory': str(path), 'sdks': sdks}


def select_xcode(paths):
    failures = []
    seen = set()
    for path in paths:
        path = Path(path).resolve()
        if path in seen:
            continue
        seen.add(path)
        try:
            return inspect_xcode(path)
        except (OSError, subprocess.SubprocessError, ValueError) as error:
            failures.append(str(error))
    raise RuntimeError('Exact Xcode 27.0 with iphoneos27.0 and iphonesimulator27.0 was not found. '
                       'Use the xcode-27 GitHub runner or install this toolchain. No fallback was used.\n'
                       + '\n'.join(failures))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--print-path', action='store_true',
                        help='Print only the validated developer path for shell command substitution')
    args = parser.parse_args()
    candidates = [Path('/Applications/Xcode_27.0.app/Contents/Developer'),
                  Path('/Applications/Xcode_27.app/Contents/Developer')]
    if os.environ.get('DEVELOPER_DIR'):
        candidates.append(Path(os.environ['DEVELOPER_DIR']))
    try:
        candidates.append(Path(command(['xcode-select', '-p'])))
    except (OSError, subprocess.SubprocessError):
        pass
    candidates.extend(sorted(Path('/Applications').glob('Xcode*.app/Contents/Developer')))
    try:
        metadata = select_xcode(candidates)
    except RuntimeError as error:
        print(str(error), file=sys.stderr)
        return 1
    output = Path(__file__).resolve().parents[1] / 'build'
    output.mkdir(exist_ok=True)
    (output / 'toolchain.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
    if args.print_path:
        print(metadata['developerDirectory'])
    else:
        print(json.dumps(metadata, indent=2))
        if os.environ.get('GITHUB_ENV'):
            with open(os.environ['GITHUB_ENV'], 'a', encoding='utf-8') as env:
                env.write(f"DEVELOPER_DIR={metadata['developerDirectory']}\n")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
