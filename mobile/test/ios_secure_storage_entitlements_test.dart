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
      debugEntitlements.readAsStringSync(),
      contains(
        '<string>48V5PYQU8X.com.tradingdemo.tradingMobile</string>',
      ),
    );
    expect(
      debugEntitlements.readAsStringSync(),
      contains('<key>application-identifier</key>'),
    );
    expect(
      debugEntitlements.readAsStringSync(),
      contains('<key>com.apple.developer.team-identifier</key>'),
    );
    expect(
      releaseEntitlements.readAsStringSync(),
      contains('<key>keychain-access-groups</key>'),
    );
    expect(
      releaseEntitlements.readAsStringSync(),
      contains(
        '<string>\$(AppIdentifierPrefix)\$(PRODUCT_BUNDLE_IDENTIFIER)</string>',
      ),
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
