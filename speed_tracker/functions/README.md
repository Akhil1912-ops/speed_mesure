# Cloud Functions

Automated trip verification that runs when trips are uploaded to Firebase.

## Features

- **Route Auto-Detection**: Compares trip against all approved routes (100% shape-based)
- **Route Verification**: Checks if traveled route matches approved route (85% points in 25m corridor)
- **Distance Validation**: Verifies traveled distance is 80-130% of expected
- **Penalty Calculation**: Auto-calculates fines (₹50 per speed violation, ₹100 route deviation)
- **Auto-Scoring**: Generates 0-100 score and verdict (approved/warning/denied)

## Deploy

```bash
npm install
firebase deploy --only functions
```

## Function: verifyTrip

**Trigger**: When a new document is created in `trips` collection

**Process**:
1. Finds best matching route (score ≥ 60/100)
2. Verifies route shape compliance
3. Validates distance
4. Calculates penalty
5. Updates trip with verification results

**Output** (added to trip document):
- `route_detection`: Detected route name and match score
- `verification_result`: Route check, distance check, penalty, verdict
- `auto_verdict`: "approved" | "warning" | "denied"
- `auto_score`: 0-100

