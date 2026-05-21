import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/device.dart';
import 'ui/pages/devices/devices_page.dart';
import 'ui/pages/transfer/transfer_page.dart';
import 'ui/pages/transfer/receive_confirm_dialog.dart';
import 'ui/pages/history/history_page.dart';
import 'ui/pages/settings/settings_page.dart';
import 'models/transfer_task.dart';
import 'platform/foreground_service_manager.dart';
import 'providers/settings_provider.dart';
import 'providers/connection_provider.dart';
import 'providers/discovery_provider.dart';
import 'providers/transfer_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/clipboard_provider.dart';

/// 应用入口 — 深色模式完善 (需求 §32)
///
/// 跟随系统 + 手动切换 + 全页面适配
class FastShareApp extends ConsumerStatefulWidget {
  const FastShareApp({super.key});

  @override
  ConsumerState<FastShareApp> createState() => _FastShareAppState();
}

class _FastShareAppState extends ConsumerState<FastShareApp>
    with WidgetsBindingObserver {
  final _pages = <Widget>[
    const DevicesPage(),
    const TransferPage(),
    const HistoryPage(),
    const SettingsPage(),
  ];

  final _navigatorKey = GlobalKey<NavigatorState>();
  TransferOffer? _lastShownOffer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _onAppBackground();
    } else if (state == AppLifecycleState.resumed) {
      _onAppForeground();
    }
  }

  void _onAppBackground() {
    final activeTransfer = ref.read(activeTransferProvider);
    final receiveTransfer = ref.read(receiveTransferProvider);
    final serverPort = ref.read(activeServerPortProvider);
    final hasActiveWork = activeTransfer != null ||
        receiveTransfer != null ||
        serverPort > 0;

    if (!hasActiveWork) return;

    String title = '瞬息';
    String body = 'Running in background';
    if (activeTransfer != null &&
        activeTransfer.status == TransferStatus.transferring) {
      body = '发送文件中…';
    } else if (receiveTransfer != null &&
        receiveTransfer.status == TransferStatus.transferring) {
      body = '接收文件中…';
    }

    ForegroundServiceManager().start(title: title, body: body);
  }

  void _onAppForeground() {
    ForegroundServiceManager().stop();

    // 延迟触发发现刷新，快速恢复设备列表
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.read(onlineDevicesProvider.notifier).refreshNow();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = ref.watch(darkModeProvider);
    final currentIndex = ref.watch(currentTabProvider);
    final pendingOffer = ref.watch(pendingOfferProvider);
    ref.watch(clipboardAutoReceiveProvider);

    if (pendingOffer != null && pendingOffer != _lastShownOffer) {
      _lastShownOffer = pendingOffer;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(pendingOfferProvider) == pendingOffer) {
          _showReceiveConfirmDialog(pendingOffer);
        }
      });
    }

    ThemeMode themeMode;
    if (darkMode == true) {
      themeMode = ThemeMode.dark;
    } else if (darkMode == false) {
      themeMode = ThemeMode.light;
    } else {
      themeMode = ThemeMode.system;
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: '瞬息',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: 'HarmonyOS Sans SC',
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'HarmonyOS Sans SC',
      ),
      themeMode: themeMode,
      home: Scaffold(
        body: _pages[currentIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            ref.read(currentTabProvider.notifier).state = index;
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.devices),
              selectedIcon: Icon(Icons.devices),
              label: '设备',
            ),
            NavigationDestination(
              icon: Icon(Icons.swap_horiz),
              selectedIcon: Icon(Icons.swap_horiz),
              label: '传输',
            ),
            NavigationDestination(
              icon: Icon(Icons.history),
              selectedIcon: Icon(Icons.history),
              label: '历史',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings),
              selectedIcon: Icon(Icons.settings),
              label: '设置',
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiveConfirmDialog(TransferOffer offer) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    final onlineDevices = ref.read(onlineDevicesProvider);
    final sender = onlineDevices
        .where((d) => d.deviceId == offer.senderDeviceId)
        .firstOrNull;

    showDialog<bool>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (ctx) => ReceiveConfirmDialog(
        sender: sender ??
            Device(
              deviceId: offer.senderDeviceId,
              name: offer.senderDeviceName ?? offer.senderDeviceId,
              ip: '',
              port: 0,
              platform: 'unknown',
              protocolVersion: 1,
              lastSeen: DateTime.now(),
            ),
        files: offer.files,
        totalSize: offer.totalSize,
        folderMode: offer.folderMode,
      ),
    ).then((accepted) {
      final notifier = ref.read(connectionStateProvider.notifier);
      if (accepted == true) {
        notifier.acceptPendingOffer();
      } else {
        notifier.rejectPendingOffer();
      }
    });
  }
}
