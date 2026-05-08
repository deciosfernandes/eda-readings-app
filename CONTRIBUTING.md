# 🤝 Contributing to EDA Readings

Thank you for your interest in contributing! This project uses a unique, persona-based development workflow to ensure high standards for performance, user experience, documentation, and security.

## 🎭 Development Personas

All contributions must align with one of our four core development personas. When you open a Pull Request, you should identify which persona it primarily represents.

### ⚡ BOLT (Performance)
The **Bolt** persona focuses on making the app fast, responsive, and efficient.
- **Focus**: Caching, loop optimization, parallelization, reducing I/O, and minimizing UI thread work.
- **PR Title**: `⚡ Bolt: [performance improvement]`
- **PR Description Requirements**:
    - **💡 What**: Description of the change.
    - **🎯 Why**: The performance bottleneck being addressed.
    - **📊 Impact**: Expected metrics or performance gains.
    - **🔬 Measurement**: How the improvement was verified.
- **Journaling**: Add significant learnings to `.jules/bolt.md`.

### 🎨 PALETTE (UX & Accessibility)
The **Palette** persona ensures the app is beautiful, accessible, and delightful.
- **Focus**: Haptics, semantics, visual consistency, loading states, and inclusive design.
- **PR Title**: `🎨 Palette: [UX improvement]`
- **PR Description Requirements**:
    - **💡 What**: Description of the change.
    - **🎯 Why**: The specific UX or accessibility gap being addressed.
    - **📸 Before/After**: Screenshots or descriptions of the visual change.
    - **♿ Accessibility**: Details on how this improves accessibility (e.g., Semantics, contrast).
- **Journaling**: Add significant learnings to `.jules/palette.md`.

### 🖋️ INK (Documentation)
The **Ink** persona prioritizes codebase readability and developer experience.
- **Focus**: README clarity, architecture mapping, code comments, and reduction of onboarding friction.
- **PR Title**: `🖋️ Ink: [documentation improvement]`
- **PR Description Requirements**:
    - **💡 What**: The documentation added or updated.
    - **🎯 Why**: The specific confusion or gap being addressed.
- **Journaling**: Add "Gotchas" or recurring points of confusion to `.jules/ink.md`.

### 🛡️ SENTINEL (Security)
The **Sentinel** persona focuses on application security, data protection, and robust validation.
- **Focus**: Input validation, secure storage, data privacy, and mitigation of injection risks.
- **PR Title**: `🛡️ Sentinel: [CRITICAL/HIGH/MEDIUM] Fix [vulnerability type]` or `🛡️ Sentinel: [security improvement]`
- **PR Description Requirements**:
    - **Severity**: (If applicable)
    - **Vulnerability**: Description of the risk.
    - **Impact**: Potential consequences.
    - **Fix**: How the vulnerability was mitigated.
    - **Verification**: How the fix was tested.
- **Journaling**: Record critical security patterns or architectural gaps in `.jules/sentinel.md`.

## 📏 General Guidelines

- **Keep PRs Small**: We aim for PRs under **50 lines of code** whenever possible to facilitate thorough review.
- **Verify Your Work**: Run `flutter analyze` and `flutter test` before submitting.
- **Web Development**: If you are working on the Web version, remember to run the CORS proxy: `dart bin/proxy.dart`.
- **Pre-calculation**: Avoid expensive operations (formatting, decoding) inside `build()` methods or loops. Pre-calculate data during the state loading phase.
- **Secure Storage**: Always use `SecureStorageService` for credentials and sensitive configuration.

## 📝 The Journaling System (`.jules/`)

Each persona has a corresponding journal file in the `.jules/` directory. We use these to record **Critical Learnings**, **"Gotchas"**, and **Actionable Patterns**.
- Only add entries for recurring issues, non-obvious solutions, or significant architectural decisions.
- Do not document trivial changes.

---
*Last Updated: 2025-05-14*
