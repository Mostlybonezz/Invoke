"""Portable source/package checks. These do NOT compile Swift or execute XCTest.
Optional Swift grammar parser: pip install tree-sitter tree-sitter-swift
"""
import hashlib
import json
import plistlib
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
errors = []
def check(condition, message):
    if not condition: errors.append(message)

project = (ROOT/'Invoke.xcodeproj/project.pbxproj').read_text()
check(project.count('{') == project.count('}'), 'Unbalanced Xcode project braces')
try:
    from openstep_parser import OpenStepDecoder
    parsed = OpenStepDecoder.ParseFromString(project)
    check(len(parsed['objects'][parsed['rootObject']]['targets']) == 2, 'Expected app and XCTest targets')
except ImportError:
    pass
definitions = re.findall(r'^\s*([A-F0-9]{24}) = \{ isa = ', project, re.M)
check(len(definitions) == len(set(definitions)), 'Duplicate project object IDs')
check(set(re.findall(r'\b[A-F0-9]{24}\b', project)).issubset(set(definitions)), 'Unresolved project object ID')
swift = sorted((ROOT/'Invoke').rglob('*.swift')) + sorted((ROOT/'InvokeTests').glob('*.swift'))
metal = list((ROOT/'Invoke').rglob('*.metal'))
for path in swift + metal:
    rel = path.relative_to(ROOT).as_posix()
    check(f'path = "{rel}";' in project, f'File missing from project: {rel}')
    key = hashlib.sha256(('build:' + rel).encode()).hexdigest()[:24].upper()
    check(project.count(key) == 2, f'File not exactly once in compile phase: {rel}')

for path in (ROOT/'Invoke/Resources').glob('*'):
    if path.suffix in ('.plist', '.xcprivacy'): plistlib.loads(path.read_bytes())
for path in (ROOT/'Invoke/Assets.xcassets').rglob('Contents.json'): json.loads(path.read_text())
ET.parse(ROOT/'Invoke.xcodeproj/xcshareddata/xcschemes/Invoke.xcscheme')
icon = ROOT/'Invoke/Assets.xcassets/AppIcon.appiconset/Invoke.png'
check(icon.exists(), 'App icon is missing')
if icon.exists():
    b = icon.read_bytes()
    check(b[:8] == b'\x89PNG\r\n\x1a\n', 'App icon is not PNG')
    check(int.from_bytes(b[16:20], 'big') == 1024 and int.from_bytes(b[20:24], 'big') == 1024, 'App icon must be 1024 square')
    check(b[25] == 2, 'App icon must be opaque RGB')

for path in swift:
    content = path.read_text(encoding='utf-8')
    check('Velvet Margins' not in content, f'Old branding in {path.name}')
    check('fatalError(' not in content and 'try!' not in content, f'Unchecked failure in {path.name}')
    check('.design(.serif)' not in content, f'Invalid Font API in {path.name}')
    check('accessibilityContrast' not in content, f'Invalid environment key in {path.name}')

syntax = 'not run (optional parser is not installed)'
try:
    import tree_sitter_swift
    from tree_sitter import Language, Parser
    parser = Parser(Language(tree_sitter_swift.language()))
    for path in swift:
        tree = parser.parse(path.read_bytes())
        check(not tree.root_node.has_error, f'Swift grammar error in {path.relative_to(ROOT)}')
    syntax = f'{len(swift)} Swift files parsed; no grammar errors' if not errors else 'see failures'
except ImportError:
    pass

test_count = sum(len(re.findall(r'func test\w+\(', p.read_text())) for p in (ROOT/'InvokeTests').glob('*.swift'))
print(f'Package checks: {len(swift)} Swift files, {len(metal)} Metal file(s), {test_count} authored XCTest methods.')
print('Swift syntax: ' + syntax)
print('Swift compilation, Metal compilation, simulator/device testing, and XCTest execution: NOT RUN.')
if errors:
    print('\n'.join('FAIL: ' + error for error in errors)); sys.exit(1)
print('PASS: package/source checks only.')
