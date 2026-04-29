## 2026-02-09 - Trade-off between Brittle Performance and Robustness in JSON Filtering
**Learning:** Using `String.contains` to filter JSON strings before decoding can significantly reduce memory pressure and CPU cycles, but it is brittle. It assumes specific formatting (no spaces, specific quoting) and can cause false positives if the target string appears in unrelated fields.
**Action:** Prefer a middle-ground approach using lazy `Iterable.map(json.decode)` followed by `where` on the decoded Map. This avoids full object creation (the most expensive part in Dart) while maintaining robustness against JSON formatting variations.

## 2026-02-10 - Persistent HTTP Connections via Client Reuse
**Learning:** In Dart, creating a new `http.Client` for each request (or even for each instance of an API client class) prevents the underlying engine from reusing TCP connections. This adds significant latency due to repeated TCP and SSL handshakes.
**Action:** Implement a static shared `http.Client` instance within API client classes to enable connection pooling, while still allowing for instance-based injection for testing.

## 2026-02-11 - Performance Trade-offs: In-memory Cache Structure
**Learning:** Caching raw JSON maps instead of model objects reduces memory pressure and allows for lazy filtering (avoiding instantiation of filtered-out items), but increases CPU cost on repeated access as objects must be re-created. In Flutter, this is a beneficial trade-off when data is large and filtering is frequent, provided the re-instantiation happens outside of build() loops.
**Action:** Use Map-based caches for large datasets where filtering is common; prefer object-based caches for small, frequently accessed configuration state.
