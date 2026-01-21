# Flight Carbon Tracker - Basic Outline

## Tech Stack
- **Flutter** (iOS, Android, Web)
- **Firebase Auth** (Google Sign-In)
- **Cloud Firestore** (database)
- **Google Travel Impact Model API** (carbon calculations)

---

## App Structure

```
lib/
├── main.dart
├── firebase_options.dart (auto-generated)
│
├── config/
│   └── theme.dart
│
├── models/
│   └── flight.dart
│
├── services/
│   ├── auth_service.dart
│   └── carbon_service.dart
│
├── screens/
│   ├── auth/
│   │   └── login_screen.dart
│   ├── home/
│   │   └── home_screen.dart
│   ├── add_flight/
│   │   └── add_flight_screen.dart
│   ├── flight_details/
│   │   └── flight_details_screen.dart
│   └── profile/
│       └── profile_screen.dart
│
└── widgets/
    └── bottom_nav.dart
```

---

## Screens (5 total)

| Screen | Purpose |
|--------|---------|
| **Login** | Google Sign-In button |
| **Home/Dashboard** | Total CO2, recent flights list |
| **Add Flight** | Enter origin/destination, get emissions |
| **Flight Details** | View single flight impact + equivalents |
| **Profile** | User info, sign out button |

---

## Data Model

```dart
class Flight {
  String id;
  String odriginCode;      // "SFO"
  String destinationCode; // "JFK"
  DateTime date;
  String travelClass;     // economy, business, first
  double emissionsKg;
  DateTime createdAt;
}
```

---

## Firestore Structure

```
users/{userId}/
  └── flights/{flightId}/
        ├── originCode
        ├── destinationCode
        ├── date
        ├── travelClass
        ├── emissionsKg
        └── createdAt
```

---

## Core User Flows

**1. Sign In**
```
Login Screen → Google Sign-In → Home Screen
```

**2. Add Flight**
```
Tap "+" → Enter airports → Select class → See CO2 estimate → Save
```

**3. View Impact**
```
Home Screen → Tap flight → See details + environmental equivalents
```

---

## MVP Features Checklist

- [ ] Firebase Auth (Google Sign-In)
- [ ] Dark theme (matches mockup)
- [ ] Bottom navigation (Home, Add, Profile)
- [ ] Add flight form (origin, destination, class, date)
- [ ] Carbon calculation (Google Travel Impact Model API)
- [ ] Save flights to Firestore
- [ ] Display total emissions on dashboard
- [ ] Flight details with equivalents (miles driven, trees, etc.)
- [ ] Sign out

---

## APIs

**Google Travel Impact Model** (free, no key needed for typical emissions)
```
POST https://travelimpactmodel.googleapis.com/v1/flights:computeFlightEmissions
```

---

## Next Steps

1. Initialize Firebase in `main.dart`
2. Create dark theme
3. Build login screen with Google Sign-In
4. Build home screen shell
5. Add bottom navigation
