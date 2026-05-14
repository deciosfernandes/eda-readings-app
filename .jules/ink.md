# 🖋️ Ink Journal - EDA Readings

## ⚠️ Critical Learnings & "Gotchas"

### 🌐 Web Development & CORS Proxy
**Issue**: When running the application on the Web (`flutter run -d chrome`), requests to the EDA API (`smile.eda.pt`) fail due to Cross-Origin Resource Sharing (CORS) restrictions.
**Solution**: A dedicated proxy server is provided in `bin/proxy.dart`. Developers must run this proxy locally to bypass CORS during web development.
**Usage**:
```bash
dart bin/proxy.dart
```
The app is configured to use `http://localhost:8080/api/leitura` as the base URL when `kIsWeb` is true.

### 🏛️ Architecture Documentation
**Style Improvement**: Consolidating Persona-specific development patterns (BOLT, PALETTE, SENTINEL) into the central `ARCHITECTURE.md` file.
**Impact**: Significantly improves developer onboarding and code consistency by providing a single source of truth for both structural overview and actionable best practices. This bridges the gap between high-level architecture and day-to-day coding standards.

### 📖 Domain Model Documentation
**Style Improvement**: Explicitly documenting API-driven models that use domain-specific or foreign language field names (e.g., Portuguese fields from the EDA API).
**Impact**: Reduces "Time to First Hello World" by demystifying opaque terms like `CIL`, `Contrato`, and counter identifiers (`valorContador1`, `register1`). It ensures developers understand the data contract without needing to reverse-engineer the API or use external translation tools.

### 🏷️ Persona-Tagged Documentation
**Style Improvement**: Explicitly tagging DartDoc comments with development personas (**BOLT**, **PALETTE**, **SENTINEL**).
**Impact**: Reinforces the project's quality standards directly in the code. It helps developers understand the *intent* behind specific implementation choices (e.g., why a certain cache is used or why a field is validated) without leaving the IDE.

### 📖 Centralized Domain Glossary
**Style Improvement**: Adding a "Domain Glossary" to `ARCHITECTURE.md` to define foreign-language (Portuguese) business terms.
**Impact**: Bridges the language gap for non-Portuguese speakers and ensures consistent terminology across the codebase. It significantly reduces the cognitive load when working with API-driven models that reflect regional business logic.

### 📤 Data Portability Documentation
**Style Improvement**: Explicitly documenting the CSV schema in a tabular format within `ARCHITECTURE.md`.
**Impact**: Reduces confusion for developers implementing or debugging import/export logic. By explicitly stating the 5-column format, constraints, and the SENTINEL security requirements (e.g., single-quote prepending), we ensure that future changes maintain data integrity and user safety.

### 🗺️ Visualizing Navigation Flow
**Style Improvement**: Adding Mermaid-based diagrams for screen-to-screen navigation.
**Impact**: Bridges the "Visual Void" in architectural documentation. It allows developers to understand the relationship between core screens (e.g., how to reach Settings from the Dashboard via the ProfileDrawer) without tracing the `MaterialApp` routes.

### 🛠️ Onboarding Troubleshooting Guide
**Style Improvement**: Adding a proactive "Troubleshooting" section to the `README.md`.
**Impact**: Reduces "Time to First Hello World" by addressing the most common setup friction points (CORS proxy, Android permissions, and test race conditions) in a central location.

### 🛡️ Persistence & Security Documentation Alignment
**Gotcha**: Documentation rot often occurs during security-focused refactors (e.g., migrating from `SharedPreferences` to `FlutterSecureStorage`). Developers might rely on outdated "Data Flow" diagrams or service descriptions that no longer reflect the encrypted state of the data.
**Solution**: Always audit `ARCHITECTURE.md` when changing storage providers or hardening API interactions. Explicitly documenting the transition (like the one-time migration in `HistoryService`) prevents confusion and ensures security-conscious development.

### 🧬 Visualizing Data Pipelines
**Style Improvement**: Using Mermaid sequence diagrams to map complex data transformation pipelines (like CSV Import/Export).
**Impact**: Bridges the "Visual Void" for non-obvious logic flows that span multiple layers (UI -> Utility -> Service). By visualizing the interplay between **BOLT** and **SENTINEL** patterns in these pipelines, we reduce the cognitive load for developers tasked with maintaining data integrity and security in portability features.

---
*Last Updated: 2026-05-14*
