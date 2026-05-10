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

---
*Last Updated: 2025-05-15*
