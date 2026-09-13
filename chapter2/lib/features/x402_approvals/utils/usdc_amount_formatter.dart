/// Formats USDC atomic units (6 decimals) as an exact decimal string,
/// without going through floating point, since amounts come from the API as
/// strings and can be arbitrarily large.
class UsdcAmountFormatter {
  const UsdcAmountFormatter._();

  static const int decimals = 6;

  static String format(String atomicUnits) {
    final value = BigInt.parse(atomicUnits);
    final divisor = BigInt.from(10).pow(decimals);
    final whole = value ~/ divisor;
    final fraction = (value % divisor).abs().toString().padLeft(decimals, '0');
    return '$whole.$fraction';
  }
}
