## 2026-02-09 - Trade-off between Brittle Performance and Robustness in JSON Filtering
**Learning:** Using `String.contains` to filter JSON strings before decoding can significantly reduce memory pressure and CPU cycles, but it is brittle. It assumes specific formatting (no spaces, specific quoting) and can cause false positives if the target string appears in unrelated fields.
**Action:** Prefer a middle-ground approach using lazy `Iterable.map(json.decode)` followed by `where` on the decoded Map. This avoids full object creation (the most expensive part in Dart) while maintaining robustness against JSON formatting variations.

## 2026-02-10 - Persistent HTTP Connections via Client Reuse
**Learning:** In Dart, creating a new `http.Client` for each request (or even for each instance of an API client class) prevents the underlying engine from reusing TCP connections. This adds significant latency due to repeated TCP and SSL handshakes.
**Action:** Implement a static shared `http.Client` instance within API client classes to enable connection pooling, while still allowing for instance-based injection for testing.

## 2026-02-11 - Performance Trade-offs: In-memory Cache Structure
**Learning:** Caching raw JSON maps instead of model objects reduces memory pressure and allows for lazy filtering (avoiding instantiation of filtered-out items), but increases CPU cost on repeated access as objects must be re-created. In Flutter, this is a beneficial trade-off when data is large and filtering is frequent, provided the re-instantiation happens outside of build() loops.
**Action:** Use Map-based caches for large datasets where filtering is common; prefer object-based caches for small, frequently accessed configuration state.

## 2026-02-12 - UI Thread Optimization: Pre-calculation and Tab State Persistence
**Learning:** Performing string formatting (e.g., `DateFormat.format`) and complex string interpolations inside `ListView.builder` or chart title generators leads to redundant work on every frame during scrolling or animations. Additionally, `TabBarView` disposes of tabs by default, causing expensive rebuilds and loss of UI state (scroll position).
**Action:** Pre-calculate all display strings (dates, labels) into state-managed lists during data fetching and use `AutomaticKeepAliveClientMixin` to persist tab state, ensuring the UI thread remains responsive during interactions.

## 2026-02-13 - O(1) Profile-Based Indexing for History
**Learning:** For features that frequently filter a large flat list by a key (e.g., Dashboard filtering history by `profileId`), a simple list scan becomes O(N). Implementing a Map-based index (`Map<String, List>`) during the initial load achieves O(1) lookups for the common case.
**Action:** Maintain a profile-indexed cache in `HistoryService`. When performing batch updates, group items by profile before prepending to the index to maintain chronological order without O(N) re-sorts.

## 2026-02-14 - Pre-instantiation of Model Objects in Cache
**Learning:** Caching raw JSON maps still incurs O(N) overhead for object instantiation on every read. Pre-instantiating model objects in the cache during the initial load (or upon write) moves this cost to the background/initialization phase, making UI builds O(1) relative to object creation.
**Action:** In singleton services, prefer caching fully instantiated model objects. When returning lists from the cache, use `List.from()` to prevent external mutation of the internal cache list while keeping the O(1) benefit for the objects themselves.

## 2026-02-15 - Static Uri Pre-parsing and Theme Hoisting
**Learning:** Redundant `Uri.parse` calls in API clients and `Theme.of(context)` lookups in `ListView.builder` can cause measurable overhead on low-end devices and impact scroll smoothness. `Uri.parse` involves string parsing logic that is unnecessary for static base URLs.
**Action:** Pre-parse static base URLs into `static final Uri` objects. Hoist `Theme.of(context)` and `ColorScheme` lookups to the top of build methods or pass them as parameters to sub-widgets to avoid repeated InheritedWidget traversals in high-frequency paths.
