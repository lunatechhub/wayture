"""
Excel Traffic Data Importer for Wayture

Reads traffic data from an Excel file (.xlsx) and uploads all rows
to the FastAPI backend via POST /traffic/upload-traffic-bulk.

Usage:
    python import_excel.py traffic_data.xlsx

The Excel file should have columns like:
    Location | Latitude | Longitude | Congestion Level | Vehicle Count |
    Average Speed | Hour | Day of Week | Date

Column names are matched case-insensitively and flexibly, so
"location", "Location", "LOCATION", "location_name" all work.
"""

import sys
import requests
import pandas as pd

# FastAPI backend URL — adjust if your server is on a different host/port
API_BASE_URL = "http://localhost:8000"
UPLOAD_ENDPOINT = f"{API_BASE_URL}/traffic/upload-traffic-bulk"

# Known Kathmandu locations with their coordinates (fallback if lat/lng missing)
KATHMANDU_LOCATIONS = {
    "koteshwor": (27.6781, 85.3499),
    "kalanki": (27.6933, 85.2814),
    "thamel": (27.7153, 85.3123),
    "new baneshwor": (27.6882, 85.3419),
    "baneshwor": (27.6882, 85.3419),
    "maharajgunj": (27.7369, 85.3300),
    "lazimpat": (27.7220, 85.3238),
    "balaju": (27.7343, 85.3042),
    "chabahil": (27.7178, 85.3457),
    "maitighar": (27.6947, 85.3222),
    "thapathali": (27.6926, 85.3220),
    "tinkune": (27.6844, 85.3465),
    "putalisadak": (27.7030, 85.3200),
    "gaushala": (27.7119, 85.3427),
    "samakhusi": (27.7280, 85.3150),
    "bouddha": (27.7215, 85.3620),
    "swayambhunath": (27.7149, 85.2903),
    "ratnapark": (27.7050, 85.3150),
    "kalimati": (27.6975, 85.3020),
    "tripureshwor": (27.6950, 85.3130),
    "jamal": (27.7080, 85.3170),
    "sundhara": (27.7020, 85.3140),
    "bagbazar": (27.7065, 85.3190),
    "durbar marg": (27.7130, 85.3180),
    "singha durbar": (27.6980, 85.3220),
    "patan": (27.6710, 85.3250),
    "bhaktapur": (27.6720, 85.4298),
    "kirtipur": (27.6780, 85.2780),
    "satdobato": (27.6580, 85.3260),
    "gongabu": (27.7350, 85.3120),
    "naxal": (27.7170, 85.3270),
    "babarmahal": (27.6960, 85.3280),
    "battisputali": (27.7040, 85.3400),
    "sinamangal": (27.6890, 85.3490),
}


def find_column(df: pd.DataFrame, candidates: list[str]) -> str | None:
    """Find a column in the DataFrame by trying multiple name variants."""
    df_cols_lower = {c.lower().strip().replace(" ", "_"): c for c in df.columns}
    for candidate in candidates:
        key = candidate.lower().strip().replace(" ", "_")
        if key in df_cols_lower:
            return df_cols_lower[key]
    return None


def get_coords_for_location(location: str) -> tuple[float, float]:
    """Look up coordinates for a known Kathmandu location."""
    key = location.lower().strip()
    for name, coords in KATHMANDU_LOCATIONS.items():
        if name in key or key in name:
            return coords
    # Default to Kathmandu center
    return (27.7172, 85.3240)


def speed_to_congestion(speed: float) -> str:
    """Convert average speed to a congestion level."""
    if speed <= 10:
        return "red"
    elif speed <= 25:
        return "yellow"
    return "green"


def parse_excel(file_path: str) -> list[dict]:
    """Read an Excel file and return a list of traffic data dicts."""
    print(f"Reading Excel file: {file_path}")
    df = pd.read_excel(file_path, engine="openpyxl")
    print(f"Found {len(df)} rows and {len(df.columns)} columns")
    print(f"Columns: {list(df.columns)}")

    # Map columns flexibly
    col_location = find_column(df, [
        "location", "location_name", "place", "area", "road", "street", "name",
    ])
    col_lat = find_column(df, ["latitude", "lat"])
    col_lng = find_column(df, ["longitude", "lng", "lon", "long"])
    col_congestion = find_column(df, [
        "congestion_level", "congestion", "traffic_level", "level", "status",
    ])
    col_vehicles = find_column(df, [
        "vehicle_count", "vehicles", "count", "num_vehicles", "traffic_count",
    ])
    col_speed = find_column(df, [
        "average_speed", "avg_speed", "speed", "speed_kmh", "mean_speed",
    ])
    col_hour = find_column(df, ["hour", "time_hour", "hr"])
    col_day = find_column(df, [
        "day_of_week", "day", "weekday", "day_name",
    ])
    col_date = find_column(df, ["date", "observation_date", "record_date"])

    print(f"\nColumn mapping:")
    print(f"  Location:   {col_location or '(not found — will use row index)'}")
    print(f"  Latitude:   {col_lat or '(not found — will use location lookup)'}")
    print(f"  Longitude:  {col_lng or '(not found — will use location lookup)'}")
    print(f"  Congestion: {col_congestion or '(not found — will derive from speed)'}")
    print(f"  Vehicles:   {col_vehicles or '(not found — will default to 0)'}")
    print(f"  Speed:      {col_speed or '(not found — will default to 30)'}")
    print(f"  Hour:       {col_hour or '(not found — will default to 12)'}")
    print(f"  Day:        {col_day or '(not found — will default to Monday)'}")
    print(f"  Date:       {col_date or '(not found — will skip)'}")
    print()

    records = []
    for idx, row in df.iterrows():
        # Location
        location = str(row[col_location]).strip() if col_location and pd.notna(row[col_location]) else f"Location_{idx}"

        # Coordinates
        if col_lat and col_lng and pd.notna(row.get(col_lat)) and pd.notna(row.get(col_lng)):
            lat = float(row[col_lat])
            lng = float(row[col_lng])
        else:
            lat, lng = get_coords_for_location(location)

        # Speed
        speed = float(row[col_speed]) if col_speed and pd.notna(row.get(col_speed)) else 30.0

        # Congestion level
        if col_congestion and pd.notna(row.get(col_congestion)):
            raw = str(row[col_congestion]).lower().strip()
            if raw in ("red", "high", "heavy", "congested"):
                congestion = "red"
            elif raw in ("yellow", "medium", "moderate"):
                congestion = "yellow"
            else:
                congestion = "green"
        else:
            congestion = speed_to_congestion(speed)

        # Vehicle count
        vehicles = int(row[col_vehicles]) if col_vehicles and pd.notna(row.get(col_vehicles)) else 0

        # Hour
        hour = int(row[col_hour]) if col_hour and pd.notna(row.get(col_hour)) else 12

        # Day of week
        day = str(row[col_day]).strip() if col_day and pd.notna(row.get(col_day)) else "Monday"

        # Date
        date = str(row[col_date]).strip() if col_date and pd.notna(row.get(col_date)) else None

        records.append({
            "location": location,
            "latitude": lat,
            "longitude": lng,
            "congestion_level": congestion,
            "vehicle_count": vehicles,
            "average_speed": speed,
            "hour": hour,
            "day_of_week": day,
            "date": date,
            "source": "excel_import",
        })

    return records


def upload_to_api(records: list[dict]) -> bool:
    """Upload parsed records to the FastAPI backend in bulk."""
    print(f"Uploading {len(records)} records to {UPLOAD_ENDPOINT} ...")

    # Upload in chunks of 200 to avoid timeout
    chunk_size = 200
    total_uploaded = 0

    for i in range(0, len(records), chunk_size):
        chunk = records[i:i + chunk_size]
        payload = {"records": chunk}

        try:
            resp = requests.post(UPLOAD_ENDPOINT, json=payload, timeout=60)
            if resp.status_code == 200:
                result = resp.json()
                total_uploaded += result.get("count", len(chunk))
                print(f"  Chunk {i // chunk_size + 1}: {result.get('count', len(chunk))} records uploaded")
            else:
                print(f"  Chunk {i // chunk_size + 1} FAILED: {resp.status_code} — {resp.text}")
                return False
        except requests.exceptions.ConnectionError:
            print(f"\nERROR: Cannot connect to {API_BASE_URL}")
            print("Make sure the FastAPI server is running:")
            print("  cd wayture_backend")
            print("  uvicorn main:app --reload")
            return False
        except Exception as e:
            print(f"  Chunk {i // chunk_size + 1} ERROR: {e}")
            return False

    print(f"\nSUCCESS: {total_uploaded} records uploaded to Firestore!")
    return True


def train_model() -> bool:
    """Trigger ML model training after data upload."""
    print("\nTraining ML model on uploaded data ...")
    try:
        resp = requests.post(f"{API_BASE_URL}/traffic/train-model", timeout=60)
        if resp.status_code == 200:
            result = resp.json()
            print(f"  Model trained on {result.get('samples_trained', '?')} samples")
            print(f"  Classes: {result.get('congestion_classes', [])}")
            fi = result.get("feature_importances", {})
            if fi:
                print(f"  Feature importances:")
                for name, imp in fi.items():
                    print(f"    {name}: {imp:.3f}")
            return True
        else:
            print(f"  Training failed: {resp.status_code} — {resp.text}")
    except Exception as e:
        print(f"  Training error: {e}")
    return False


def main():
    if len(sys.argv) < 2:
        print("Usage: python import_excel.py <excel_file.xlsx>")
        print("\nExample: python import_excel.py kathmandu_traffic_data.xlsx")
        print("\nExpected Excel columns (flexible matching):")
        print("  Location, Latitude, Longitude, Congestion Level,")
        print("  Vehicle Count, Average Speed, Hour, Day of Week, Date")
        print("\nNot all columns are required — the script will use defaults")
        print("for missing columns and auto-detect Kathmandu coordinates.")
        sys.exit(1)

    file_path = sys.argv[1]

    # Parse Excel
    records = parse_excel(file_path)
    if not records:
        print("No records found in the Excel file.")
        sys.exit(1)

    # Show sample
    print(f"Sample record:")
    for key, val in records[0].items():
        print(f"  {key}: {val}")
    print()

    # Upload
    success = upload_to_api(records)
    if not success:
        sys.exit(1)

    # Train ML model
    train_model()

    print("\nDone! You can now:")
    print("  GET  http://localhost:8000/traffic/traffic         — view all data")
    print("  GET  http://localhost:8000/traffic/predict?location=Koteshwor  — ML prediction")
    print("  GET  http://localhost:8000/traffic/route?origin=Thamel&destination=Koteshwor  — directions")


if __name__ == "__main__":
    main()
