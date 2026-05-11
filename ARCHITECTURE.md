# 🏗️ EDA Readings - Architecture

This document provides a high-level overview of the architecture, folder structure, and development patterns used in the EDA Readings application.

## 📁 Folder Structure

The project follows a standard Flutter directory structure with a clear separation of concerns:

- **`lib/api/`**: Contains the `EDAClient` for interacting with the EDA API.
- **`lib/models/`**: Defines data structures (e.g., `ReadingResponse`, `UserProfile`) and their serialization logic.
- **`lib/services/`**: Houses singleton services for shared logic:
  - `HistoryService`: Manages local reading history with in-memory caching.
  - `SecureStorageService`: Handles persistent storage of credentials and app state.
  - `NotificationService`: Manages local reminders with timezone-aware scheduling and platform-specific permission handling.
  - `ThemeService`: Handles theme persistence and state, ensuring UI consistency across app sessions.
- **`lib/screens/`**: UI components categorized by screen. Includes dialogs and drawer components.
- **`lib/theme/`**: Centralized theme definitions (`AppTheme`).
- **`assets/`**: Static resources like translations (JSON) and icons.
- **`bin/`**: Server-side or utility scripts (e.g., `proxy.dart` for Web development).
- **`test/`**: Comprehensive test suite for APIs, models, and services.

## 📖 Domain Glossary (EDA)

Understanding these terms is critical for working with the EDA API and the application's data models.

| Term | Full Name (Portuguese) | Description |
| :--- | :--- | :--- |
| **CIL** | Código de Identificação Local | Local Identification Code. A unique 10-digit number identifying a specific electricity delivery point. |
| **Contrato** | Número de Contrato | Electricity Contract Number. Associated with the CIL for authentication and billing. |
| **Ponta** | Horas de Ponta | Peak hours. High consumption period with higher costs. |
| **Cheias** | Horas de Cheias | Intermediate consumption period. |
| **Vazio** | Horas de Vazio | Off-peak hours. Lower consumption period (usually at night) with lower costs. |
| **Super Vazio** | Horas de Super Vazio | Deep off-peak. Even lower costs during specific night windows. |

### Meter Registers (Contadores)
The application handles up to three registers depending on the user's tariff:

1.  **`valorContador1` (Register 1)**: Primary reading. In a *Simples* tariff, this is the only counter. In *Bi-horária* or *Tri-horária*, it typically maps to the **Peak/Intermediate (Ponta/Cheias)** period.
2.  **`valorContador2` (Register 2)**: Used in *Bi-horária* and *Tri-horária* tariffs. Typically maps to the **Off-peak (Vazio)** period.
3.  **`valorContador3` (Register 3)**: Used exclusively in *Tri-horária* tariffs. Typically maps to the **Super Off-peak (Super Vazio)** period.

## 🔄 Data Flow

The following diagram illustrates how data flows from the API to the UI, highlighting the role of services and caching.

```mermaid
graph TD
    UI[DashboardScreen / ReadingScreen] -->|Requests Data| HS[HistoryService]
    UI -->|Saves Reading| API[EDA API / Proxy]
    API -->|Confirmation| UI
    UI -->|Updates History| HS
    HS -->|Caches in Memory| MEM[(In-Memory Cache)]
    HS -->|Persists| SP[SharedPreferences]

    UI -->|Loads Profile| SSS[SecureStorageService]
    SSS -->|Caches State| SSS_MEM[(In-Memory Cache)]
    SSS -->|Persists Credentials| FSS[Flutter Secure Storage]
```

## 🛠️ Core Services

### HistoryService
A singleton that manages the user's reading history. It implements a write-through cache:
1.  **Read**: Checks in-memory cache first, falls back to `SharedPreferences`.
2.  **Write**: Updates in-memory list, updates profile-indexed map, and then asynchronously persists to `SharedPreferences`.

### SecureStorageService
Manages sensitive user information (CIL/Contract) and the overall `AppStateData` (profiles, active profile). It uses `flutter_secure_storage` for encryption-at-rest.

### NotificationService
Provides local notification scheduling for reading reminders. It uses `timezone` for accurate delivery and handles platform-specific permission requests (e.g., Android 13+) to respect user privacy and system security requirements.

### ThemeService
A `ChangeNotifier` that manages the application's `ThemeMode`. It persists user preferences to `SharedPreferences` to ensure visual consistency across application restarts.

## 📤 Data Portability

The application allows users to import and export their reading history via CSV files. This logic is centralized in the `ImportExportScreen` and `SettingsScreen`, utilizing the `CsvHelper` utility.

### Security (SENTINEL)
- **Formula Injection Protection**: All exported fields starting with trigger characters (`=`, `+`, `-`, `@`) are prepended with a single quote (`'`) to prevent execution in spreadsheet software.
- **Input Validation**: During import, the application enforces length limits (e.g., 50 for names, 15 for readings) and validates numeric formats before insertion into local storage.

### Performance (BOLT)
- **Lookup Optimization**: During import, a lookup map of property names to IDs is pre-calculated to achieve O(1) matching, replacing O(N) list scans.
- **Batch Processing**: Multiple readings are added to the `HistoryService` in a single atomic update to minimize secure storage I/O overhead.

## 🎭 Persona Patterns

Development is guided by three core "Personas," each focusing on a specific dimension of software quality. You will find comments tagged with these personas throughout the codebase.

### ⚡ BOLT (Performance)
The **Bolt** pattern focuses on making the app fast and responsive.
- **Caching**: Aggressive in-memory caching in services (`HistoryService`, `SecureStorageService`) to avoid redundant I/O.
- **Parallelization**: Concurrently initializing independent services during startup (`main.dart`).
- **Pre-calculation**: Transforming data for charts and lists before the `build` method is called to keep the UI thread free (`DashboardScreen`).

### 🎨 PALETTE (UX & Accessibility)
The **Palette** pattern ensures the app is beautiful, accessible, and delightful to use.
- **Haptics**: Consistent use of `HapticFeedback` for tactile confirmation of user actions.
- **Semantics**: Enhanced `Semantics` labels for screen readers.
- **Visual Cues**: Clear destructive action confirmation and themed loading states.

### 🖋️ INK (Documentation)
The **Ink** pattern prioritizes codebase readability and developer experience.
- **Clear Intent**: Documentation that explains the "Why" behind complex logic.
- **Self-Documenting Code**: Professional tone and clear naming conventions.
- **Architecture Mapping**: Maintaining documents like this one to reduce onboarding friction.

### 🛡️ SENTINEL (Security)
The **Sentinel** pattern focuses on application security, data protection, and robust input validation.
- **Input Validation**: Strict enforcement of length limits and numeric format validation on all user-facing inputs.
- **Secure Storage**: Using `flutter_secure_storage` for credentials and ensuring sensitive data is never exposed in logs or UI.
- **PR Standards**: Security-focused PRs must follow the format `🛡️ Sentinel: [CRITICAL/HIGH/MEDIUM] Fix [vulnerability type]` and include detailed sections for Severity, Vulnerability, Impact, Fix, and Verification.

## 🚀 Development Best Practices

### ⚡ Performance (BOLT)
- **Aggressive Caching**: Always check in-memory caches before performing disk I/O or platform channel calls.
- **Loop Optimization**: Hoist expensive object instantiations (like `DateFormat`) out of loops.
- **UI Responsiveness**: Pre-calculate derived data (like chart spots or formatted strings) during data loading rather than in the `build()` method.

### 🎨 UX & Accessibility (PALETTE)
- **Tactile Feedback**: Use `HapticFeedback.selectionClick()` or `lightImpact()` for interactive elements.
- **Rich Semantics**: Provide descriptive `Semantics` labels that concatenate multiple fields to provide full context for screen readers.
- **Consistent States**: Use themed empty states with icons and clear Calls to Action (CTAs).

### 🛡️ Security (SENTINEL)
- **Safe Parsing**: When parsing numeric input, always use `double.tryParse` and verify `number.isFinite` and `number >= 0`.
- **Length Limits**: Enforce `maxLength` on all `TextField` and `TextFormField` components (e.g., 50 for names, 15 for readings).
- **Error Privacy**: Never expose raw exception messages in the UI; use localized, generic error messages.

## 🌐 Development Environment

### Web Development (CORS Proxy)
Due to browser security restrictions, direct requests to the EDA API will fail with CORS errors when running on the Web. A local proxy is provided to bypass this:

1.  **Start the proxy**:
    ```bash
    dart bin/proxy.dart
    ```
2.  **Run the app**:
    ```bash
    flutter run -d chrome
    ```

The `EDAClient` is pre-configured to detect the web environment and route requests through `http://localhost:8080`.

---
*Last Updated: 2026-05-11*
