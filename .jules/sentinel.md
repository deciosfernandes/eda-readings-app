## 2026-05-22 - Preventing Information Leakage and DoS via UI Hardening
**Vulnerability:** Raw exception strings were exposed to users in the reading screen, and text fields lacked length constraints.
**Learning:** Defaulting to `e.toString()` for error messages can leak internal stack traces or API details. Lack of `maxLength` on inputs allows for excessively large payloads that can crash the client or stress the backend.
**Prevention:** Always use generic, localized error messages for UI display and move detailed logs to `debugPrint`. Enforce `maxLength` on all user-facing inputs based on expected data formats.
