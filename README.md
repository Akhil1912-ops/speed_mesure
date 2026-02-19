# Campus Speed Tracker

A Flutter mobile app with automated route verification for campus vehicle speed monitoring.

---

## 📥 DOWNLOAD APP — For Testing

> **Install the Android app on your device to test Campus Speed Tracker.**

### [⬇️ Download APK (app-release.apk)](https://github.com/Akhil1912-ops/speed_mesure/releases/download/v1.0/app-release.apk)

| Step | Action |
|------|--------|
| 1 | Tap the link above to download the APK |
| 2 | **Settings** → **Security** → Enable **Install from unknown sources** |
| 3 | Open the downloaded file and tap **Install** |
| 4 | Grant **Location** permission when prompted |

---

## Features

- 📱 **Real-time GPS Speed Tracking** - Tracks vehicle speed with 30 km/h campus limit
- 🗺️ **Route Auto-Detection** - Automatically detects which route was taken
- ✅ **Automated Verification** - Verifies route compliance, distance, and speed violations
- 💰 **Penalty Calculation** - Auto-calculates fines based on violations
- 📊 **Security Dashboard** - Web dashboard for security to review trips
- 📱 **QR Code Generation** - Quick access to trip details via QR code

## Project Structure

```
speed_mesure/
└── speed_tracker/          # Main app
    ├── lib/               # Flutter source
    ├── functions/         # Firebase Cloud Functions
    ├── dashboard/         # Security dashboard (web)
    └── scripts/           # Route management
```

See [speed_tracker/README.md](speed_tracker/README.md) for setup and development instructions.
