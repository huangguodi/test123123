import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';

void main(List<String> args) {
  final runnerDir = Directory('ios/Runner');
  if (!runnerDir.existsSync()) {
    print('Error: ios/Runner directory not found. Please run from project root.');
    exit(1);
  }

  final keyFile = File('${runnerDir.path}/integrity_check');
  
  if (args.isEmpty || args.contains('help')) {
    printUsage();
    return;
  }

  final command = args[0];

  if (command == 'generate') {
    generateKeyFile(keyFile);
  } else if (command == 'show') {
    if (!keyFile.existsSync()) {
      print('Key file not found. Run "generate" first.');
      return;
    }
    showConfig(keyFile);
  } else if (command == 'encrypt') {
    if (args.length < 2) {
      print('Usage: encrypt <url>');
      return;
    }
    print('Input URL: "${args[1]}" (Length: ${args[1].length})');
    encryptUrl(keyFile, args[1]);
  } else {
    printUsage();
  }
}

void printUsage() {
  print('iOS Security Helper Tool');
  print('------------------------');
  print('Commands:');
  print('  generate   Generate a new random integrity_check file in ios/Runner/');
  print('  show       Calculate hash and show C++/Dart configuration code');
  print('  encrypt <url>  Encrypt a URL using the current integrity hash');
}

void generateKeyFile(File file) {
  final random = Random.secure();
  final values = List<int>.generate(1024, (i) => random.nextInt(256));
  file.writeAsBytesSync(values);
  print('Generated ${file.path} (${values.length} bytes)');
  showConfig(file);
}

void showConfig(File file) {
  final hash = _getHash(file);
  
  // Format as Colon-Separated (like Android Fingerprint) for consistency
  final formattedHash = _formatAsColonHex(hash);
  
  print('\n[iOS Integrity Hash]');
  print(formattedHash);
  
  print('\n[1. C++ Config (native-lib.cpp)]');
  print('Add this to the prefix check in decrypt_with_signature:');
  final prefixBytes = formattedHash.split(':').take(8).map((e) => "0x$e").join(', ');
  print('const uint8_t ios_prefix[] = { $prefixBytes };');
  
  print('\n[2. Dart Config (obfuscator.dart)]');
  print('Update get appSignature for iOS:');
  final codes = formattedHash.codeUnits;
  print('return String.fromCharCodes($codes);');
  
  print('\n[3. Swift Config (AppDelegate.swift)]');
  print('Ensure getAppSignature reads "integrity_check" from bundle.');
}

String _getHash(File file) {
  final bytes = file.readAsBytesSync();
  final digest = sha256.convert(bytes);
  return digest.toString().toUpperCase();
}

void encryptUrl(File file, String url) {
  if (!file.existsSync()) {
    print('Key file not found. Run "generate" first.');
    return;
  }
  
  final hash = _getHash(file);
  final formattedHash = _formatAsColonHex(hash);
  final sigBytes = formattedHash.codeUnits;
  
  // Native Logic Simulation: Derived Key = SigBytes ^ 0xAA
  final derivedKey = sigBytes.map((b) => b ^ 0xAA).toList();
  
  // Obfuscator Logic: Encrypted = URL ^ Vector ^ DerivedKey
  // Vector from obfuscator.dart
  final vector = [189, 45, 187, 187, 24, 162, 222, 200];
  final targetBytes = utf8.encode(url);
  final encrypted = <int>[];

  for (int i = 0; i < targetBytes.length; i++) {
    int v = vector[i % vector.length];
    int k = derivedKey[i % derivedKey.length];
    int t = targetBytes[i];
    encrypted.add(t ^ v ^ k);
  }

  print('Encrypted count: ${encrypted.length}');
  print('Encrypted list: $encrypted');

  print('\n[Obfuscator Config] Copy into _kBaseParamsIOS:\n');
  final buffer = StringBuffer();
  buffer.writeln('  static const List<int> _kBaseParamsIOS = [');
  for (int b in encrypted) {
    buffer.writeln('    $b,');
  }
  buffer.write('  ];');
  print(buffer.toString());
}

String _formatAsColonHex(String hex) {
  final buffer = StringBuffer();
  for (int i = 0; i < hex.length; i += 2) {
    if (i > 0) buffer.write(':');
    buffer.write(hex.substring(i, i + 2));
  }
  return buffer.toString();
}
