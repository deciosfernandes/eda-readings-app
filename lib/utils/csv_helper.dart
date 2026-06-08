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
/// is prefixed with a marker that [unescapeField] strips on import.
///
/// **SENTINEL**: Embedded newlines (\n, \r) are normalised to a space before
/// writing so that the per-line import reader can never split a quoted field
/// across multiple input lines.
class CsvHelper {
  /// SENTINEL: Characters that trigger CSV Formula Injection in spreadsheet software.
  /// Prepending a single quote (') to fields starting with these characters prevents
  /// them from being executed as formulas when the CSV is opened.
  static const _triggerChars = {'=', '+', '-', '@', '\t', '\r', '\n', '\''};

  /// SENTINEL: Protects against CSV formula injection by prepending a single quote.
  ///
  /// Also normalises embedded CR/LF to a space so that the line-based import
  /// reader never accidentally splits a quoted field across rows.
  static String escapeField(String value) {
    if (value.isEmpty) return '';

    // SENTINEL: Normalise embedded newlines BEFORE the injection check so that
    // a value like "hello\nworld" cannot break the line-splitter during import.
    // Values that legitimately require multiline representation are extremely
    // unlikely in this domain (kWh readings, dates, profile names).
    value = value.replaceAll('\r\n', ' ').replaceAll('\r', ' ').replaceAll('\n', ' ');

    // SENTINEL: Detect trigger characters even if preceded by whitespace to prevent bypasses.
    // We check both the original first character and the first non-whitespace character.
    final trimmed = value.trimLeft();
    if (_triggerChars.contains(value[0]) ||
        (trimmed.isNotEmpty && _triggerChars.contains(trimmed[0]))) {
      value = "'$value";
    }

    return value.replaceAll('"', '""');
  }

  /// Strip the injection-protection prefix added by [escapeField] during import.
  ///
  /// A leading single quote is the injection-protection marker added by this
  /// class. A leading tab is the legacy marker from older app versions.
  ///
  /// Note: a legitimate field that starts with a single quote will have been
  /// double-prefixed by [escapeField] (because `'` is a trigger char), so one
  /// prefix is stripped here and the original leading quote is preserved.
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
  ///
  /// Follows RFC-4180: fields may be enclosed in double-quotes; a double-quote
  /// inside a quoted field is represented as two consecutive double-quotes.
  static List<String> parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          // Escaped double-quote inside a quoted field.
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
