#!/usr/bin/env python3
"""Deterministic Xcode project, generated using only Python's standard library."""
from pathlib import Path
import hashlib

def uid(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def q(s): return '"' + str(s).replace('\\', '\\\\').replace('"','\\"') + '"'
objects = {}
def obj(key, body): objects[uid(key)] = '{ ' + body + ' };'; return uid(key)
def arr(items): return '(' + ', '.join(items) + ',)' if items else '()'
app='Flightbook'; targets=[app,'FlightbookTests','FlightbookUITests']
products=[]; groups=[]; native=[]
for name in targets:
    suffix='app' if name == app else 'xctest'
    prod=obj('product'+name,f'isa = PBXFileReference; explicitFileType = {"wrapper.application" if name == app else "wrapper.cfbundle"}; path = {q(name+"."+suffix)}; sourceTree = BUILT_PRODUCTS_DIR;')
    products.append(prod)
    files=list(Path(name).rglob('*.swift'))
    if name == app: files += list(Path('Flightbook/Resources').glob('*')) + [Path('Flightbook/Assets.xcassets')]
    sources=[]; resources=[]; refs=[]
    for path in sorted(files):
        p=str(path); kind='sourcecode.swift' if path.suffix == '.swift' else 'folder.assetcatalog' if path.suffix=='.xcassets' else 'text.json'
        ref=obj('ref'+p,f'isa = PBXFileReference; lastKnownFileType = {kind}; path = {q(p)}; sourceTree = SOURCE_ROOT;')
        refs.append(ref)
        build=obj('build'+p,f'isa = PBXBuildFile; fileRef = {ref};')
        (sources if path.suffix == '.swift' else resources).append(build)
    group=obj('group'+name,f'isa = PBXGroup; children = {arr(refs)}; name = {q(name)}; sourceTree = "<group>";'); groups.append(group)
    sourcePhase=obj('sources'+name,f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {arr(sources)}; runOnlyForDeploymentPostprocessing = 0;')
    resPhase=obj('resources'+name,f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {arr(resources)}; runOnlyForDeploymentPostprocessing = 0;')
    frameworkPhase=obj('frameworks'+name,'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    configs=[]
    for config in ['Debug','Release']:
        settings={'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.baiweicheng.flightbook'+('' if name==app else '.'+name),
                  'SWIFT_VERSION':'6.0','IPHONEOS_DEPLOYMENT_TARGET':'26.0','TARGETED_DEVICE_FAMILY':'1',
                  'GENERATE_INFOPLIST_FILE':'YES','CODE_SIGN_STYLE':'Automatic','SWIFT_STRICT_CONCURRENCY':'complete',
                  'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if config=='Debug' else '-O','ENABLE_TESTABILITY':'YES' if config=='Debug' else 'NO'}
        if name==app: settings.update({'INFOPLIST_KEY_CFBundleDisplayName':'Flightbook','INFOPLIST_KEY_UILaunchScreen_Generation':'YES',
            'INFOPLIST_KEY_UISupportedInterfaceOrientations':'UIInterfaceOrientationPortrait',
            'INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES','ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME':'AccentColor',
            'ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','MARKETING_VERSION':'1.0','CURRENT_PROJECT_VERSION':'1',
            'INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace':'YES'})
        elif name=='FlightbookTests': settings.update({'TEST_HOST':'$(BUILT_PRODUCTS_DIR)/Flightbook.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Flightbook','BUNDLE_LOADER':'$(TEST_HOST)'})
        else: settings['TEST_TARGET_NAME']=app
        cfg=obj('config'+name+config,'isa = XCBuildConfiguration; buildSettings = { '+' '.join(f'{k} = {q(v)};' for k,v in settings.items())+' }; name = '+config+';'); configs.append(cfg)
    cl=obj('configs'+name,f'isa = XCConfigurationList; buildConfigurations = {arr(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    deps=[]
    if name!=app:
        proxy=obj('proxy'+name,f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("target"+app)}; remoteInfo = Flightbook;')
        deps=[obj('dep'+name,f'isa = PBXTargetDependency; target = {uid("target"+app)}; targetProxy = {proxy};')]
    native.append(obj('target'+name,f'isa = PBXNativeTarget; buildConfigurationList = {cl}; buildPhases = {arr([sourcePhase,frameworkPhase,resPhase])}; buildRules = (); dependencies = {arr(deps) if deps else "()"}; name = {q(name)}; productName = {q(name)}; productReference = {prod}; productType = {q("com.apple.product-type.application" if name==app else "com.apple.product-type.bundle.unit-test" if name=="FlightbookTests" else "com.apple.product-type.bundle.ui-testing")};'))
productGroup=obj('products',f'isa = PBXGroup; children = {arr(products)}; name = Products; sourceTree = "<group>";')
main=obj('main',f'isa = PBXGroup; children = {arr(groups+[productGroup])}; sourceTree = "<group>";')
configs=[]
for config in ['Debug','Release']:
    configs.append(obj('project'+config,f'isa = XCBuildConfiguration; buildSettings = {{ SDKROOT = iphoneos; CLANG_ENABLE_MODULES = YES; ENABLE_USER_SCRIPT_SANDBOXING = YES; DEBUG_INFORMATION_FORMAT = {q("dwarf" if config=="Debug" else "dwarf-with-dsym")}; }}; name = {config};'))
cl=obj('projectconfigs',f'isa = XCConfigurationList; buildConfigurations = {arr(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2710; BuildIndependentTargetsInParallel = YES; }}; buildConfigurationList = {cl}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main}; productRefGroup = {productGroup}; projectDirPath = ""; projectRoot = ""; targets = {arr(native)};')
root=Path('Flightbook.xcodeproj'); root.mkdir(exist_ok=True)
(root/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(k+' = '+v for k,v in sorted(objects.items()))+'\n}; rootObject = '+uid('project')+'; }\n')
scheme=root/'xcshareddata/xcschemes'; scheme.mkdir(parents=True,exist_ok=True)
def ref(name): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target"+name)}" BuildableName="{name+ (".app" if name==app else ".xctest")}" BlueprintName="{name}" ReferencedContainer="container:Flightbook.xcodeproj"/>'
(scheme/'Flightbook.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2710" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref(app)}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>{''.join('<TestableReference skipped="NO" parallelizable="NO">'+ref(t)+'</TestableReference>' for t in targets[1:])}</Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref(app)}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref(app)}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Generated Flightbook.xcodeproj')
