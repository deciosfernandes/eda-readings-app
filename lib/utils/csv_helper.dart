/// Utility class for handling CSV data transformation and security.
///
/// **INK**: This helper centralizes the logic for escaping and unescaping CSV fields,
/// ensuring a consistent format across the application's import and export features.
///
/// **Data Format Specification:**
/// The application uses a standard 5-column CSV format for reading history:
/// 1. `Property`: The name of the [ContractProfile].
/// 2. `Date`: The timestamp of the reading (`yyyy-MM-dd HH:mm:ss`).
/// 3. `Counter 1`: Primary reading value in kWh.
/// 4. `Counter 2`: (Optional) Off-peak reading value.
/// 5. `Counter 3`: (Optional) Super Off-peak reading value.
///
/// **SENTINEL**: To protect users from malicious data, this class implements
/// CSV Formula Injection protection. Any field starting with a trigger character
/// is prepended with a single quote (') to ensure it is treated as literal text
/// by spreadsheet applications like Excel or Google Sheets.
class CsvHelper {
  /// SENTINEL: Characters that trigger CSV Formula Injection in spreadsheet software.
  /// Prepending a single quote (') to fields starting with these characters prevents
  /// them from being executed as formulas when the CSV is opened.
  static const _triggerChars = {'=', '+', '-', '@', '\t', '\r', '\n', '\''};

  /// SENTINEL: Protects against CSV formula injection by prepending a single quote.
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
