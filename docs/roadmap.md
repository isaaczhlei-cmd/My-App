# flightprint Completion Roadmap

**Date:** 2026-05-19
**Source:** Full repo code review (lib/, test/, pubspec.yaml, docs/app-completion-audit.md)
**Goal:** Ship v1.0 — every screen functional, no "Coming Soon" placeholders, real booking handoff, hardened auth.

---

## Code Review Summary

### Strengths
- Clean feature-folder layout under `lib/screens/`; services are singletons with consistent `({value, error})` record return type.
- `AuthService` already exposes an `AuthServiceLike` seam for tests/mocks.
- `BookFlightScreen` already wires real Skyscanner deep-link handoff via `url_launcher` with 3-stage fallback (`externalApplication` → `platformDefault` → `inAppBrowserView`).
- `compare_screen.dart` already filters to current year (P1 bug from audit `docs/app-completion-audit.md` is resolved despite doc not being updated).
- Swipe-to-delete with 5s undo is in `HomeScreen._buildRecentFlights` (commit `b551e10`).

### Issues found (new, beyond existing audit)

| # | Severity | Location | Problem | Fix |
|---|----------|----------|---------|-----|
| R1 | P0 | `lib/screens/auth/login_screen.dart:600` | `_defaultAuthService` is a top-level `AuthService()` separate from `main.dart`'s `AuthService()` in `AuthWrapper`. Multiple instances are stateless today but invites bugs as soon as caching is added. | Make `AuthService` a singleton (`factory AuthService() => _instance ??= AuthService._()`) or inject via `Provider`. |
| R2 | P0 | `lib/screens/auth/widgets/signup_form.dart:54-58` | Hardcoded colors (`_cardBackground`, `_primaryGreen`, etc.) bypass `AppTheme`. Theme drift on dark/light switch. | Replace constants with `AppColors.*` from `lib/config/theme.dart`. |
| R3 | P0 | `lib/services/auth_service.dart:49-70` | `registerWithEmail` does not create a Firestore user profile doc. Downstream features (display name, default cabin pref, notification settings) have no anchor. | After `createUserWithEmailAndPassword`, write `users/{uid}` doc with `{displayName, email, createdAt, isAnonymous:false}`. Mirror in `signInWithGoogle` (upsert with `SetOptions(merge: true)`). |
| R4 | P1 | `lib/services/auth_service.dart:49-70` | No email-verification step. New accounts are immediately full-access. | Call `credential.user!.sendEmailVerification()` after register; surface a "Verify your email" banner in `HomeScreen` until `user.emailVerified == true`. |
| R5 | P1 | `lib/screens/book_flight/book_flight_screen.dart:862-881` | Only Skyscanner is offered — user requested "direct links to book." Single provider = single point of failure when affiliate is down. | Add provider picker (Google Flights, Kayak, Skyscanner, airline IATA-code deep link). Move URL builders into `lib/services/booking_link_service.dart`. |
| R6 | P1 | `lib/screens/book_flight/book_flight_screen.dart` | Airport autocomplete uses static `AirportDirectory` (small in-repo list). User typing a real city outside the seed list falls back silently. | Either expand seed list to top-N IATA (~500) or call an airport-lookup API; show "no match" hint instead of silent reset. |
| R7 | P1 | `lib/screens/profile/profile_subscreens.dart:69, 117` | `NotificationSettingsScreen` and `AppSettingsScreen` are "Coming Soon" stubs — blocks calling the app feature-complete. | Implement per audit Issue 3 & 4 (toggles backed by `users/{uid}/settings/*`). |
| R8 | P1 | `lib/services/emissions_service.dart:22` | API key passed in URL query string and logged in HTTP error paths. | Move key to `Authorization` header if endpoint supports; otherwise scrub from any logged error string. |
| R9 | P2 | `lib/screens/profile/profile_subscreens.dart:165` (`AboutScreen`) | Static text — no app version, no Travel Impact Model attribution, no privacy URL. | Add `package_info_plus` dependency, render version + Google TIM attribution + links. |
| R10 | P2 | `lib/screens/reports/reports_screen.dart:65` | `flightCount` computed per month but never displayed. | Show count as bar subtitle. |
| R11 | P2 | `lib/screens/home/widgets/flight_card.dart` | No tap action / detail view; can't edit or inspect a logged flight. | Add `FlightDetailScreen` with edit + re-compute emissions + delete. |
| R12 | P2 | `lib/models/flight.dart` | `AirlineCode` / `AirlineNumber` PascalCase on Dart vs camelCase on wire — confusing, lint-noisy. | Rename to lowerCamelCase, keep wire names. |
| R13 | P2 | `test/` | Only `widget_test.dart` and `eco_tip_service_test.dart`. No tests for `AuthService` mock, `FirestoreService`, `BookFlightScreen` URL builder, signup form validation. | Add unit tests for `_buildFlightSearchUri`, `SignupForm._isFormValid`, `AuthService` error-code mapping. |
| R14 | P2 | `pubspec.yaml:2` | Store description should stay app-specific. | Keep real description current for store metadata. |
| R15 | P3 | repo root | No CI workflow; `flutter analyze` / `flutter test` not gated on PR. | Add `.github/workflows/ci.yml` running analyze + test on push. |
| R16 | P3 | `lib/main.dart:11-14` | No error handling around `dotenv.load` or `Firebase.initializeApp`. App crashes silently if `.env` missing. | Wrap in `runZonedGuarded` + show fallback `ErrorScreen` widget. |
| R17 | P3 | repo | No app icon configuration (`flutter_launcher_icons`) and no splash (`flutter_native_splash`). | Add both before store submission. |

---

## Roadmap (sequenced)

### Phase 0 — Foundations (1–2 days)
Goal: any new feature lands on stable scaffolding.

1. **[R1]** Make `AuthService` a true singleton; remove `_defaultAuthService` from `login_screen.dart`.
2. **[R3]** Create `users/{uid}` profile doc on register + Google sign-in (idempotent merge).
3. **[R16]** Wrap `main()` in `runZonedGuarded`; surface init errors with `ErrorScreen`.
4. **[R15]** Add `.github/workflows/ci.yml` → `flutter pub get && flutter analyze && flutter test`.

### Phase 1 — Account creation hardening (1 day)
Goal: "ensure account creation works no problem."

5. **[R2]** Swap hardcoded colors in `signup_form.dart` for `AppColors`.
6. **[R4]** Send email verification on register; add `EmailVerificationBanner` widget on `HomeScreen`.
7. **[R8]** Move TIM key out of query string into header, or sanitize from error messages.
8. **[R13a]** Unit tests: `SignupForm._isFormValid`, `AuthService._getErrorMessage` switch coverage.

### Phase 2 — Finish the Book Flight flow (2–3 days)
Goal: "users direct links to book a flight."

9. **[R5]** Extract `lib/services/booking_link_service.dart`:
   - `Uri skyscannerUri(...)`
   - `Uri googleFlightsUri(...)`  (`https://www.google.com/travel/flights?q=...`)
   - `Uri kayakUri(...)`
   - `Uri airlineDirect(IataCode airline, ...)` (optional)
10. **[R5]** Replace `Search Flights` button with provider chips (Skyscanner default, Google Flights, Kayak); persist last-used provider in `shared_preferences`.
11. **[R6]** Expand `AirportDirectory` to top-500 IATA OR integrate `airportsdotjson` / TIM airport list; show "No matches — try the IATA code" hint when query length ≥ 3 and matches is empty.
12. **Search Flights modal completion:** replace the inline autocomplete dropdown with a full-screen `AirportSearchModal` (`showModalBottomSheet`) — recent-searches list, country grouping, debounced search. The current dropdown is the "not-finished search flights modal" the user referenced.
13. **[R13b]** Unit tests on `BookingLinkService` URI builders.

### Phase 3 — Fill the stubs (2 days)
Goal: kill every "Coming Soon" screen.

14. **[R7a]** `NotificationSettingsScreen` — toggles for weekly digest / milestone / eco tips, written to `users/{uid}/settings/notifications`; integrate `flutter_local_notifications`.
15. **[R7b]** `AppSettingsScreen` — default cabin class (consumed by `AddFlightScreen`), units toggle (kg vs tons across Compare/Reports/Home), CSV export of all flights via `share_plus`.
16. **[R9]** `AboutScreen` — add `package_info_plus` for version, TIM attribution, privacy/terms links.

### Phase 4 — Polish + extra value (2 days)

17. **[R10]** Show monthly `flightCount` on `ReportsScreen` bar chart.
18. **[R11]** `FlightDetailScreen` (route, date, airline, cabin, emissions, edit, delete) reachable via `FlightCard` tap.
19. **[R12]** Normalize `Flight` field casing.
20. **[R14]** Real `pubspec.yaml` description.

### Phase 5 — Release prep (1 day)

21. **[R17]** `flutter_launcher_icons` + `flutter_native_splash` configured.
22. Android: signing config, `applicationId`, target SDK 35 check.
23. iOS: bundle identifier, ATS exceptions for Skyscanner/Google Flights only.
24. Firestore security rules audit — only `users/{uid}/**` writable by `request.auth.uid == uid`.
25. Store listing copy + screenshots from `flutter_01.png` style captures.

---

## Out of scope (v1.1+)
- Carbon offset purchase integration
- Multi-leg / multi-city booking
- Social feed / leaderboard
- Web build polishing (currently functional via `flutter build web` but untested)

---

## Status legend
- **P0** — blocks correct behavior or shipping
- **P1** — user-visible gap, ship blocker for "complete"
- **P2** — polish, low-risk
- **P3** — infra / nice-to-have
