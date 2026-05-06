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

---
*Last Updated: 2025-05-14*
