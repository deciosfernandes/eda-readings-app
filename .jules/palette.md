## 2026-05-18 - [Optimizing keyboard navigation in modal forms]
**Learning:** In Flutter modal bottom sheets with multiple input fields, providing a logical keyboard flow (autofocus, next/done actions) and allowing submission directly from the keyboard significantly reduces friction for mobile and power users.
**Action:** Always consider `autofocus`, `textInputAction`, and `onSubmitted` when implementing multi-field forms in dialogs.

## 2026-05-18 - [Accessibility and Interaction Polish]
**Learning:** Adding `Semantics` to list items and `HapticFeedback` for selection/success events makes the app feel more robust and professional. Ensuring high contrast on interactive elements like `TabBar` labels is critical for visibility.
**Action:** Use localized `Semantics` descriptions for data-rich list items and provide tactile feedback for key user interactions.
