# Campus Speed Tracker

A Flutter mobile app with automated route verification for campus vehicle speed monitoring.

## Features

- 📱 **Real-time GPS Speed Tracking** - Tracks vehicle speed with 30 km/h campus limit
- 🗺️ **Route Auto-Detection** - Automatically detects which route was taken
- ✅ **Automated Verification** - Verifies route compliance, distance, and speed violations
- 💰 **Penalty Calculation** - Auto-calculates fines based on violations
- 📊 **Security Dashboard** - Web dashboard for security to review trips
- 📱 **QR Code Generation** - Quick access to trip details via QR code

## Project Structure

```
speed_tracker/
├── lib/                    # Flutter app source code
│   ├── main.dart          # Main app entry
│   ├── database_helper.dart
│   ├── firebase_service.dart
│   ├── trip_summary_screen.dart
│   ├── upload_screen.dart
│   └── qr_display_screen.dart
├── functions/             # Firebase Cloud Functions
│   ├── index.js           # Automated trip verification
│   └── package.json
├── dashboard/             # Security dashboard (web)
│   └── index.html
└── scripts/               # Utility scripts
    ├── add_routes_to_firebase.py
    └── all_routes.json    # Route backup
```

## Quick Start

### 1. Flutter App
```bash
flutter pub get
flutter run
```

### 2. Deploy Cloud Functions
```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

### 3. Deploy Dashboard
```bash
cd dashboard
firebase deploy --only hosting
```

## How It Works

1. **User records trip** → App tracks GPS and speed
2. **Trip uploaded** → Data saved to Firebase
3. **Auto-verification** → Cloud Function detects route and verifies compliance
4. **QR code generated** → Security scans to view results
5. **Dashboard shows** → Route detected, violations, penalty, verdict

## Route Management

Routes are stored in Firebase `approved_routes` collection. To add/modify routes:

1. Update `scripts/all_routes.json`
2. Run `python scripts/add_routes_to_firebase.py`

## Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase (Firestore, Storage, Functions, Hosting)
- **Verification**: Buffer-based corridor route matching
- **Maps**: OpenStreetMap (flutter_map)

## License

Private project for campus use.
