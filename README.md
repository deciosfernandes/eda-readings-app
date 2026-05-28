# EDA Readings

A modern, cross-platform Flutter application designed for customers of **Electricidade dos Açores (EDA)**. This app helps users track, manage, and analyze their electricity consumption by recording and visualizing meter readings.

## 🌟 Features

- **🏠 Property Management**: Add and manage multiple properties. Each property can have a custom icon and unique details.
- **📊 Data Visualization**: Integrated charts (powered by `fl_chart`) to analyze consumption trends over time.
- **🔔 Reading Reminders**: Set up local notifications to ensure you never miss a reading submission window.
- **🌍 Multi-language Support**: Full support for English and Portuguese (auto-detected or user-selected).
- **🔒 Secure Storage**: Credentials and sensitive data are stored using `flutter_secure_storage`.
- **🌓 Adaptive Theme**: Automatically switches between Light and Dark modes based on system preferences.
- **🖥️ Cross-Platform**: Optimized for Android, iOS, Windows, macOS, and Web.
- **♿ Accessibility**: Enhanced with tooltips, semantic labels, and pointer cursors for a seamless experience on all devices.

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (Dart)
- **State Management**: Provider-based patterns
- **Localization**: [easy_localization](https://pub.dev/packages/easy_localization)
- **Charts**: [fl_chart](https://pub.dev/packages/fl_chart)
- **Storage**: `flutter_secure_storage` & `shared_preferences`
- **Notifications**: `flutter_local_notifications`

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable version)
- Dart SDK
- IDE: VS Code, Android Studio, or IntelliJ

### Installation

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/deciosfernandes/eda-readings-app.git
    cd eda-readings-app
    ```

2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Run the application**:
    ```bash
    # Run on mobile emulator or connected device
    flutter run

    # Run on specific platform (e.g., Windows)
    flutter run -d windows
    ```

### 🌐 Developing for Web

When developing for the Web, you must run a local CORS proxy to interact with the EDA API:

```bash
# In a separate terminal
dart bin/proxy.dart

# Run the app in Chrome
flutter run -d chrome
```

## 🛠️ Troubleshooting

### 🌐 Web: "Failed to fetch" or CORS Errors
If you see network errors when running in Chrome, ensure the CORS proxy is running:
1. Stop the Flutter process.
2. Run `dart bin/proxy.dart` in a terminal.
3. Restart the app with `flutter run -d chrome`.

### 📱 Android: Notifications Not Appearing
Starting with Android 13 (API 33), users must explicitly grant notification permissions.
- The app requests this on the first run via `NotificationService`.
- If denied, you can manually enable it in **Settings > Apps > EDA Readings > Notifications**.
- For development, ensure the emulator has Google Play Services if testing advanced notification features.

### 🧪 Tests: "easy_localization" Race Conditions
If `flutter test` fails randomly during widget tests, it may be due to localization loading timing.
- **Solution**: Run specific tests using `flutter test --plain-name "[Test Name]"` to isolate the issue.

## 🏗️ Core Architecture

This project follows a service-oriented architecture with aggressive in-memory caching for performance.

For a detailed breakdown of the folder structure, data flow, and development patterns, see **[ARCHITECTURE.md](ARCHITECTURE.md)**.

## 🌍 Localization

Translations are managed via JSON files in `assets/translations/`.
- `en.json`: English
- `pt.json`: Portuguese

To update translations, simply edit these files and the app will reflect changes on next load.

## 🤝 Contributing

This project is open-source and follows a unique **Persona-based Development Workflow**.

We welcome contributions! Please see our **[CONTRIBUTING.md](CONTRIBUTING.md)** for details on our development personas (BOLT, PALETTE, INK, SENTINEL), PR standards, and journaling requirements.

## 🔒 Privacy Policy

The Privacy Policy for this app (available in English and Portuguese) is hosted here:

**[https://deciosfernandes.github.io/eda-readings-app/privacy-policy.html](https://deciosfernandes.github.io/eda-readings-app/privacy-policy.html)**

The source file is located at [`docs/privacy-policy.html`](docs/privacy-policy.html).

---

*Last Updated: 2026-05-15*

*Made for the Azores with ⚡ by Decio Fernandes.*
