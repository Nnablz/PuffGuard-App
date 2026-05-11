# PuffGuard IoT Control Dashboard

A single‑page Flutter application that connects via WebSocket to an ESP32 microcontroller to display real‑time humidity and smoke sensor data and manually control an exhaust fan.

## Features
- Real‑time sensor data (humidity, smoke level, fan status) over a local Wi‑Fi WebSocket (`ws://192.168.4.1:81`).
- Playful minimalist UI with off‑white background, rounded corners, and vibrant colors.
- Automatic high‑smoke detection ( > 1000 ) triggers a local Android/iOS notification.
- Manual fan override button that updates based on the current fan status.
- State management powered by `provider`.
- Uses `flutter_local_notifications` for on‑device alerts.

## Getting Started
1. Ensure your development machine has Flutter 3.41 or newer and the Android/iOS toolchains installed.
2. Clone the repository and open the project in your IDE.
3. Run `flutter pub get` to fetch dependencies.
4. Connect your device/emulator to the same Wi‑Fi network as the ESP32.
5. Launch the app with `flutter run`.

## Configuration
- To change the ESP32 address, edit the `_wsUrl` constant in `lib/main.dart`.
- Adjust the smoke‑danger threshold by modifying `IotProvider.dangerThreshold`.

---
© 2026 Nabil PC. All rights reserved. This repository is private and **not** open‑source. Unauthorized distribution or use is prohibited.
