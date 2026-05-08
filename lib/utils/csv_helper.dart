class CsvHelper {
  /// Sentinel: Hardens a field for CSV export by:
  /// 1. Escaping double quotes (replacing " with "") to maintain structure.
  /// 2. Protecting against CSV Formula Injection (prepending ' to fields
  ///    starting with =, +, -, or @).
  static String escapeField(String value) {
    if (value.isEmpty) return '';

    // Protect against Formula Injection
    final firstChar = value[0];
    if (firstChar == '=' || firstChar == '+' || firstChar == '-' || firstChar == '@') {
      value = "'$value";
    }

    // Escape double quotes
    return value.replaceAll('"', '""');
  }
}
