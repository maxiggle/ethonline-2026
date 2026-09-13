/// Formats USDC atomic units (6 decimals) as a money-style decimal string,
/// without going through floating point, since amounts come from the API as
/// strings and can be arbitrarily large.
///
/// Always shows at least 2 decimal places (`$2.50`), but keeps trailing
/// digits beyond that when they carry real value (`$0.005`) instead of
/// rounding sub-cent amounts away.
class UsdcAmountFormatter {
  const UsdcAmountFormatter._();

  static const int decimals = 6;
  static const int _minDecimals = 2;

  static String format(String atomicUnits) {
    final value = BigInt.parse(atomicUnits);
    final divisor = BigInt.from(10).pow(decimals);
    final whole = value ~/ divisor;
    var fraction = (value % divisor).abs().toString().padLeft(decimals, '0');

    while (fraction.length > _minDecimals && fraction.endsWith('0')) {
      fraction = fraction.substring(0, fraction.length - 1);
    }

    return '$whole.$fraction';
  }
}
