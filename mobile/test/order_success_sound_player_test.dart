import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/audio/order_success_sound.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'failed reference playback stays silent without a system click',
    () async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      final player = AssetOrderSuccessSoundPlayer();

      await player.play();

      expect(calls.where((call) => call.method == 'SystemSound.play'), isEmpty);
    },
  );

  test('order failure feedback plays the platform alert sound', () async {
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await const SystemOrderFailureSoundPlayer().play();

    expect(
      calls,
      contains(
        isA<MethodCall>()
            .having((call) => call.method, 'method', 'SystemSound.play')
            .having(
              (call) => call.arguments,
              'arguments',
              SystemSoundType.alert.toString(),
            ),
      ),
    );
  });
}
