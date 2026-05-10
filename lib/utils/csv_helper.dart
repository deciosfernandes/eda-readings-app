class CsvHelper {
  /// SENTINEL: Trigger characters that can be used for CSV formula injection.
  static const _triggerChars = {'=', '+', '-', '@', '\t', '\r', '\n', '\''};

  /// SENTINEL: Protect against CSV formula injection by prepending a single quote.
  /// Trigger characters include =, +, -, @, \t, \r, \n, and '.
  static String escapeField(String value) {
    if (value.isEmpty) return '';

    if (_triggerChars.contains(value[0])) {
      value = "'$value";
    }

    return value.replaceAll('"', '""');
  }

  /// Strip the escape prefix added by [escapeField] during import.
  /// Handles both the new single quote prefix and legacy tab prefix.
  static String unescapeField(String value) {
    if (value.isEmpty) return value;
    if (value.startsWith("'") || value.startsWith('\t')) {
      return value.substring(1);
    }
    return value;
  }

  /// Formats a list of fields into a valid CSV row, applying escaping and quoting.
  static String toCsvRow(List<String> fields) {
    return fields.map((f) => '"${escapeField(f)}"').join(',');
  }

  /// Parses a single CSV line into a list of fields, handling quotes and escaped quotes.
  static List<String> parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString());
    return result;
  }
}
