# Wayture

Traffic Congestion Predictor for Kathmandu. Flutter mobile app (`wayture_frontend/`) + FastAPI backend (`wayture_backend/`).

---

## Requirements

- **Python 3.10 or newer** (3.11 recommended). The backend uses PEP 604 union types (`X | None`) which will not parse on 3.9.
- **Flutter SDK 3.22+ with Dart 3.10+**. Check with `flutter --version`.
- **Android Studio** (for the Android emulator) or a physical Android device with USB debugging.
- A Firebase project (the included `firebase_credentials.json` points at the one used during development — create your own if it has been rotated).

Optional (the app falls back to free services if these are missing):

- Google Maps Platform API key — enables Google Directions / Places / Geocoding. Without it, the backend uses OSRM + Nominatim.
- Groq API key — enables AI-generated traffic commentary. Without it, that section is disabled.

---

## Backend (FastAPI)

```bash
cd wayture_backend
python -m venv venv

# Windows
venv\Scripts\activate
# macOS / Linux
source venv/bin/activate

pip install -r requirements.txt

# Copy the env template and fill in the keys you have.
# Leaving a key blank is fine — the service that needs it will be disabled.
cp .env.example .env          # macOS / Linux
copy .env.example .env        # Windows

# Run the API on http://localhost:8000
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

On startup you should see a banner listing which services connected. Interactive API docs are at `http://localhost:8000/docs`.

### ML model

The `/prediction` endpoint uses scikit-learn `RandomForestClassifier` + `RandomForestRegressor`. It trains lazily from traffic records in Firestore on the first request, or manually via `POST /traffic/train-model`. There are no external model files — nothing to download. If scikit-learn is not installed, the endpoint falls back to a rule-based predictor automatically.

---

## Frontend (Flutter)

```bash
cd wayture_frontend
flutter pub get
flutter run
```

The app auto-detects the platform and points at the backend:

- Android emulator → `http://10.0.2.2:8000`
- Web / desktop → `http://localhost:8000`

If you run on a **physical phone**, edit `lib/services/api_service.dart` and replace the URL with your computer's LAN IP (e.g. `http://192.168.1.42:8000`), and make sure phone and computer are on the same Wi-Fi.

Start the backend first, then launch the Flutter app.

---

## Project layout

```
wayture/
├── wayture_backend/     FastAPI server (auth, routing, prediction, reports)
│   ├── main.py          App entry point
│   ├── routers/         API endpoints grouped by feature
│   ├── services/        Firebase, Google Maps, Groq, weather, ML
│   ├── models/          Pydantic schemas
│   └── requirements.txt
│
└── wayture_frontend/    Flutter app
    ├── lib/
    │   ├── screens/     UI screens
    │   ├── services/    API, auth, location
    │   ├── widgets/     Reusable widgets
    │   └── models/      Data models
    ├── assets/          Images, icons
    └── pubspec.yaml
```

---

## Troubleshooting

- **`SyntaxError: unsupported operand type(s) for |: 'type' and 'NoneType'`** — You are on Python 3.9 or older. Upgrade to 3.10+.
- **Backend prints `Firebase not initialized`** — `firebase_credentials.json` is missing or invalid. Download a service-account JSON from Firebase Console → Project Settings → Service Accounts and drop it next to `main.py`.
- **App opens but every network call fails** — Backend is not running, or you are on a physical device and `api_service.dart` still points at `localhost`. See the frontend section.
- **`flutter pub get` fails with SDK version error** — Your Flutter is older than Dart 3.10 requires. Run `flutter upgrade`.
- **Google Maps tiles are blank / routing fails** — Either `GOOGLE_MAPS_API_KEY` is not set (expected, falls back to OSRM) or the key is set but the server-side APIs (Directions, Geocoding, Places, Distance Matrix) are not enabled on it. Enable them in Google Cloud Console.
