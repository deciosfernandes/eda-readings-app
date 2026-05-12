## 2026-05-18 - [Optimizing keyboard navigation in modal forms]
**Learning:** In Flutter modal bottom sheets with multiple input fields, providing a logical keyboard flow (autofocus, next/done actions) and allowing submission directly from the keyboard significantly reduces friction for mobile and power users.
**Action:** Always consider `autofocus`, `textInputAction`, and `onSubmitted` when implementing multi-field forms in dialogs.

## 2026-05-18 - [Accessibility and Interaction Polish]
**Learning:** Adding `Semantics` to list items and `HapticFeedback` for selection/success events makes the app feel more robust and professional. Ensuring high contrast on interactive elements like `TabBar` labels is critical for visibility.
**Action:** Use localized `Semantics` descriptions for data-rich list items and provide tactile feedback for key user interactions.

## 2026-05-01 - [Destructive Action Visuals and Semantic List State]
**Learning:** For destructive actions in mobile apps, combining visual cues (error color) with tactile feedback (medium impact haptics) creates a safer and more intentional user experience. When using Semantics for list items, including the selection state in the label (e.g., "Property Name (OK)") ensures screen readers convey the full context of which item is currently active.
**Action:** Always pair destructive UI elements with appropriate color tokens and physical feedback, and ensure list item Semantics reflect active/inactive state.

## 2026-05-20 - [Visual Affordance for Editable Profile Media]
**Learning:** Interactive elements that look like static media (e.g., a profile picture) require explicit visual cues like badges or icons to signal editability. Combining this visual affordance with immediate tactile feedback on interaction creates a more discoverable and satisfying user experience.
**Action:** Wrap 'CircleAvatar' or similar media in a 'Stack' with a 'Positioned' icon badge (e.g., camera icon) and provide haptic feedback on tap.

## 2026-05-03 - [Reactive "Clear" Buttons in Forms]
**Learning:** Conditional decorations like a "Clear" suffix icon in a 'TextFormField' do not automatically update as the user types unless the widget is rebuilt. Adding an 'onChanged' callback that triggers 'setState' is necessary to provide immediate visual feedback on the button's visibility.
**Action:** Always pair conditional 'InputDecoration' elements with an 'onChanged' trigger to ensure the UI remains in sync with the field's state.

## 2026-05-22 - [Semantic Headers for Navigation]
**Learning:** Section headers in complex screens or dialogs are critical for screen reader users to navigate the content efficiently. Wrapping text-based headers in `Semantics(header: true)` allows assistive technologies to jump directly to logical sections.
**Action:** Always identify logical section starts and wrap their titles in `Semantics(header: true)`.

## 2026-05-24 - [Enhancing selection clarity with icons]
**Learning:** Adding visual icons to choice-heavy widgets like 'DropdownButton' (e.g., for theme selection) significantly improves the speed at which users can identify and select their preferred option compared to text-only labels.
**Action:** Always consider pairing text labels with semantic icons in selection components to provide immediate visual context.

## 2026-05-26 - [Unambiguous selection feedback in horizontal lists]
**Learning:** For item selectors in horizontal lists (e.g., icon pickers), a simple background color change can be subtle and easily missed, especially in high-brightness environments. Combining an 'AnimatedContainer' for smooth transitions with a 'Stack'-based checkmark overlay ('Icons.check_circle') provides clear, unambiguous, and delightful visual confirmation of the selected state.
**Action:** Use 'AnimatedContainer' and a checkmark status indicator for all selection components where clarity is paramount.
