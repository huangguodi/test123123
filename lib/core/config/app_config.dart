import 'dart:convert';

import 'package:flutter/services.dart';

/// 打包后可修改的配置（随 APK/IPA 内 assets 分发）。
///
/// Android APK 解压后路径示例：
/// `assets/flutter_assets/assets/app_config.json`
///
/// iOS IPA 解压后路径示例：
/// `Payload/Runner.app/Frameworks/App.framework/flutter_assets/assets/app_config.json`
class AppConfig {
  static const String assetPath = 'assets/app_config.json';
  static const String defaultIndexId = '10';

  static String indexId = defaultIndexId;
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString(assetPath);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final id = map['index_id']?.toString().trim();
      if (id != null && id.isNotEmpty) {
        indexId = id;
      }
    } catch (_) {
      indexId = defaultIndexId;
    }
    _loaded = true;
  }

  static String buildIndexUrl(String apiBase) {
    if (apiBase.isEmpty) return '';
    final base = apiBase.endsWith('/')
        ? apiBase.substring(0, apiBase.length - 1)
        : apiBase;
    return '$base/index/$indexId';
  }
}
