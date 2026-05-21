import 'dart:io';
import '../platform/platform_android.dart';
import '../util/logger.dart';

/// 前台服务管理器 — 防止 Android 后台进程冻结
///
/// 单例，仅在 Android 上生效。不做传输工作，仅启动/停止前台服务来
/// 告诉系统"进程正在做用户可见的工作"，从而阻止 Android 14+ 的
/// 墓碑机制（cached app freeze）冻结进程。
class ForegroundServiceManager {
  static final ForegroundServiceManager _instance =
      ForegroundServiceManager._();
  factory ForegroundServiceManager() => _instance;
  ForegroundServiceManager._();

  final _platform = Platform.isAndroid ? AndroidPlatform() : null;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Future<void> start({
    required String title,
    required String body,
  }) async {
    if (!Platform.isAndroid || _isRunning) return;
    _isRunning = true;
    await _platform?.startForegroundService({
      'title': title,
      'body': body,
    });
    Logger.log('[FGS] Started: title=$title body=$body');
  }

  Future<void> stop() async {
    if (!Platform.isAndroid || !_isRunning) return;
    _isRunning = false;
    await _platform?.stopForegroundService();
    Logger.log('[FGS] Stopped');
  }

  Future<void> updateNotification({
    required String title,
    required String body,
    int? progress,
    int? progressMax,
  }) async {
    if (!Platform.isAndroid || !_isRunning) return;
    await _platform?.updateNotification(
      title: title,
      body: body,
      progress: progress,
      progressMax: progressMax,
    );
  }
}
