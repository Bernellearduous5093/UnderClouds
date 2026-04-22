# ☁️ UnderClouds

**Point your phone at the sky — instantly identify clouds, estimate your distance to them, and discover what lies directly beneath.**

![Flutter](https://img.shields.io/badge/Flutter-3.41.7-02569B?logo=flutter&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)
![License](https://img.shields.io/badge/License-All%20Rights%20Reserved-red)

---

## 📸 Demo

![App GIF](<./UnderCloudsTest.gif>)

---

## ✨ Features

- **🤖 On-device Cloud Classification** — Identifies 11 WMO-standard cloud types (Cirrus, Cumulus, Cumulonimbus, Stratus, and more) using a TFLite model running entirely on-device — no internet required for inference.

- **📐 Distance Estimation** — Combines the phone's elevation angle (accelerometer) with each cloud type's known altitude to calculate horizontal and slant distance via trigonometry.

- **🌍 Ground Location Projection** — Uses GPS position, compass bearing, and estimated horizontal distance to project the GPS coordinate of the point directly beneath the cloud using the Haversine formula.

- **🗺️ Reverse Geocoding** — Queries OpenStreetMap's Nominatim API to convert the projected coordinate into a human-readable address, with graceful offline fallback.

- **🏛️ Nearby Landmark Discovery** — Uses the Overpass API to find named points of interest within 500 m of the cloud's ground position, ranked by distance.

- **📖 Wikipedia Integration** — Automatically enriches detected landmarks with a photo thumbnail, a brief description, and a direct Wikipedia link, fetched via the Wikipedia Geosearch and Summary REST APIs.

- **🧭 Live Sensor HUD** — A glassmorphic floating pill overlay shows real-time elevation angle and compass azimuth while framing the shot.

- **⚡ Confidence-Aware Results** — Three-tier confidence system (high / low / too uncertain) with colour-coded indicators; distance and location cards are hidden when the model cannot make a reliable prediction.

---

## 🛠️ Tech Stack

| Layer | Technology |
| --- | --- |
| UI framework | Flutter 3.41.7 / Dart 3.11.5 |
| ML inference | `tflite_flutter ^0.12` · CCSN dataset model |
| Image preprocessing | `image ^4.8` · center-crop · /255 normalisation · `compute()` isolate |
| Camera | `camera ^0.12` |
| Location | `geolocator ^14` |
| Elevation angle | `sensors_plus ^7` (accelerometer) |
| Compass bearing | `flutter_compass ^0.8` |
| Geocoding | Nominatim (OSM) · Overpass API · Wikipedia REST API |
| Networking | `http ^1.6` |
| Fonts | Google Fonts — Nunito · Space Mono · DM Serif Display |
| Ads | `google_mobile_ads ^5.2` |

---

## 🚀 Quick Start

### Prerequisites

| Requirement | Version |
| --- | --- |
| Flutter SDK | ≥ 3.41.7 (stable) |
| Dart SDK | ≥ 3.11.5 |
| Android min SDK | **26** (Android 8.0) |
| Android target SDK | 35 |

### 1 — Clone the repository

```bash
git clone https://github.com/[in-fill-your-username]/UnderClouds.git
cd UnderClouds
```

### 2 — Add the TFLite model

Download the CCSN cloud classifier model and place it at:

```text
assets/models/cloud_classifier.tflite
assets/models/cloud_labels.txt   # one label per line, 11 lines
```

> The label order must match the model's output layer exactly.  
> Reference training script: `https://github.com/Slayingripper/Cloud-Classification`

### 3 — Install dependencies

```bash
flutter pub get
```

### 4 — Run on a connected Android device

```bash
# List available devices
flutter devices

# Run on a specific device (requires Camera + Location permissions)
flutter run -d <device-id>
```

### 5 — Build a release APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

> **Note:** Replace the test AdMob IDs in `AndroidManifest.xml` and `result_screen.dart` with your real AdMob IDs before publishing.

---

## ⚠️ Disclaimer

> **This project is intended solely for personal learning and as a technical portfolio showcase. If you are interested in collaboration or have any inquiries, feel free to reach out.**

---

## 📄 License

© [Sammnie] · All rights reserved.  
Unauthorised copying, modification, or distribution of this software is strictly prohibited.
