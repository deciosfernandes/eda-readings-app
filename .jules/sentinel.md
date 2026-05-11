## 2026-05-22 - Preventing Information Leakage and DoS via UI Hardening
**Vulnerability:** Raw exception strings were exposed to users in the reading screen, and text fields lacked length constraints.
**Learning:** Defaulting to `e.toString()` for error messages can leak internal stack traces or API details. Lack of `maxLength` on inputs allows for excessively large payloads that can crash the client or stress the backend.
**Prevention:** Always use generic, localized error messages for UI display and move detailed logs to `debugPrint`. Enforce `maxLength` on all user-facing inputs based on expected data formats.

## 2026-05-25 - Hardening Numeric Parsers and CSV Import Logic
**Vulnerability:** Numeric inputs and CSV imports could be bypassed using special literals like "NaN" or "Infinity", and CSV imports lacked length constraints.
**Learning:** In Dart, `double.tryParse` accepts special literals ("NaN", "Infinity") which can bypass standard range checks (e.g., `val < min`). External data sources like CSV must be treated as untrusted and subjected to the same validation as manual UI inputs.
**Prevention:** When parsing numeric user input, always verify `number.isFinite` and enforce strict length limits on all fields imported from external files to prevent malformed data injection.

## 2026-05-28 - Hardening Network Requests with Timeouts and Safe URI Construction
**Vulnerability:** API requests lacked timeouts, potentially leading to resource exhaustion, and URI construction used manual string interpolation.
**Learning:** Default network clients may wait indefinitely for a response, which can be exploited to hang the application. Manual URI construction is error-prone and can lead to injection if not properly encoded.
**Prevention:** Always apply a reasonable timeout (e.g., 15s) to all network requests and use built-in URI builders like `Uri.replace(queryParameters: ...)` to ensure safe encoding of parameters.

## 2026-06-01 - Hardening CSV Security and Centralizing Processing Logic
**Vulnerability:** CSV processing was decentralized, leading to inconsistent escaping and missing protection against whitespace-triggered formula injection.
**Learning:** Formula injection can be triggered by characters like tabs or newlines if they are at the start of a field. Decentralized parsing logic (duplicated `_parseCsvLine` in multiple screens) increases the risk of security regressions when updates are needed.
**Prevention:** Centralize all CSV formatting and parsing in a single utility (`CsvHelper`). Use the single quote (`'`) as a robust escape character for all spreadsheet-sensitive prefixes (`=`, `+`, `-`, `@`, `\t`, `\r`, `\n`, `'`) and ensure unescaping logic supports both new and legacy (tab) prefixes.

## 2026-06-03 - Hardening Proxy URI Construction and CSV Numeric Validation
**Vulnerability:** The development proxy used manual string interpolation for URI forwarding, and CSV imports lacked non-negative validation for numeric readings.
**Learning:** Manual URI construction using string interpolation or `Uri.parse` with concatenated strings is fragile and can lead to injection if request components aren't properly encoded. Similarly, CSV validation must match UI validation (e.g., non-negative checks) to ensure data consistency and prevent logic bypasses.
**Prevention:** Always use structured URI constructors like `Uri.https` with `queryParametersAll` to ensure robust encoding of all URI components. Synchronize validation logic between manual inputs and automated imports (e.g., CSV) to enforce uniform security and data integrity constraints.
