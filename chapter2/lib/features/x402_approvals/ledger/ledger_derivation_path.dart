import 'dart:typed_data';

/// Encodes a BIP-32 derivation path the way the Ledger Ethereum app expects
/// it in APDU payloads: one byte giving the number of path components,
/// followed by each component as a big-endian uint32 (hardened components
/// OR'd with `0x80000000`).
class LedgerDerivationPath {
  const LedgerDerivationPath._();

  static const int _hardenedOffset = 0x80000000;

  /// `44'/60'/0'/0/0`, the fixed Ethereum path this app signs with.
  static final Uint8List ethereumDefault = _encode(const [
    44 + _hardenedOffset,
    60 + _hardenedOffset,
    0 + _hardenedOffset,
    0,
    0,
  ]);

  static Uint8List _encode(List<int> components) {
    final data = ByteData(1 + components.length * 4);
    data.setUint8(0, components.length);
    for (var i = 0; i < components.length; i++) {
      data.setUint32(1 + i * 4, components[i], Endian.big);
    }
    return data.buffer.asUint8List();
  }
}
