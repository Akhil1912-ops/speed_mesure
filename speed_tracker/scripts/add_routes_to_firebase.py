"""
Upload approved campus routes to Firebase Firestore.

Usage:
    python add_routes_to_firebase.py
"""

import firebase_admin
from firebase_admin import credentials, firestore
import json
import os

def initialize_firebase():
    """Initialize Firebase Admin SDK"""
    try:
        app = firebase_admin.get_app()
    except ValueError:
        cred_path = os.path.join(os.path.dirname(__file__), 'serviceAccountKey.json')
        if not os.path.exists(cred_path):
            print(f"ERROR: serviceAccountKey.json not found at {cred_path}")
            print("\nTo get your service account key:")
            print("1. Go to Firebase Console > Project Settings > Service Accounts")
            print("2. Click 'Generate New Private Key'")
            print("3. Save it as 'serviceAccountKey.json' in this directory")
            return None
        cred = credentials.Certificate(cred_path)
        app = firebase_admin.initialize_app(cred)
    return firestore.client()

def load_routes_from_json():
    """Load routes from all_routes.json file"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    json_file = os.path.join(script_dir, 'all_routes.json')
    
    if os.path.exists(json_file):
        print(f"Loading routes from: {json_file}")
        with open(json_file, 'r') as f:
            routes = json.load(f)
        print(f"✓ Loaded {len(routes)} routes")
        return routes
    else:
        print(f"⚠️  {json_file} not found!")
        return []

def add_routes_to_firebase(db, routes):
    """Upload routes to Firebase Firestore"""
    routes_ref = db.collection('approved_routes')
    
    for route in routes:
        route_id = route['id']
        print(f"Uploading: {route['fullName']}...")
        
        # Convert polyline to Firestore format (objects instead of arrays)
        firestore_route = {}
        for key, value in route.items():
            if key != 'approvedRoutes':
                firestore_route[key] = value
        
        if 'approvedRoutes' in route:
            firestore_route['approvedRoutes'] = []
            for approved_route in route['approvedRoutes']:
                converted = {}
                for k, v in approved_route.items():
                    if k == 'polyline':
                        # Convert [[lat,lon],...] to [{lat,lon},...]
                        converted['polyline'] = [
                            {"lat": float(c[0]), "lon": float(c[1])} 
                            for c in v
                        ]
                    else:
                        converted[k] = v
                firestore_route['approvedRoutes'].append(converted)
        
        routes_ref.document(route_id).set(firestore_route)
        print(f"  ✓ {route_id}")
    
    print(f"\n✓ Uploaded {len(routes)} routes")

def main():
    print("Campus Route Uploader")
    print("=" * 50)
    
    db = initialize_firebase()
    if not db:
        return
    
    routes = load_routes_from_json()
    if not routes:
        return
    
    print(f"\nRoutes to upload ({len(routes)}):")
    for r in routes:
        print(f"  • {r['fullName']}")
    
    if input("\nProceed? (yes/no): ").lower() != 'yes':
        print("Cancelled.")
        return
    
    add_routes_to_firebase(db, routes)
    print("\n✓ Done!")

if __name__ == "__main__":
    main()
