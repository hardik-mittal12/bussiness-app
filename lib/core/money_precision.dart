import 'dart:math' as math;

/// Centralized monetary precision utility using integer minor units (paise) internally
/// to eliminate IEEE 754 floating-point accumulation errors (e.g. 0.1 + 0.2 != 0.3).
class MoneyPrecision {
  /// Converts double major units (Rupees) to integer minor units (Paise).
  /// 1 Rupee = 100 Paise.
  static int toPaise(double amount) {
    return (amount * 100.0).round();
  }

  /// Converts integer minor units (Paise) to double major units (Rupees).
  static double toRupees(int paise) {
    return paise / 100.0;
  }

  /// Adds list of double amounts with exact minor unit precision
  static double sum(List<double> amounts) {
    int totalPaise = 0;
    for (final amount in amounts) {
      totalPaise += toPaise(amount);
    }
    return toRupees(totalPaise);
  }

  /// Multiplies quantity and unit price with exact rounding to nearest paise
  static double calculateLineTotal(double quantity, double unitRate) {
    // Quantity can have decimals (e.g., 2.5 kg at 45.50/kg)
    final double raw = quantity * unitRate;
    return toRupees(toPaise(raw));
  }

  /// Calculates discount amount given subtotal and discount percentage or fixed amount
  static double calculateDiscount({
    required double subtotal,
    double discountPercentage = 0.0,
    double fixedDiscount = 0.0,
  }) {
    final int subtotalPaise = toPaise(subtotal);
    int discountPaise = toPaise(fixedDiscount);

    if (discountPercentage > 0.0) {
      final double rawPctDiscount = (subtotalPaise * discountPercentage) / 100.0;
      discountPaise += rawPctDiscount.round();
    }

    // Ensure discount does not exceed subtotal
    discountPaise = math.min(discountPaise, subtotalPaise);
    return toRupees(discountPaise);
  }

  /// Calculates tax amount for a taxable amount given tax rate percentage
  static double calculateTax(double taxableAmount, double taxRatePercentage) {
    if (taxRatePercentage <= 0.0) return 0.0;
    final int taxablePaise = toPaise(taxableAmount);
    final double rawTax = (taxablePaise * taxRatePercentage) / 100.0;
    return toRupees(rawTax.round());
  }

  /// Rounds a double amount to 2 decimal places cleanly
  static double round(double amount) {
    return toRupees(toPaise(amount));
  }

  /// Formats amount to standard 2-decimal string (e.g. 1250.50)
  static String format(double amount) {
    return round(amount).toStringAsFixed(2);
  }
}
