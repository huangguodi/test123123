import 'dart:io';
import 'package:flutter/services.dart';
import 'package:safe_device/safe_device.dart';
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
    // Android: 已移除 APK 证书指纹校验，便于更换签名证书
    if (!Platform.isAndroid) {
      await _checkAppSignature();
    }

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

  /// iOS 可选签名校验（当前未启用强制比对）
  Future<void> _checkAppSignature() async {
    if (Platform.isIOS) {
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
