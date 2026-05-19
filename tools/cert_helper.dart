import 'dart:io';
import 'dart:math';

/// 证书更新辅助脚本
///
/// 用法:
/// dart tools/cert_helper.dart [path/to/new.crt]
///
/// 默认读取项目根目录下的 new.crt
void main(List<String> args) async {
  final String inputPath = args.isNotEmpty ? args[0] : 'new.crt';
  final File certFile = File(inputPath);

  if (!await certFile.exists()) {
    print('Error: Certificate file not found at $inputPath');
    print('Usage: dart tools/cert_helper.dart [path/to/new.crt]');
    exit(1);
  }

  print('Reading certificate from $inputPath...');
  final List<int> bytes = await certFile.readAsBytes();

  // 保持与 cert_data.dart 中一致的加密向量
  // 如果需要更换向量，请同时修改这里和生成的代码
  final List<int> kCertV = [
    25,
    204,
    36,
    232,
    71,
    199,
    93,
    36,
    51,
    126,
    142,
    203,
    246,
    252,
    66,
    6,
  ];

  print('Encrypting ${bytes.length} bytes...');
  final List<int> encrypted = [];
  for (int i = 0; i < bytes.length; i++) {
    encrypted.add(bytes[i] ^ kCertV[i % kCertV.length]);
  }

  // 将数据切分为4个部分，模拟混淆结构
  int partSize = (encrypted.length / 4).ceil();
  List<List<int>> parts = [];
  for (int i = 0; i < encrypted.length; i += partSize) {
    parts.add(encrypted.sublist(i, min(i + partSize, encrypted.length)));
  }

  // 确保至少有4个部分（处理空文件或极小文件的情况）
  while (parts.length < 4) {
    parts.add([]);
  }

  final StringBuffer buffer = StringBuffer();
  buffer.writeln('class CertData {');
  buffer.writeln('  static const List<int> kCertV = [');
  buffer.write('    ');
  buffer.write(kCertV.join(', '));
  buffer.writeln(',');
  buffer.writeln('  ];');
  buffer.writeln('');

  // 保持变量名混淆
  final List<String> varNames = [
    'kData4c1gLYNgA0UdrO3Ww0FH',
    'kData3SdqlIdEvI2UwYvpg8WY',
    'kDataagv7gegPRzgk3f8O4qOJ',
    'kDataE9Z63a8ZwbqAycZ0ZbTn',
  ];

  for (int i = 0; i < 4; i++) {
    buffer.writeln('  static const List<int> ${varNames[i]} = [');
    final part = parts[i];
    if (part.isNotEmpty) {
      for (int j = 0; j < part.length; j += 16) {
        // 每行16个字节，保持美观
        buffer.write('    ');
        buffer.write(part.sublist(j, min(j + 16, part.length)).join(', '));
        buffer.writeln(',');
      }
    }
    buffer.writeln('  ];');
    if (i < 3) buffer.writeln('');
  }
  buffer.writeln('}');

  final String targetPath = 'lib/core/security/cert_data.dart';
  final File outFile = File(targetPath);

  // 确保目标目录存在
  if (!await outFile.parent.exists()) {
    print('Error: Target directory lib/core/security/ does not exist.');
    exit(1);
  }

  await outFile.writeAsString(buffer.toString());
  print('Successfully updated $targetPath');
  print('Original size: ${bytes.length} bytes');
  print('Encrypted size: ${encrypted.length} bytes');
}
