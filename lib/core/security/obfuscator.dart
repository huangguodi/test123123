import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'cert_data.dart';

typedef DecryptWithSignatureNative =
    Void Function(
      Pointer<Uint8> data,
      IntPtr dataLen,
      Pointer<Uint8> sigBytes,
      IntPtr sigLen,
    );
typedef DecryptWithSignature =
    void Function(
      Pointer<Uint8> data,
      int dataLen,
      Pointer<Uint8> sigBytes,
      int sigLen,
    );

class Obfuscator {
  static final DynamicLibrary _nativeLib = Platform.isAndroid
      ? DynamicLibrary.open("libnative_security.so")
      : DynamicLibrary.process();

  static final DecryptWithSignature _decryptNative = _nativeLib
      .lookup<NativeFunction<DecryptWithSignatureNative>>(
        "decrypt_with_signature",
      )
      .asFunction();

  static const List<int> _kBaseVector = [189, 45, 187, 187, 24, 162, 222, 200];

  /// 统一获取应用签名指纹（已混淆）
  /// 供 Native 解密和 SecurityService 校验使用
  static String get appSignature {
    if (Platform.isIOS) {
      // iOS Hardcoded Integrity Hash (Managed by tools/ios_security_tool.dart)
      // 7C:9F:B4:1E:CC:39:BB:98:34:81:D3:3B:12:DC:E4:BD:5C:92:1F:82:83:71:20:03:63:92:22:20:BB:0C:90:EE
      return String.fromCharCodes([
        55,
        67,
        58,
        57,
        70,
        58,
        66,
        52,
        58,
        49,
        69,
        58,
        67,
        67,
        58,
        51,
        57,
        58,
        66,
        66,
        58,
        57,
        56,
        58,
        51,
        52,
        58,
        56,
        49,
        58,
        68,
        51,
        58,
        51,
        66,
        58,
        49,
        50,
        58,
        68,
        67,
        58,
        69,
        52,
        58,
        66,
        68,
        58,
        53,
        67,
        58,
        57,
        50,
        58,
        49,
        70,
        58,
        56,
        50,
        58,
        56,
        51,
        58,
        55,
        49,
        58,
        50,
        48,
        58,
        48,
        51,
        58,
        54,
        51,
        58,
        57,
        50,
        58,
        50,
        50,
        58,
        50,
        48,
        58,
        66,
        66,
        58,
        48,
        67,
        58,
        57,
        48,
        58,
        69,
        69,
      ]);
    }
    // Android Signature (ci-debug.keystore)
    return String.fromCharCodes([
      67, 66, 58, 56, 69, 58, 48, 69, 58, 70, 70, 58, 65, 65, 58, 68, 66, 58, 66,
      51, 58, 51, 70, 58, 54, 49, 58, 67, 67, 58, 57, 68, 58, 65, 70, 58, 69, 66,
      58, 49, 70, 58, 65, 67, 58, 70, 57, 58, 69, 67, 58, 50, 49, 58, 48, 48, 58,
      56, 67, 58, 53, 68, 58, 51, 54, 58, 68, 55, 58, 54, 49, 58, 49, 56, 58, 48,
      56, 58, 52, 55, 58, 67, 66, 58, 68, 55, 58, 69, 54, 58, 66, 67, 58, 50, 51,
    ]);
  }

  static const List<int> _kBaseParamsAndroid = [
    60,
    177,
    95,
    89,
    132,
    8,
    107,
    8,
    25,
    242,
    121,
    26,
    192,
    112,
    96,
    23,
    102,
    142,
    125,
    19,
    190,
    15,
  ];

  static const List<int> _kBaseParamsIOS = [
    72,
    176,
    95,
    88,
    135,
    8,
    25,
    121,
    25,
    133,
    122,
    26,
    194,
    114,
    96,
    96,
    29,
    142,
    125,
    98,
    190,
    5,
  ];

  /// Hive Box Name "upload_history" (Obfuscated)
  static const List<int> historyBoxBytes = [
    200,
    93,
    215,
    212,
    121,
    198,
    129,
    160,
    212,
    94,
    207,
    212,
    106,
    219,
  ];

  /// 解密后的 API 根地址（不含路径后缀）
  static String get apiBase {
    if (Platform.isIOS) {
      return _decryptViaDartIOS(_kBaseParamsIOS);
    }
    return _decryptViaNative(_kBaseParamsAndroid);
  }

  /// 2026 Refactor: 简化路径逻辑，仅保留基础地址加密
  static String get syncTarget {
    final String base = apiBase;
    if (base.isEmpty) return "";
    return "$base/upload_x9s8k2";
  }

  /// iOS 专用 Dart 层解密实现
  /// 逻辑与 tools/ios_security_tool.dart 保持逆向一致
  static String _decryptViaDartIOS(List<int> data) {
    try {
      final String sig = appSignature;
      final List<int> sigBytes = sig.codeUnits;

      // 1. Derive Key (Sig ^ 0xAA)
      final List<int> derivedKey = sigBytes.map((b) => b ^ 0xAA).toList();

      // 2. Layer 1 Decrypt (Data ^ DerivedKey)
      final List<int> temp = [];
      for (int i = 0; i < data.length; i++) {
        temp.add(data[i] ^ derivedKey[i % derivedKey.length]);
      }

      // 3. Layer 2 Decrypt (Vector XOR) & Clean
      String decrypted = _applyVectorXor(temp).trim();

      if (decrypted.startsWith('http')) {
        if (decrypted.endsWith('/')) {
          decrypted = decrypted.substring(0, decrypted.length - 1);
        }
        return decrypted;
      }
      return "";
    } catch (e) {
      return "";
    }
  }

  static String _decryptViaNative(List<int> data) {
    // 智能密钥发现策略 (Smart Key Discovery)
    // 即使攻击者修改了这里的签名并重打包 App，由于底层数据 _kBaseParams 是用官方签名强加密的，
    // 使用攻击者的签名解密只会得到乱码。这构成了"签名-数据"的死锁防护。
    final List<String> candidateSigs = [
      // 当前环境指纹 (修改指纹请参考项目根目录 sign.md)
      appSignature,
    ];

    Pointer<Uint8>? dataPtr;
    Pointer<Uint8>? sigPtr;

    try {
      // 遍历所有可能的密钥
      for (final sig in candidateSigs) {
        // 针对每个密钥，尝试多种传递格式
        final List<List<int>> formats = [
          // 格式 A: 32字节原始二进制 (最可能的正确格式)
          sig.split(':').map((e) => int.parse(e, radix: 16)).toList(),
          // 格式 B: UTF-8 字符串 (兼容旧版逻辑)
          utf8.encode(sig),
          // 格式 C: 无冒号小写字符串 (某些特定加密库的习惯)
          utf8.encode(sig.replaceAll(':', '').toLowerCase()),
        ];

        for (int fmtIdx = 0; fmtIdx < formats.length; fmtIdx++) {
          final sigBytes = formats[fmtIdx];
          try {
            // 分配原生内存
            dataPtr = malloc.allocate<Uint8>(data.length);
            sigPtr = malloc.allocate<Uint8>(sigBytes.length);

            // 填充数据
            for (int i = 0; i < data.length; i++) dataPtr[i] = data[i];
            for (int i = 0; i < sigBytes.length; i++) sigPtr![i] = sigBytes[i];

            // 调用原生解密
            _decryptNative(dataPtr, data.length, sigPtr, sigBytes.length);

            // 提取结果并进行异或还原
            List<int> nativeResult = [];
            for (int i = 0; i < data.length; i++) {
              nativeResult.add(dataPtr[i]);
            }
            String decrypted = _applyVectorXor(nativeResult).trim();

            // 验证解密结果有效性
            if (decrypted.startsWith('http')) {
              if (decrypted.endsWith('/')) {
                decrypted = decrypted.substring(0, decrypted.length - 1);
              }
              return decrypted; // 成功解密，立即返回
            }
          } catch (e) {
            // 当前尝试失败，继续下一次尝试
            continue;
          } finally {
            // 每次尝试后必须释放内存，避免泄漏和污染
            if (dataPtr != null) {
              malloc.free(dataPtr);
              dataPtr = null;
            }
            if (sigPtr != null) {
              malloc.free(sigPtr);
              sigPtr = null;
            }
          }
        }
      }
      // 所有尝试均失败
      return "";
    } catch (e) {
      return "";
    }
  }

  static String _applyVectorXor(List<int> bytes) {
    final buffer = StringBuffer();
    for (int i = 0; i < bytes.length; i++) {
      buffer.writeCharCode(bytes[i] ^ _kBaseVector[i % _kBaseVector.length]);
    }
    return buffer.toString();
  }

  static List<int> get sslBytes {
    final List<int> combined = [
      ...CertData.kData4c1gLYNgA0UdrO3Ww0FH,
      ...CertData.kData3SdqlIdEvI2UwYvpg8WY,
      ...CertData.kDataagv7gegPRzgk3f8O4qOJ,
      ...CertData.kDataE9Z63a8ZwbqAycZ0ZbTn,
    ];
    final List<int> decrypted = [];
    for (var i = 0; i < combined.length; i++) {
      decrypted.add(combined[i] ^ CertData.kCertV[i % CertData.kCertV.length]);
    }
    return decrypted;
  }

  /// 动态解密混淆后的字节码
  static String deobfuscate(List<int> bytes) {
    final buffer = StringBuffer();
    for (var i = 0; i < bytes.length; i++) {
      // 使用基础向量循环异或
      buffer.writeCharCode(bytes[i] ^ _kBaseVector[i % _kBaseVector.length]);
    }
    return buffer.toString();
  }
}
