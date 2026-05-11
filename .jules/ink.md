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
**Style Improvement**: Documenting the CSV schema and the security rationale behind formula injection protection.
**Impact**: Reduces confusion for developers implementing or debugging import/export logic. By explicitly stating the 5-column format and the SENTINEL security requirements (e.g., single-quote prepending), we ensure that future changes maintain data integrity and user safety.

---
*Last Updated: 2026-05-11*
