import 'dart:io';
import 'package:flutter/services.dart';
import 'logger.dart';

/// Acquires WiFi Multicast Lock on Android to ensure reliable UDP
/// broadcast/multicast reception. No-op on other platforms.
class WifiLock {
  static const _channel = MethodChannel('fastshare/wifi_lock');
  static bool _acquired = false;

  static Future<void> acquire() async {
    if (_acquired) return;
    if (!Platform.isAndroid) return;
    try {
      final result = await _channel.invokeMethod('acquireMulticastLock');
      _acquired = true;
      Logger.log('[WifiLock] Multicast lock acquired: $result');
    } catch (e) {
      Logger.log('[WifiLock] acquire failed: $e');
    }
  }

  static Future<void> release() async {
    if (!_acquired) return;
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('releaseMulticastLock');
      _acquired = false;
      Logger.log('[WifiLock] Multicast lock released');
    } catch (e) {
      Logger.log('[WifiLock] release failed: $e');
    }
  }
}
