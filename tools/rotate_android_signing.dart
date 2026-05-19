import 'dart:convert';

/// Decrypt/encrypt Android _kBaseParams (native derivedKey + vector XOR).
List<int> _kBaseVector = [189, 45, 187, 187, 24, 162, 222, 200];

String decryptParams(List<int> data, String sigColonHex) {
  final sigBytes = utf8.encode(sigColonHex);
  final derivedKey = sigBytes.map((b) => b ^ 0xAA).toList();
  final temp = List<int>.generate(
    data.length,
    (i) => data[i] ^ derivedKey[i % derivedKey.length],
  );
  return String.fromCharCodes(
    List.generate(
      temp.length,
      (i) => temp[i] ^ _kBaseVector[i % _kBaseVector.length],
    ),
  );
}

List<int> encryptParams(String url, String sigColonHex) {
  final sigBytes = utf8.encode(sigColonHex);
  final derivedKey = sigBytes.map((b) => b ^ 0xAA).toList();
  final urlBytes = utf8.encode(url);
  return List<int>.generate(
    urlBytes.length,
    (i) =>
        urlBytes[i] ^
        derivedKey[i % derivedKey.length] ^
        _kBaseVector[i % _kBaseVector.length],
  );
}

String cppPrefixArray(String sigColonHex) {
  final prefix = sigColonHex.substring(0, 8);
  final bytes = utf8.encode(prefix);
  return bytes.map((b) => '0x${b.toRadixString(16).toUpperCase().padLeft(2, '0')}').join(', ');
}

void main(List<String> args) {
  const oldSig =
      '30:D6:18:9E:EB:AB:FE:B9:45:53:63:A9:AD:56:D1:A4:52:9F:CE:95:D9:88:2D:3D:AE:D4:77:37:BC:84:95:93';
  const data = [
    76, 195, 95, 37, 247, 8, 106, 117, 25, 141, 122, 26, 196, 115, 96, 18, 102,
    142, 121, 101, 190, 126,
  ];

  if (args.isEmpty) {
    final url = decryptParams(data, oldSig).trim();
    print('DECRYPTED_URL=$url');
    return;
  }

  final newSig = args[0];
  final url = args.length > 1 ? args[1] : decryptParams(data, oldSig).trim();
  final enc = encryptParams(url, newSig);
  print('URL=$url');
  print('NEW_SIG=$newSig');
  print('CPP_PREFIX=${cppPrefixArray(newSig)}');
  print('ENCRYPTED=$enc');
  print('SIG_CODES=${newSig.codeUnits}');
}
