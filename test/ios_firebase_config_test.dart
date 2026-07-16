import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const bundleId = 'com.codingminds.issac.flighttracker';
  const firebaseAppId = '1:508069160076:ios:bfa57741686fb95f6687a9';

  test('iOS target and FlutterFire use the same registered app', () {
    final firebaseConfig =
        jsonDecode(File('firebase.json').readAsStringSync())
            as Map<String, dynamic>;
    final flutter = firebaseConfig['flutter'] as Map<String, dynamic>;
    final platforms = flutter['platforms'] as Map<String, dynamic>;
    final ios = platforms['ios'] as Map<String, dynamic>;
    final defaultIos = ios['default'] as Map<String, dynamic>;
    final dart = platforms['dart'] as Map<String, dynamic>;
    final dartOptions =
        dart['lib/firebase_options.dart'] as Map<String, dynamic>;
    final configurations =
        dartOptions['configurations'] as Map<String, dynamic>;

    expect(defaultIos['appId'], firebaseAppId);
    expect(configurations['ios'], firebaseAppId);

    final xcodeProject = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final appBundleIds = RegExp(
      r'PRODUCT_BUNDLE_IDENTIFIER = (com\.codingminds\.[^;]+);',
    ).allMatches(xcodeProject).map((match) => match.group(1)).toSet();

    expect(appBundleIds, {bundleId});
  });

  test('generated local Firebase files match the iOS target when present', () {
    final firebaseOptions = File('lib/firebase_options.dart');
    if (firebaseOptions.existsSync()) {
      final contents = firebaseOptions.readAsStringSync();
      expect(contents, contains(firebaseAppId));
      expect(contents, contains("iosBundleId: '$bundleId'"));
    }

    final googleServiceInfo = File('ios/Runner/GoogleService-Info.plist');
    if (googleServiceInfo.existsSync()) {
      final contents = googleServiceInfo.readAsStringSync();
      expect(contents, contains(firebaseAppId));
      expect(contents, contains(bundleId));
    }
  });

  test('iOS Firebase plugins stay on the CocoaPods iOS 15 path', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec,
      contains('enable-swift-package-manager: false'),
      reason:
          'Enabling Flutter plugin SwiftPM recreates an iOS 13 wrapper package '
          'that cannot host the Firebase iOS 15 packages during Xcode Archive.',
    );

    final podfile = File('ios/Podfile').readAsStringSync();
    expect(podfile, contains("platform :ios, '15.0'"));
    expect(
      podfile,
      contains("IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'"),
    );

    final xcodeProject = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    expect(xcodeProject, isNot(contains('FlutterGeneratedPluginSwiftPackage')));

    final deploymentTargets = RegExp(
      r'IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);',
    ).allMatches(xcodeProject).map((match) => match.group(1)!).toSet();
    expect(deploymentTargets, isNotEmpty);
    expect(
      deploymentTargets.every(
        (version) => double.parse(version) >= 15,
      ),
      isTrue,
    );
  });
}
