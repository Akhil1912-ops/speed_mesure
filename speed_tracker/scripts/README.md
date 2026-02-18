# Route Management Scripts

## Adding Routes to Firebase

### Prerequisites
1. Get Firebase service account key:
   - Firebase Console → Project Settings → Service Accounts
   - Generate New Private Key
   - Save as `serviceAccountKey.json` in this directory

2. Install dependencies:
```bash
pip install firebase-admin
```

### Upload Routes
```bash
python add_routes_to_firebase.py
```

This uploads all routes from `all_routes.json` to Firebase `approved_routes` collection.

## Route Format

Routes in `all_routes.json` should follow this structure:

```json
{
  "id": "gate_to_h16",
  "name": "Hostel 16",
  "fullName": "Main Gate ↔ Hostel 16 (Round Trip)",
  "startGeofence": { "latitude": 19.125937, "longitude": 72.916204, "radius_m": 30 },
  "endGeofence": { "latitude": 19.125937, "longitude": 72.916204, "radius_m": 30 },
  "approvedRoutes": [{
    "routeId": "gate_to_h16_main",
    "polyline": [{"lat": 19.125937, "lon": 72.916204}, ...],
    "expectedDistance_m": 2977
  }],
  "verification": {
    "corridorBuffer_m": 25,
    "minInsideRatio": 0.85,
    "distanceRatioMin": 0.8,
    "distanceRatioMax": 1.3
  }
}
```

