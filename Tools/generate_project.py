"""Rebuild the dependency-free Xcode project after adding/removing source files.
Run from anywhere with Python 3.10+: python Tools/generate_project.py
"""
from pathlib import Path
import hashlib
import json
import plistlib
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
def uid(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()
def q(value):
    return json.dumps(str(value))
objects = []
def obj(key, isa, fields):
    objects.append(f"\t\t{uid(key)} = {{ isa = {isa}; {fields} }};")
def refs(keys):
    return "(" + ", ".join(uid(k) for k in keys) + ("," if keys else "") + ")"
def settings(values):
    return "{ " + " ".join(f"{k} = {q(v)};" for k, v in values.items()) + " }"

sources = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / 'Invoke').rglob('*') if p.suffix in ('.swift', '.metal'))
tests = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / 'InvokeTests').rglob('*.swift'))
ui_tests = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / 'InvokeUITests').rglob('*.swift'))
resources = ['Invoke/Assets.xcassets', 'Invoke/Effects/ShaderLicense.txt'] + sorted(
    p.relative_to(ROOT).as_posix() for p in (ROOT / 'Invoke/Resources').rglob('*')
    if p.is_file() and p.name != 'Info.plist' and p.suffix in ('.json', '.xcprivacy', '.txt'))
filetypes = {'.swift': 'sourcecode.swift', '.metal': 'sourcecode.metal', '.xcassets': 'folder.assetcatalog', '.xcprivacy': 'text.xml', '.json': 'text.json', '.txt': 'text'}
for path in sources + tests + ui_tests + resources:
    obj('file:' + path, 'PBXFileReference', f'lastKnownFileType = {filetypes.get(Path(path).suffix, "text")}; path = {q(path)}; sourceTree = "<group>";')
    obj('build:' + path, 'PBXBuildFile', f'fileRef = {uid("file:" + path)};')
obj('app-product', 'PBXFileReference', 'explicitFileType = wrapper.application; includeInIndex = 0; path = Invoke.app; sourceTree = BUILT_PRODUCTS_DIR;')
obj('test-product', 'PBXFileReference', 'explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = InvokeTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
obj('ui-test-product', 'PBXFileReference', 'explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = InvokeUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
obj('main-group', 'PBXGroup', f'children = {refs(["source-group", "test-group", "ui-test-group", "resource-group", "products-group"])}; sourceTree = "<group>";')
obj('source-group', 'PBXGroup', f'children = {refs(["file:" + p for p in sources])}; name = Sources; sourceTree = "<group>";')
obj('test-group', 'PBXGroup', f'children = {refs(["file:" + p for p in tests])}; name = Tests; sourceTree = "<group>";')
obj('ui-test-group', 'PBXGroup', f'children = {refs(["file:" + p for p in ui_tests])}; name = UITests; sourceTree = "<group>";')
obj('resource-group', 'PBXGroup', f'children = {refs(["file:" + p for p in resources])}; name = Resources; sourceTree = "<group>";')
obj('products-group', 'PBXGroup', f'children = {refs(["app-product", "test-product", "ui-test-product"])}; name = Products; sourceTree = "<group>";')
for key, isa, paths in [('ui-test-sources', 'PBXSourcesBuildPhase', ui_tests), ('ui-test-resources', 'PBXResourcesBuildPhase', []), ('ui-test-frameworks', 'PBXFrameworksBuildPhase', [])]:
    obj(key, isa, f'buildActionMask = 2147483647; files = {refs(["build:" + p for p in paths])}; runOnlyForDeploymentPostprocessing = 0;')
for key, isa, paths in [('app-sources', 'PBXSourcesBuildPhase', sources), ('test-sources', 'PBXSourcesBuildPhase', tests), ('app-resources', 'PBXResourcesBuildPhase', resources), ('test-resources', 'PBXResourcesBuildPhase', []), ('app-frameworks', 'PBXFrameworksBuildPhase', []), ('test-frameworks', 'PBXFrameworksBuildPhase', [])]:
    obj(key, isa, f'buildActionMask = 2147483647; files = {refs(["build:" + p for p in paths])}; runOnlyForDeploymentPostprocessing = 0;')
obj('test-proxy', 'PBXContainerItemProxy', f'containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("app-target")}; remoteInfo = Invoke;')
obj('test-dependency', 'PBXTargetDependency', f'target = {uid("app-target")}; targetProxy = {uid("test-proxy")};')
obj('app-target', 'PBXNativeTarget', f'buildConfigurationList = {uid("app-config-list")}; buildPhases = {refs(["app-sources", "app-frameworks", "app-resources"])}; buildRules = (); dependencies = (); name = Invoke; productName = Invoke; productReference = {uid("app-product")}; productType = "com.apple.product-type.application";')
obj('test-target', 'PBXNativeTarget', f'buildConfigurationList = {uid("test-config-list")}; buildPhases = {refs(["test-sources", "test-frameworks", "test-resources"])}; buildRules = (); dependencies = {refs(["test-dependency"])}; name = InvokeTests; productName = InvokeTests; productReference = {uid("test-product")}; productType = "com.apple.product-type.bundle.unit-test";')
obj('ui-test-target', 'PBXNativeTarget', f'buildConfigurationList = {uid("ui-test-config-list")}; buildPhases = {refs(["ui-test-sources", "ui-test-frameworks", "ui-test-resources"])}; buildRules = (); dependencies = {refs(["test-dependency"])}; name = InvokeUITests; productName = InvokeUITests; productReference = {uid("ui-test-product")}; productType = "com.apple.product-type.bundle.ui-testing";')

base = {'CLANG_ENABLE_MODULES': 'YES', 'CLANG_ENABLE_OBJC_ARC': 'YES', 'IPHONEOS_DEPLOYMENT_TARGET': '17.0', 'SDKROOT': 'iphoneos', 'SWIFT_VERSION': '5.0', 'ENABLE_USER_SCRIPT_SANDBOXING': 'YES', 'GCC_C_LANGUAGE_STANDARD': 'gnu17', 'CLANG_CXX_LANGUAGE_STANDARD': 'gnu++20', 'SWIFT_STRICT_CONCURRENCY': 'targeted'}
for config in ['Debug', 'Release']:
    b = base | {'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if config == 'Debug' else '-O', 'DEBUG_INFORMATION_FORMAT': 'dwarf' if config == 'Debug' else 'dwarf-with-dsym', 'ENABLE_TESTABILITY': 'YES' if config == 'Debug' else 'NO', 'ONLY_ACTIVE_ARCH': 'YES' if config == 'Debug' else 'NO'}
    if config == 'Debug': b['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG $(inherited)'
    obj('project-' + config, 'XCBuildConfiguration', f'buildSettings = {settings(b)}; name = {config};')
    app = {'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon', 'CODE_SIGN_STYLE': 'Automatic', 'CURRENT_PROJECT_VERSION': '1', 'GENERATE_INFOPLIST_FILE': 'NO', 'INFOPLIST_FILE': 'Invoke/Resources/Info.plist', 'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks', 'MARKETING_VERSION': '2.0.0', 'PRODUCT_BUNDLE_IDENTIFIER': 'app.invoke.personal', 'PRODUCT_NAME': '$(TARGET_NAME)', 'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator', 'SUPPORTS_MACCATALYST': 'NO', 'TARGETED_DEVICE_FAMILY': '1', 'ENABLE_PREVIEWS': 'YES', 'MTL_ENABLE_DEBUG_INFO': 'INCLUDE_SOURCE' if config == 'Debug' else 'NO'}
    app['OTHER_LDFLAGS'] = '$(inherited) -lsqlite3'
    obj('app-' + config, 'XCBuildConfiguration', f'buildSettings = {settings(app)}; name = {config};')
    test = {'BUNDLE_LOADER': '$(TEST_HOST)', 'CODE_SIGN_STYLE': 'Automatic', 'GENERATE_INFOPLIST_FILE': 'YES', 'PRODUCT_BUNDLE_IDENTIFIER': 'app.invoke.personal.tests', 'PRODUCT_NAME': '$(TARGET_NAME)', 'TARGETED_DEVICE_FAMILY': '1', 'TEST_HOST': '$(BUILT_PRODUCTS_DIR)/Invoke.app/Invoke', 'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks @loader_path/Frameworks'}
    test['OTHER_LDFLAGS'] = '$(inherited) -lsqlite3'
    obj('test-' + config, 'XCBuildConfiguration', f'buildSettings = {settings(test)}; name = {config};')
    ui_test = {'CODE_SIGN_STYLE': 'Automatic', 'GENERATE_INFOPLIST_FILE': 'YES', 'PRODUCT_BUNDLE_IDENTIFIER': 'app.invoke.personal.uitests', 'PRODUCT_NAME': '$(TARGET_NAME)', 'TARGETED_DEVICE_FAMILY': '1', 'TEST_TARGET_NAME': 'Invoke', 'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks @loader_path/Frameworks'}
    obj('ui-test-' + config, 'XCBuildConfiguration', f'buildSettings = {settings(ui_test)}; name = {config};')
for key in ['project', 'app', 'test', 'ui-test']:
    obj(key + '-config-list', 'XCConfigurationList', f'buildConfigurations = {refs([key + "-Debug", key + "-Release"])}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('project', 'PBXProject', f'attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; TargetAttributes = {{ {uid("app-target")} = {{ CreatedOnToolsVersion = 16.0; }}; {uid("test-target")} = {{ CreatedOnToolsVersion = 16.0; TestTargetID = {uid("app-target")}; }}; {uid("ui-test-target")} = {{ CreatedOnToolsVersion = 16.0; TestTargetID = {uid("app-target")}; }}; }}; }}; buildConfigurationList = {uid("project-config-list")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {uid("main-group")}; productRefGroup = {uid("products-group")}; projectDirPath = ""; projectRoot = ""; targets = {refs(["app-target", "test-target", "ui-test-target"])};')
project = ROOT / 'Invoke.xcodeproj'
project.mkdir(exist_ok=True)
(project / 'project.pbxproj').write_text('// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n' + '\n'.join(objects) + f'\n\t}};\n\trootObject = {uid("project")};\n}}\n', encoding='utf-8')

scheme = ET.Element('Scheme', LastUpgradeVersion='1600', version='1.3')
def build_ref(parent, target):
    key = {'Invoke': 'app-target', 'InvokeTests': 'test-target', 'InvokeUITests': 'ui-test-target'}[target]
    ET.SubElement(parent, 'BuildableReference', BuildableIdentifier='primary', BlueprintIdentifier=uid(key), BuildableName=target + ('.app' if target == 'Invoke' else '.xctest'), BlueprintName=target, ReferencedContainer='container:Invoke.xcodeproj')
build = ET.SubElement(scheme, 'BuildAction', parallelizeBuildables='YES', buildImplicitDependencies='YES')
entries = ET.SubElement(build, 'BuildActionEntries')
entry = ET.SubElement(entries, 'BuildActionEntry', buildForTesting='YES', buildForRunning='YES', buildForProfiling='YES', buildForArchiving='YES', buildForAnalyzing='YES')
build_ref(entry, 'Invoke')
test_action = ET.SubElement(scheme, 'TestAction', buildConfiguration='Debug', selectedDebuggerIdentifier='Xcode.DebuggerFoundation.Debugger.LLDB', selectedLauncherIdentifier='Xcode.IDEFoundation.Launcher.LLDB', shouldUseLaunchSchemeArgsEnv='YES')
testables = ET.SubElement(test_action, 'Testables')
testable = ET.SubElement(testables, 'TestableReference', skipped='NO')
build_ref(testable, 'InvokeTests')
build_ref(ET.SubElement(testables, 'TestableReference', skipped='NO', parallelizable='NO'), 'InvokeUITests')
launch = ET.SubElement(scheme, 'LaunchAction', buildConfiguration='Debug', selectedDebuggerIdentifier='Xcode.DebuggerFoundation.Debugger.LLDB', selectedLauncherIdentifier='Xcode.IDEFoundation.Launcher.LLDB', launchStyle='0', useCustomWorkingDirectory='NO', ignoresPersistentStateOnLaunch='NO', debugDocumentVersioning='YES', debugServiceExtension='internal', allowLocationSimulation='YES')
build_ref(ET.SubElement(launch, 'BuildableProductRunnable', runnableDebuggingMode='0'), 'Invoke')
profile = ET.SubElement(scheme, 'ProfileAction', buildConfiguration='Release', shouldUseLaunchSchemeArgsEnv='YES', savedToolIdentifier='', useCustomWorkingDirectory='NO', debugDocumentVersioning='YES')
build_ref(ET.SubElement(profile, 'BuildableProductRunnable', runnableDebuggingMode='0'), 'Invoke')
ET.SubElement(scheme, 'AnalyzeAction', buildConfiguration='Debug')
ET.SubElement(scheme, 'ArchiveAction', buildConfiguration='Release', revealArchiveInOrganizer='YES')
scheme_dir = project / 'xcshareddata' / 'xcschemes'
scheme_dir.mkdir(parents=True, exist_ok=True)
ET.indent(scheme)
ET.ElementTree(scheme).write(scheme_dir / 'Invoke.xcscheme', encoding='utf-8', xml_declaration=True)

info = {'CFBundleDevelopmentRegion': 'en', 'CFBundleDisplayName': 'Invoke', 'CFBundleExecutable': '$(EXECUTABLE_NAME)', 'CFBundleIdentifier': '$(PRODUCT_BUNDLE_IDENTIFIER)', 'CFBundleInfoDictionaryVersion': '6.0', 'CFBundleName': 'Invoke', 'CFBundlePackageType': 'APPL', 'CFBundleShortVersionString': '$(MARKETING_VERSION)', 'CFBundleVersion': '$(CURRENT_PROJECT_VERSION)', 'LSRequiresIPhoneOS': True, 'UIApplicationSceneManifest': {'UIApplicationSupportsMultipleScenes': False}, 'UILaunchScreen': {}, 'UISupportedInterfaceOrientations': ['UIInterfaceOrientationPortrait'], 'UIRequiredDeviceCapabilities': ['arm64'], 'UTExportedTypeDeclarations': [{'UTTypeIdentifier': 'app.invoke.backup', 'UTTypeDescription': 'Invoke portable backup', 'UTTypeConformsTo': ['public.json'], 'UTTypeTagSpecification': {'public.filename-extension': ['invoke'], 'public.mime-type': 'application/json'}}], 'CFBundleDocumentTypes': [{'CFBundleTypeName': 'Invoke portable backup', 'LSItemContentTypes': ['app.invoke.backup'], 'LSHandlerRank': 'Owner'}]}
(ROOT/'Invoke/Resources/Info.plist').write_bytes(plistlib.dumps(info))
(ROOT/'Invoke/Resources/PrivacyInfo.xcprivacy').write_bytes(plistlib.dumps({'NSPrivacyTracking': False, 'NSPrivacyTrackingDomains': [], 'NSPrivacyCollectedDataTypes': [], 'NSPrivacyAccessedAPITypes': []}))
(ROOT/'Invoke/Assets.xcassets/Contents.json').write_text(json.dumps({'info': {'author':'xcode', 'version':1}}, indent=2))
(ROOT/'Invoke/Assets.xcassets/AppIcon.appiconset/Contents.json').write_text(json.dumps({'images':[{'filename':'Invoke.png','idiom':'universal','platform':'ios','size':'1024x1024'}], 'info':{'author':'xcode','version':1}},indent=2))
print(f'Generated Invoke.xcodeproj: {len(sources)} app compile sources, {len(tests)} unit test sources, {len(ui_tests)} UI test sources, {len(resources)} resources.')
