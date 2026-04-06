# Yatri Cabs - Flutter App

India's Leading Inter-City One Way Cab Service Provider

## 📱 Screens

### 1. Home Screen (pixel-perfect from Figma)
- **Outstation Trip** tab: One-way / Round Trip toggle, Pickup City, Drop City, Date(s), Time
- **Local Trip** tab: Pickup City, Pickup Date, Time
- **Airport Transfer** tab: To/From Airport toggle, city/airport search, Date, Time
- City autocomplete dropdown (opens as you type)
- Functional date picker (calendar UI)
- Functional time picker
- Green "Explore Cabs" button → navigates to ride screen
- Bottom nav: Home, My Trip, Account, More
- Fully responsive via MediaQuery

### 2. Explore Cabs Screen (custom design)
- Google Maps with live location
- Pickup → Drop route display
- **Start Ride** button → begins ride
- Live odometer: `0.00 km` updates every 5 seconds
- GPS coordinates saved to Hive (local storage) every 5 sec
- **End Ride** button → shows ride summary modal
- My Location button

---

## 🚀 Setup

### Prerequisites
- Flutter SDK ≥ 3.0.0
- Dart ≥ 3.0.0
- Google Maps API Key with these APIs enabled:
  - Maps SDK for Android
  - Maps SDK for iOS
  - Directions API (optional - for route drawing)

### 1. Get dependencies
```bash
flutter pub get
```

### 2. Add your Google Maps API Key

**Android** — `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ACTUAL_API_KEY_HERE"/>
```

**iOS** — `ios/Runner/AppDelegate.swift`:
```swift
GMSServices.provideAPIKey("YOUR_ACTUAL_API_KEY_HERE")
```

### 3. Android min SDK
In `android/app/build.gradle.kts`, ensure:
```kotlin
minSdk = 21
```

### 4. Run
```bash
flutter run
```

---

## 📦 Tech Stack

| Category | Package |
|----------|---------|
| State Management | `flutter_riverpod` ^2.4.9 |
| Maps | `google_maps_flutter` ^2.5.3 |
| GPS | `geolocator` ^11.0.0 |
| City Autocomplete | Custom overlay (built-in) |
| Local Storage | `hive` + `hive_flutter` ^2.2.3 |
| Date Formatting | `intl` ^0.19.0 |
| Font | `google_fonts` ^6.1.0 (Poppins) |
| Responsive UI | `MediaQuery` (built-in) |

---

## 🎨 Design System

| Token | Value |
|-------|-------|
| Primary Green | `#38B000` |
| Background | `#212728` |
| Field Background | `#D5F2C8` |
| Font | Poppins (via google_fonts) |
| Card Radius | 20px |
| Field Height | 58px |
| Tab Size | 80px height |
| Nav Bar | 85px height |

---

## 📁 Project Structure

```
lib/
├── main.dart                    # Entry point, ProviderScope + Hive init
├── providers/
│   └── home_provider.dart       # All Riverpod providers & state
├── screens/
│   ├── home_screen.dart         # Full home screen (all 3 tabs)
│   └── explore_cabs_screen.dart # Maps + ride tracking screen
├── utils/
│   ├── app_theme.dart           # Colors, text styles
│   └── cities.dart              # Indian cities + airports list
└── widgets/
    ├── city_search_field.dart   # Typeahead city autocomplete
    ├── date_time_field.dart     # Date & dual-date fields
    ├── yatri_logo.dart          # YATRICABS logo widget
    └── promo_banner.dart        # Promotional banner
```

---

## ⚠️ Notes

1. The Google Maps API key is **required** for the Explore Cabs screen to work
2. Location permission must be granted on device for GPS tracking
3. All coordinates are stored in Hive box `ride_coordinates`
4. The odometer resets each time a new ride starts
5. The city autocomplete is built with a custom `Overlay` — no external package needed
6. State management uses **Riverpod** (StateNotifier pattern)
7. All UI is responsive using **MediaQuery**
