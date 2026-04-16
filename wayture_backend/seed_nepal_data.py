"""
Standalone seed script — populates Firestore with realistic Nepal traffic data.

Uses the FastAPI backend's POST /seed-data endpoint.
Make sure the server is running before executing this script.

Usage:
    python seed_nepal_data.py

The script will:
  1. Call POST /traffic/seed-data to populate all 5 collections
  2. Verify the data by calling GET endpoints
  3. Print a summary of what was created
"""

import requests
import json
import sys

API_BASE = "http://localhost:8000"


def check_server():
    """Verify the FastAPI server is running."""
    try:
        r = requests.get(f"{API_BASE}/health", timeout=5)
        data = r.json()
        print(f"Server status: {data.get('status', 'unknown')}")
        print(f"Firebase: {'connected' if data.get('firebase') else 'NOT connected'}")
        if not data.get("firebase"):
            print("\nERROR: Firebase is not initialized!")
            print("Make sure firebase_credentials.json exists in wayture_backend/")
            sys.exit(1)
        return True
    except requests.exceptions.ConnectionError:
        print(f"ERROR: Cannot connect to {API_BASE}")
        print("Start the server first:")
        print("  cd wayture_backend")
        print("  uvicorn main:app --reload")
        sys.exit(1)


def seed_data():
    """Call the seed endpoint to populate Firestore."""
    print("\nSeeding Firestore with Nepal traffic data...")
    try:
        r = requests.post(f"{API_BASE}/seed-data", timeout=60)
        if r.status_code == 200:
            data = r.json()
            print(f"\nStatus: {data.get('status', '?')}")
            print(f"ML Model: {data.get('ml_model', '?')}")
            print(f"\nCollections populated:")
            for col, count in data.get("collections_populated", {}).items():
                print(f"  {col}: {count} documents")
            return True
        else:
            print(f"ERROR: {r.status_code} — {r.text}")
            return False
    except Exception as e:
        print(f"ERROR: {e}")
        return False


def verify_data():
    """Verify data was created by querying each endpoint."""
    print("\n" + "=" * 50)
    print("Verifying seeded data...")
    print("=" * 50)

    # 1. Traffic data
    try:
        r = requests.get(f"{API_BASE}/traffic?limit=5", timeout=10)
        if r.status_code == 200:
            data = r.json()
            print(f"\ntraffic_data: {len(data)} records returned (showing first 5)")
            for d in data[:3]:
                print(f"  - {d['location_name']}: {d['congestion_level']} | "
                      f"{d['average_speed_kmh']} km/h | {d['vehicle_count']} vehicles")
        else:
            print(f"\ntraffic_data: ERROR {r.status_code}")
    except Exception as e:
        print(f"\ntraffic_data: ERROR {e}")

    # 2. Real-time traffic
    try:
        r = requests.get(f"{API_BASE}/realtime", timeout=10)
        if r.status_code == 200:
            data = r.json()
            print(f"\ntraffic_realtime: {len(data)} locations")
            for d in data[:3]:
                print(f"  - {d.get('location_name', '?')}: {d.get('congestion_level', '?')} | "
                      f"{d.get('average_speed_kmh', '?')} km/h")
        else:
            print(f"\ntraffic_realtime: ERROR {r.status_code}")
    except Exception as e:
        print(f"\ntraffic_realtime: ERROR {e}")

    # 3. Nepal locations
    try:
        r = requests.get(f"{API_BASE}/nepal-locations", timeout=10)
        if r.status_code == 200:
            data = r.json()
            print(f"\nnepal_locations: {len(data)} locations")
            for d in data:
                print(f"  - {d['location_name']}, {d['district']} "
                      f"({d['latitude']:.4f}, {d['longitude']:.4f})")
        else:
            print(f"\nnepal_locations: ERROR {r.status_code}")
    except Exception as e:
        print(f"\nnepal_locations: ERROR {e}")

    # 4. Incidents
    try:
        r = requests.get(f"{API_BASE}/incidents", timeout=10)
        if r.status_code == 200:
            data = r.json()
            print(f"\nincidents: {len(data)} active incidents")
            for d in data[:3]:
                print(f"  - [{d['severity'].upper()}] {d['incident_type']} at "
                      f"{d['location_name']}: {d['description']}")
        else:
            print(f"\nincidents: ERROR {r.status_code}")
    except Exception as e:
        print(f"\nincidents: ERROR {e}")

    # 5. ML prediction test
    try:
        r = requests.get(
            f"{API_BASE}/predict",
            params={"location": "Koteshwor", "latitude": 27.6781, "longitude": 85.3499},
            timeout=10,
        )
        if r.status_code == 200:
            data = r.json()
            print(f"\nML Prediction for Koteshwor:")
            print(f"  Congestion: {data['predicted_congestion']}")
            print(f"  Speed: {data['predicted_speed']} km/h")
            print(f"  Confidence: {data['confidence']}")
            for f in data.get("factors", []):
                print(f"  - {f}")
        else:
            print(f"\nML Prediction: ERROR {r.status_code}")
    except Exception as e:
        print(f"\nML Prediction: ERROR {e}")


def main():
    print("=" * 50)
    print("  Wayture — Nepal Traffic Data Seeder")
    print("=" * 50)

    check_server()
    ok = seed_data()
    if ok:
        verify_data()

    print("\n" + "=" * 50)
    print("Done! Your Firestore now has real Nepal traffic data.")
    print("\nUseful endpoints:")
    print(f"  {API_BASE}/docs                         — Swagger UI")
    print(f"  {API_BASE}/traffic               — all traffic data")
    print(f"  {API_BASE}/traffic/Koteshwor     — Koteshwor data")
    print(f"  {API_BASE}/incidents             — active incidents")
    print(f"  {API_BASE}/nepal-locations        — all locations")
    print(f"  {API_BASE}/predict?location=Thamel — ML prediction")
    print(f"  {API_BASE}/route?origin=Thamel&destination=Koteshwor — directions")
    print("=" * 50)


if __name__ == "__main__":
    main()
