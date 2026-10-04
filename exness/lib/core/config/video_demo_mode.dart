import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The recorded interface is the default preview until account APIs are wired.
/// Override this provider with false to exercise the existing live data path.
final videoDemoModeProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('VIDEO_DEMO_MODE', defaultValue: true),
);
