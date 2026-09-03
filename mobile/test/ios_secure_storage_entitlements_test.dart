import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS runner configures Keychain Sharing for every build mode', () {
    final debugEntitlements = File('ios/Runner/DebugProfile.entitlements');
    final releaseEntitlements = File('ios/Runner/Release.entitlements');
    final project = File('ios/Runner.xcodeproj/project.pbxproj');

    expect(debugEntitlements.existsSync(), isTrue);
    expect(releaseEntitlements.existsSync(), isTrue);
    expect(
      debugEntitlements.readAsStringSync(),
      contains('<key>keychain-access-groups</key>'),
    );
    expect(
      releaseEntitlements.readAsStringSync(),
      contains('<key>keychain-access-groups</key>'),
    );

    final projectContents = project.readAsStringSync();
    expect(
      'CODE_SIGN_ENTITLEMENTS = Runner/DebugProfile.entitlements;'.allMatches(
        projectContents,
      ),
      hasLength(2),
    );
    expect(
      'CODE_SIGN_ENTITLEMENTS = Runner/Release.entitlements;'.allMatches(
        projectContents,
      ),
      hasLength(1),
    );
  });
}
