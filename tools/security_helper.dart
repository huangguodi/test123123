import 'dart:convert';

// Security Helper Tool
// 用于快速生成混淆代码和加密参数
//
// 使用方法:
// 1. 生成指纹代码: dart tools/security_helper.dart sig "30:D6:..."
// 2. 生成加密参数: dart tools/security_helper.dart encrypt "https://..." "[153, 154, ...]"

void main(List<String> args) {
  if (args.isEmpty) {
    printUsage();
    return;
  }

  final command = args[0];

  if (command == 'sig') {
    if (args.length < 2) {
      print('Error: Missing signature string.');
      return;
    }
    generateSignatureCode(args[1]);
  } else if (command == 'encrypt') {
    if (args.length < 3) {
      print('Error: Missing target URL or Native Key.');
      print(
        'Usage: dart tools/security_helper.dart encrypt <url> <native_key_json_list> [variable_name]',
      );
      return;
    }
    final varName = args.length > 3 ? args[3] : '_kBaseParams';
    encryptParams(args[1], args[2], varName);
  } else {
    printUsage();
  }
}

void printUsage() {
  print('Security Helper Tool');
  print('--------------------');
  print('Commands:');
  print(
    '  sig <signature_string>       Generate ASCII char codes for obfuscator.dart',
  );
  print(
    '  encrypt <url> <native_key> [var_name]   Generate encrypted params using Native Key',
  );
  print('');
  print('Example (Sig):');
  print('  dart tools/security_helper.dart sig "30:D6:..."');
  print('');
  print('Example (Encrypt Android):');
  print(
    '  dart tools/security_helper.dart encrypt "https://api.com" "[...]" _kBaseParamsAndroid',
  );
  print('Example (Encrypt iOS):');
  print(
    '  dart tools/security_helper.dart encrypt "https://api.com" "[...]" _kBaseParamsIOS',
  );
}

void generateSignatureCode(String sig) {
  final codes = sig.codeUnits;
  print('\n[Obfuscator Config] Copy into candidateSigs:\n');
  print('String.fromCharCodes($codes)');
  print('');
}

void encryptParams(String target, String nativeKeyJson, String varName) {
  try {
    final List<dynamic> parsedKey = jsonDecode(nativeKeyJson);
    final List<int> nativeKey = parsedKey.cast<int>();

    // 注意：此 Vector 必须与 lib/core/security/obfuscator.dart 中的 _kBaseVector 保持一致
    final List<int> vector = [189, 45, 187, 187, 24, 162, 222, 200];

    final List<int> targetBytes = utf8.encode(target);
    final List<int> encrypted = [];

    for (int i = 0; i < targetBytes.length; i++) {
      int v = vector[i % vector.length];
      int k = nativeKey[i % nativeKey.length];
      int t = targetBytes[i];
      encrypted.add(t ^ v ^ k);
    }

    print('\n[Obfuscator Config] Copy into $varName:\n');
    final buffer = StringBuffer();
    buffer.writeln('  static const List<int> $varName = [');
    for (int b in encrypted) {
      buffer.writeln('    $b,');
    }
    buffer.write('  ];');
    print(buffer.toString());
    print('');
  } catch (e) {
    print('Error parsing Native Key: $e');
    print('Ensure the key is a valid JSON list, e.g., "[1, 2, 3]"');
  }
}
