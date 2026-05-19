import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:android_id/android_id.dart';

class DeviceIdService {
  static const String _storageKey = 'device_unique_id';
  static String? _cachedId;

  /// 获取设备唯一标识符
  /// 优先级：内存缓存 > 本地存储 > 系统ID (Android ID/IDFV) > 随机UUID
  static Future<String> getDeviceId() async {
    // 1. 内存缓存
    if (_cachedId != null && _cachedId!.isNotEmpty) {
      return _cachedId!;
    }

    // 2. 本地存储 (持久化)
    final prefs = await SharedPreferences.getInstance();
    String? storedId = prefs.getString(_storageKey);
    if (storedId != null && storedId.isNotEmpty) {
      _cachedId = storedId;
      return storedId;
    }

    // 3. 系统ID
    String? systemId;
    try {
      if (Platform.isAndroid) {
        // 使用 android_id 插件获取 Android ID
        const androidIdPlugin = AndroidId();
        systemId = await androidIdPlugin.getId();
      } else if (Platform.isIOS) {
        // 使用 device_info_plus 获取 IDFV
        final deviceInfo = DeviceInfoPlugin();
        final iosInfo = await deviceInfo.iosInfo;
        systemId = iosInfo.identifierForVendor;
      }
    } catch (e) {
      // 忽略错误，降级到 UUID
      // print('获取系统ID失败: $e');
    }

    // 4. 生成 UUID (兜底)
    if (systemId == null || systemId.isEmpty || systemId == 'null') {
      systemId = const Uuid().v4();
    }

    // 5. 保存并返回
    await prefs.setString(_storageKey, systemId);
    _cachedId = systemId;
    return systemId;
  }
}
