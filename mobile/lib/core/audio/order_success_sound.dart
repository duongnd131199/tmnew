import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class OrderSuccessSoundPlayer {
  Future<void> warmUp();

  Future<void> play();

  Future<void> dispose();
}

final orderSuccessSoundPlayerProvider = Provider<OrderSuccessSoundPlayer>((
  ref,
) {
  final player = AssetOrderSuccessSoundPlayer();
  ref.onDispose(() => unawaited(player.dispose()));
  return player;
});

class AssetOrderSuccessSoundPlayer implements OrderSuccessSoundPlayer {
  static final _asset = AssetSource('sounds/order_success.wav');

  Future<AudioPool>? _poolFuture;
  bool _disposed = false;

  Future<AudioPool> _pool() => _poolFuture ??= AudioPool.create(
    source: _asset,
    minPlayers: 1,
    maxPlayers: 2,
  );

  @override
  Future<void> dispose() async {
    _disposed = true;
    final poolFuture = _poolFuture;
    if (poolFuture == null) return;
    try {
      final pool = await poolFuture;
      await pool.dispose();
    } catch (_) {
      // A failed preload has no native player to release.
    }
  }

  @override
  Future<void> play() async {
    if (_disposed) return;
    try {
      final pool = await _pool();
      if (_disposed) return;
      await pool.start();
    } catch (_) {
      // Audio feedback is best-effort. Staying silent preserves the approved
      // reference sound instead of substituting a different system click.
    }
  }

  @override
  Future<void> warmUp() async {
    if (_disposed) return;
    try {
      await _pool();
    } catch (_) {
      // play() will retry through the platform fallback.
    }
  }
}
