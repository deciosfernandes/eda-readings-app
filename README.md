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

## 🌍 Localization

Translations are managed via JSON files in `assets/translations/`.
- `en.json`: English
- `pt.json`: Portuguese

To update translations, simply edit these files and the app will reflect changes on next load.

## 🤝 Contribution

This project is open-source. For feature requests or bug reports, please open an issue in the repository.

---

*Made for the Azores with ⚡ by Decio Fernandes.*
