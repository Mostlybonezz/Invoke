import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('verify_test_evidence', Path(__file__).resolve().parents[1] / 'verify_test_evidence.py')
evidence = importlib.util.module_from_spec(spec)
spec.loader.exec_module(evidence)


class EvidenceGateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.build = self.root / 'build'
        for folder in ('Tools', 'InvokeTests', 'InvokeUITests', 'build/ui-screenshots'):
            (self.root / folder).mkdir(parents=True, exist_ok=True)
        (self.root / 'InvokeTests/UnitTests.swift').write_text(
            'final class UnitTests: XCTestCase {\n' + ''.join(f'func testItem{i}() {{}}\n' for i in range(24)) + '}')
        (self.root / 'InvokeUITests/UITests.swift').write_text(
            'final class UITests: XCTestCase { func testFirst() {} func testSecond() {} }')
        self.write('Tools/test_contract.json', {'schemaVersion': 1, 'minimumUnitTests': 24,
                   'minimumUITests': 2, 'requiredScreenshots': ['Today', 'Chronicle']})
        self.write('build/simulator-info.json', {'runtimeVersion': '27.0', 'testStatus': 'passed'})
        self.summary = {'result': 'Passed', 'passedTests': 26, 'totalTestCount': 26,
                        'failedTests': 0, 'skippedTests': 0,
                        'devicesAndConfigurations': [{'device': {'osVersion': '27.0'}}]}
        self.write('build/test-summary.json', self.summary)
        self.manifest = []
        for index, name in enumerate(('Today', 'Chronicle')):
            filename = f'{index}.png'
            (self.build / 'ui-screenshots' / filename).write_bytes(b'\x89PNG\r\n\x1a\n')
            self.manifest.append({'testIdentifier': f'UITests/test{("First", "Second")[index]}()',
                'attachments': [{'exportedFileName': filename, 'suggestedHumanReadableName': name + '_device',
                                 'isAssociatedWithFailure': False, 'deviceName': 'iPhone 17'}]})
        self.write('build/ui-screenshots/manifest.json', self.manifest)

    def tearDown(self):
        self.temp.cleanup()

    def write(self, name, value):
        (self.root / name).write_text(json.dumps(value))

    def testAcceptsCompleteEvidence(self):
        result = evidence.validate(self.root, self.build)
        self.assertEqual(len(result['nativeUIScreenshots']), 2)
        self.assertEqual(len(result['authoredTests']['unit']), 24)

    def testNewAuthoredTestRequiresAnAdditionalExecutedTest(self):
        (self.root / 'InvokeTests/ExtraTests.swift').write_text('final class ExtraTests: XCTestCase { func testMigration() {} }')
        with self.assertRaisesRegex(ValueError, '27 authored tests'):
            evidence.validate(self.root, self.build)

    def testSkippedTestCannotBeHiddenByPassedStatus(self):
        self.summary['skippedTests'] = 1
        self.write('build/test-summary.json', self.summary)
        with self.assertRaisesRegex(ValueError, 'zero failures/skips'):
            evidence.validate(self.root, self.build)

    def testOlderSimulatorCannotPass(self):
        self.summary['devicesAndConfigurations'][0]['device']['osVersion'] = '26.0'
        self.write('build/test-summary.json', self.summary)
        with self.assertRaisesRegex(ValueError, 'exact iOS 27.0'):
            evidence.validate(self.root, self.build)

    def testMissingOrFailureScreenshotCannotPass(self):
        self.manifest[1]['attachments'][0]['isAssociatedWithFailure'] = True
        self.write('build/ui-screenshots/manifest.json', self.manifest)
        with self.assertRaisesRegex(ValueError, 'Missing retained screenshots'):
            evidence.validate(self.root, self.build)

    def testScreenshotTraversalCannotSatisfyFlow(self):
        self.manifest[1]['attachments'][0]['exportedFileName'] = '../1.png'
        self.write('build/ui-screenshots/manifest.json', self.manifest)
        with self.assertRaisesRegex(ValueError, 'Missing retained screenshots'):
            evidence.validate(self.root, self.build)

    def testRequiredScreenMustBeCaptured(self):
        self.manifest[1]['attachments'][0]['suggestedHumanReadableName'] = 'Unrelated_device'
        self.write('build/ui-screenshots/manifest.json', self.manifest)
        with self.assertRaisesRegex(ValueError, 'Missing required native screen capture'):
            evidence.validate(self.root, self.build)


if __name__ == '__main__':
    unittest.main()
