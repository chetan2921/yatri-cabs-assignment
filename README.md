# Yatri Cabs - Flutter App

India's Leading Inter-City One Way Cab Service Provider

## Features

### Home Screen
- Outstation, Local, and Airport booking modes
- One-way and Round Trip support for outstation
- City and airport search inputs with dropdown suggestions
- Date and time pickers with green themed controls
- Form validation before Explore navigation
- Consistent design system (20px corner radius and brand green #38B000)

### Explore Screen
- Google Maps with live location and recenter support
- Pickup-to-drop route planning and rendering
- Start ride / End ride controls
- Route-aware live ride tracking and odometer updates
- ETA shown beside "Ride in Progress"
- Open navigation in external maps apps

## City Suggestions

- City autocomplete uses Photon (`photon.komoot.io`) with debounce
- If Photon is unavailable, local fallback suggestions are used
- Airport "From Airport" mode uses local airport list directly

## Secure API Key Setup (No Hardcoded Secrets)

This repo is configured to avoid committing API keys.

### Required APIs in Google Cloud
- Maps SDK for Android
- Maps SDK for iOS
- Geocoding API
- Directions API
- Routes API

### Android key (local only)

Add this to `android/local.properties` (already gitignored):

```properties
GOOGLE_MAPS_API_KEY=YOUR_GOOGLE_MAPS_KEY
```

`AndroidManifest.xml` reads `${GOOGLE_MAPS_API_KEY}` via manifest placeholders from Gradle.

### iOS key (local only)

Create `ios/Runner/Secrets.xcconfig` (already gitignored):

```xcconfig
GOOGLE_MAPS_API_KEY = YOUR_GOOGLE_MAPS_KEY
```

The key is injected into `Info.plist` and loaded in `AppDelegate.swift`.

### Flutter runtime key for Directions/Geocoding (local only)

Create a local file at project root:

`dart_defines.local.json` (already gitignored)

```json
{
  "GOOGLE_DIRECTIONS_API_KEY": "YOUR_GOOGLE_MAPS_KEY"
}
```

Run/build with:

```bash
flutter run --dart-define-from-file=dart_defines.local.json
flutter build apk --dart-define-from-file=dart_defines.local.json
```

## Quick Start

1. Install dependencies:

```bash
flutter pub get
```

2. Configure local keys using the sections above.

3. Run the app:

```bash
flutter run --dart-define-from-file=dart_defines.local.json
```

## Tech Stack

| Category | Package |
|----------|---------|
| State Management | `flutter_riverpod` |
| Maps | `google_maps_flutter` |
| Location | `geolocator` |
| Geocoding | `geocoding` |
| Networking | `http` |
| External Navigation | `url_launcher` |
| Local Storage | `hive`, `hive_flutter` |
| Date Formatting | `intl` |
| Typography | `google_fonts` |

## Notes

1. API keys must remain local and never be committed.
2. If map keys are missing, map display may fail.
3. If directions key is missing, route accuracy degrades to fallback behavior.
4. Location permission is required for live ride tracking.
