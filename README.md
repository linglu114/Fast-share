# 瞬息 (FastShare) — 局域网文件传输应用

跨平台局域网文件传输，基于 Flutter + 自定义 FLP 协议。

## 平台支持

- **Android** 8.0+ (API 26)
- **Windows** 10 1809+
- 架构预留 macOS / iOS / Linux 扩展

## 核心特性

- **零配置发现**：UDP 广播自动扫描同局域网设备，WiFi 锁保持在线
- **二维码连接**：生成/扫描二维码快速建立连接，支持短码输入
- **极速传输**：TCP 明文高速传输，1MB 分块，跑满带宽
- **双 Isolate 引擎**：发送/接收各自运行在独立 Isolate，UI 线程零阻塞
- **性能保护**：256KB IO 缓冲、64MB 滑动窗口、令牌桶限速、电量/温度感知
- **设备信任**：6 位配对码验证 + SHA256 Token 持久化
- **剪贴板共享**：通过现有 TCP 连接推送文本
- **深色模式**：跟随系统 + 手动切换

## 快速开始

```bash
# 安装依赖
cd fastshare
flutter pub get

# Windows 运行
flutter run -d windows

# Android 运行
flutter run -d android
```

## 项目结构

```
fastshare/
├── lib/
│   ├── main.dart                  # 应用入口，权限请求，DB/日志初始化
│   ├── app.dart                   # MaterialApp 根组件，4-tab 导航框架
│   ├── models/                    # 数据模型
│   │   ├── device.dart            # Device / LocalDevice 模型
│   │   ├── transfer_task.dart     # TransferTask / FileTransferItem / 状态枚举
│   │   └── history_record.dart   # HistoryRecord 传输历史模型
│   ├── engine/                    # 传输引擎 (独立 Isolate)
│   │   ├── transfer_engine.dart   # 发送端 Engine Isolate — 文件读取/分片/CRC32/Socket 写入
│   │   ├── receive_engine.dart    # 接收端 Engine Isolate — 帧解析/磁盘写入/ACK 生成
│   │   ├── frame.dart             # FLP Frame Layer — 统一帧封装/解析 (magic/CRC32/16B 头)
│   │   ├── session.dart           # Session Layer — HELLO/HELLO_ACK/PING/PONG
│   │   ├── commands.dart          # Engine Isolate 命令/事件定义
│   │   ├── transfer_control.dart  # Control Layer — OFFER/ACCEPT/REJECT/CANCEL/PAUSE/RESUME
│   │   ├── pairing.dart           # 配对协议 — PAIR_REQUEST/CONFIRM/RESULT, 6 位码 + SHA256
│   │   ├── performance_guard.dart # IO/内存/并发保护 + 令牌桶限速
│   │   └── stress_test.dart       # 压力测试工具 (千文件/嵌套文件夹/弱网模拟)
│   ├── business/                  # 业务逻辑 (运行在 UI Isolate)
│   │   ├── discovery/
│   │   │   └── discovery_service.dart  # UDP 广播发现，设备上下线事件流
│   │   ├── connection/
│   │   │   └── connection_manager.dart # TCP 连接池，配对流程，传输 Offer/Accept，剪贴板中继
│   │   ├── clipboard/
│   │   │   └── clipboard_service.dart  # 剪贴板推送/接收，系统剪贴板写入
│   │   ├── transfer/
│   │   │   └── file_receiver.dart      # @Deprecated — 已迁移至 ReceiveEngine Isolate
│   │   └── network_manager.dart        # 多网卡智能选择，手动 IP 指定
│   ├── network/                   # 网络传输层
│   │   └── tcp_server.dart        # TCP 服务器 (端口 34568) + FLP 帧读写
│   ├── platform/                  # 平台抽象层
│   │   ├── platform_interface.dart
│   │   ├── platform_windows.dart
│   │   └── platform_android.dart
│   ├── storage/                   # 持久化
│   │   ├── database.dart          # SQLite 初始化 (移动端 native，桌面端 FFI)
│   │   ├── history_repository.dart
│   │   ├── settings_repository.dart
│   │   └── trusted_device_repository.dart  # 信任设备 + Token 存储
│   ├── providers/                 # Riverpod 状态管理
│   │   ├── discovery_provider.dart    # 在线设备列表，上下线事件流
│   │   ├── connection_provider.dart   # 连接状态，传输 Offer 接收，配对流程
│   │   ├── transfer_provider.dart     # 传输队列，活跃传输，Engine Isolate 管理
│   │   ├── settings_provider.dart     # 设备名/端口/限速/深色模式/下载路径 等配置
│   │   ├── clipboard_provider.dart    # 剪贴板服务，自动接收订阅
│   │   └── navigation_provider.dart   # 底部导航 Tab 索引
│   ├── ui/                        # 用户界面
│   │   ├── pages/
│   │   │   ├── devices/           # 设备与发现页 + 配对弹窗 + 二维码/短码/扫码
│   │   │   ├── transfer/          # 传输页 + 接收确认弹窗
│   │   │   ├── history/           # 传输历史页
│   │   │   └── settings/          # 设置页
│   │   └── widgets/
│   │       ├── transfer_progress_card.dart   # 传输进度卡片组件
│   │       └── performance_guard_indicator.dart  # 性能保护状态指示器
│   └── util/
│       ├── constants.dart         # 常量定义 (分块/IO/缓冲区大小，阈值，默认端口)
│       ├── logger.dart            # 文件日志 (异步写入 fastshare_debug.log)
│       ├── format.dart            # 格式化工具 (大小/速度/ETA/时间)
│       └── wifi_lock.dart         # Android WiFi 多播锁 (MethodChannel)
├── pubspec.yaml
├── FLP v1.2.md                    # 协议规范
├── 架构设计与任务拆解v2.md         # 架构设计文档
└── 项目需求v2.1.md                 # 需求规格说明书
```

## 通信协议

FLP（FastShare LAN Protocol）v1.2 — 四层自定义协议：

| 层 | 职责 |
|---|---|
| Frame Layer | 统一帧封装 (magic/CRC32/16B header) |
| Session Layer | TCP 握手 HELLO/ACK + 心跳 PING/PONG |
| Control Layer | 传输协商 OFFER/ACCEPT/REJECT，传输控制 PAUSE/RESUME/CANCEL，剪贴板推送 |
| Data Layer | 分块传输 CHUNK/ACK/NACK，断点续传 |

- 控制消息：UTF-8 JSON 封装在 FLP Frame 中
- 数据块：二进制结构体，含 chunk 索引、偏移、数据、CRC32 校验
- 默认 TCP 端口：34568
- 发现端口：UDP 45679

详见 [`FLP v1.2.md`](FLP%20v1.2.md)

## 压力测试

```dart
import 'engine/stress_test.dart';

final tool = StressTestTool();

// 生成 1000 个文件 (1KB~10MB)
final files = await tool.generateFiles(count: 1000);

// 生成嵌套文件夹结构
final folder = await tool.generateFolderStructure(depth: 5, filesPerDir: 50);

// 清理
await tool.cleanup();
```

## 技术栈

- Flutter 3.41 / Dart 3.11
- Riverpod 状态管理
- SQLite 本地存储 (sqflite + sqflite_common_ffi)
- 双独立 Isolate 传输引擎 (发送 + 接收)
- 自定义二进制协议 FLP v1.2 (Big Endian)
- UDP 广播设备发现
- MethodChannel 平台桥接 (Android + Windows)

## 许可证

GNU General Public License v3.0 — 详见 [LICENSE](LICENSE)
