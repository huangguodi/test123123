import 'dart:io';
import 'package:flutter/services.dart';
import 'package:safe_device/safe_device.dart';
import 'package:logger/logger.dart';
import 'obfuscator.dart';

class SecurityService {
  // final Logger _logger = Logger();

  /// 运行全面的环境安全检查
  /// 如果环境不安全，可能会抛出异常或直接退出应用
  Future<bool> isDeviceSafe() async {
    try {
      bool isJailbroken = await SafeDevice.isJailBroken;
      bool isRealDevice = await SafeDevice.isRealDevice;

      return !isJailbroken && isRealDevice;
    } catch (e) {
      return false;
    }
  }

  /// 运行全面的环境安全检查
  /// 如果环境不安全，可能会抛出异常或直接退出应用
  Future<void> ensureSecureEnvironment() async {
    // 0. Code Integrity Check (Honeypot/Repackaging Defense)
    await _checkAppSignature();

    // 1. Root / Jailbreak Detection
    bool isJailbroken = false;
    try {
      isJailbroken = await SafeDevice.isJailBroken;
    } catch (e) {
      // Ignore
    }

    if (isJailbroken) {
      _terminateApp('Root/Jailbreak Detected');
    }

    // 2. Emulator Detection
    bool isRealDevice = true;
    try {
      isRealDevice = await SafeDevice.isRealDevice;
    } catch (e) {
      // Ignore
    }

    if (!isRealDevice) {
      _terminateApp('Emulator Detected');
    }

    // 3. Proxy / VPN Detection (Optional but recommended)
    // Dart HttpClient findProxy='DIRECT' 已经能防御大部分 HTTP 代理抓包
  }

  /// 校验应用签名（核心完整性校验）
  /// 这里的签名 Hash 应为你的生产证书 SHA-256
  Future<void> _checkAppSignature() async {
    // 已从 Obfuscator.appSignature 统一获取真实指纹
    final String expectedHash = Obfuscator.appSignature;

    if (Platform.isAndroid) {
      try {
        const platform = MethodChannel('com.example.address/security');
        final String? currentSignature = await platform.invokeMethod<String>('getAppSignature');

        if (currentSignature == null || currentSignature != expectedHash) {
          _terminateApp('Code Integrity Violation: Signature Mismatch');
        } else {
          // Signature Verified
        }
      } catch (e) {
        // 签名获取失败通常意味着环境异常，建议终止
        _terminateApp('Signature Check Failed: $e');
      }
    } else if (Platform.isIOS) {
      try {
        const platform = MethodChannel('com.example.address/security');
        final String? currentSignature = await platform.invokeMethod<String>('getAppSignature');

        if (currentSignature != null) {
          // 注意：此处应比对 iOS 专用签名 (Obfuscator.iosAppSignature)
          // 由于目前 Obfuscator.appSignature 仅存储 Android 指纹，
          // 暂时仅打印指纹供配置使用，不执行强制 Crash，避免误杀。
          // 待 iOS 指纹配置到位后，可启用下方逻辑：
          /*
          if (currentSignature != Obfuscator.iosAppSignature) {
             _terminateApp('Code Integrity Violation: iOS Signature Mismatch');
          }
          */
        }
      } catch (e) {
        // Ignore
      }
    }
  }

  void _terminateApp(String reason) {
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else if (Platform.isIOS) {
      exit(0);
    }
  }
}
