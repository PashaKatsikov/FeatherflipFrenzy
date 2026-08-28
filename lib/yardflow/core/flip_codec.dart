import 'dart:convert';

/// Project-unique XOR mask. Combined with the bundle id at encode/decode
/// time so the key is not a standalone constant in the binary.
const List<int> _flipMask = <int>[
  0x43, 0x6F, 0x6F, 0x70, 0x2A, 0x46, 0x66, 0x35, 0x2E, 0x7A, 0x4B, 0x91,
  0x2B, 0x33, 0xC4, 0x1E,
];

const String _bundleHint = 'com.featherflipfrenzy.featherflipfrenzygame';
const String _buildHint = '1.0.3+5';

List<int> _xorKey() {
  final seed = <int>[
    ...utf8.encode(_bundleHint),
    ...utf8.encode(_buildHint),
    ..._flipMask,
  ];
  return seed;
}

int _mixAt(int index, List<int> key) {
  return key[(index * 37 + 13) % key.length] ^ ((index * 17) & 0x7F);
}

/// Ordinary base64 + one-pass position-keyed XOR. Not a stream cipher.
List<int> foldYard(String value) {
  if (value.isEmpty) return const <int>[];
  final key = _xorKey();
  final plain = utf8.encode(value);
  final mixed = List<int>.generate(
    plain.length,
    (i) => plain[i] ^ _mixAt(i, key),
  );
  return base64Encode(mixed).codeUnits;
}

String unfoldYard(List<int> encoded) {
  if (encoded.isEmpty) return '';
  final key = _xorKey();
  final mixed = base64Decode(String.fromCharCodes(encoded));
  final plain = List<int>.generate(
    mixed.length,
    (i) => mixed[i] ^ _mixAt(i, key),
  );
  return utf8.decode(plain);
}
