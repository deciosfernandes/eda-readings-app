class CsvHelper {
  static String escapeField(String value) {
    if (value.isEmpty) return '';

    // SENTINEL: Protect against CSV formula injection by prepending a tab.
    // Tab is invisible in spreadsheets and does not corrupt the value on re-import.
    final firstChar = value[0];
    if (firstChar == '=' || firstChar == '+' || firstChar == '-' || firstChar == '@') {
      value = '\t$value';
    }

    return value.replaceAll('"', '""');
  }

  /// Strip the tab prefix added by [escapeField] during import.
  static String unescapeField(String value) {
    if (value.startsWith('\t')) return value.substring(1);
    return value;
  }
}
