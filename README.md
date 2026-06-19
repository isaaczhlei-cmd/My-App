# FlightPrint

> Track your flights. Understand your carbon footprint. Fly more consciously.

FlightPrint is an iOS app built with Flutter and Firebase that lets travelers log flights, estimate CO₂ emissions, and compare the environmental impact of their trips over time.

---

## Features

- **Flight Logging** — Add flights by route, airline, cabin class, and date. Swipe to delete with 5-second undo.
- **CO₂ Emissions** — Per-flight carbon estimates powered by the Google Travel Impact Model API, with distance-based fallback when exact model data is unavailable.
- **Reports** — Monthly bar chart of emissions and flight count. Annual totals with carbon equivalency storytelling (driving distance, home energy use).
- **Compare** — Side-by-side route comparison to find the lower-emission option for an upcoming trip.
- **Book Flight** — Deep-link handoff to Skyscanner, Google Flights, or Kayak to complete a booking.
- **Flight History** — Full scrollable list of all logged flights with swipe-to-delete.
- **Eco Tips** — Contextual tips on flying more sustainably.
- **Notifications** — In-app notification inbox for milestones, weekly digests, and eco tips.
- **Settings** — Default cabin class, units (kg / tons), accent color, dark/light/system theme, airplane mode preference, CSV export of all flights.
- **Sign in with Apple & Google** — Privacy-friendly auth with full account deletion support.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| Auth | Firebase Authentication (Google, Apple, Email) |
| Database | Cloud Firestore |
| Storage | Firebase Storage (profile photos) |
| Emissions API | Google Travel Impact Model |
| State | Singleton services + `ListenableBuilder` |
| Theme | Custom `AppTheme` with dynamic accent color |

---

## Project Structure

```
lib/
  config/         # Theme, colors
  models/         # Flight, user data models
  screens/        # Feature screens (add_flight, home, compare, reports, book_flight, profile, auth)
  services/       # Auth, Firestore, emissions, airport lookup, booking links, notifications
  widgets/        # Shared widgets (FlightCard, AirplaneModeOverlay, ErrorScreen)
```

---

## Privacy Policy

[Privacy Policy](https://www.termsfeed.com/live/dc705239-ff72-4c21-ba92-7d8ef653262c)

---

## iOS Requirements

- iOS 15.0+
- Xcode 15+
- Sign in with Apple capability enabled in Apple Developer portal
- Apple auth provider enabled in Firebase console
