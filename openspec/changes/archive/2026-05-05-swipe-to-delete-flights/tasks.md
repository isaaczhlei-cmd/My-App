## 1. Firestore Service

- [x] 1.1 Add `deleteFlight(String flightId)` method to `FirestoreService` that deletes `users/{uid}/flights/{flightId}`
- [x] 1.2 Guard `deleteFlight` with a `currentUser` null-check and `isAnonymous` check (return early, consistent with existing service patterns)

## 2. Flight List Widget — Swipe Gesture

- [x] 2.1 Locate the flight list widget in `lib/screens/home/` and identify where individual flight tiles are rendered
- [x] 2.2 Wrap each flight tile with a `Dismissible` widget keyed by flight ID (`Key(flight.id)`)
- [x] 2.3 Set `direction: DismissDirection.endToStart` on the `Dismissible`
- [x] 2.4 Add a red `background` / `secondaryBackground` with a `Icons.delete` icon aligned to the right end

## 3. Optimistic Removal & Undo Logic

- [x] 3.1 On `onDismissed`, immediately remove the flight from the local list state (optimistic UI)
- [x] 3.2 Start a `Timer(Duration(seconds: 5), ...)` that calls `FirestoreService.deleteFlight(flightId)` when it fires
- [x] 3.3 Store the `Timer` reference and the removed `Flight` object in widget state so undo can cancel/restore them
- [x] 3.4 Override `dispose()` to cancel any active timer and commit pending deletions (call `deleteFlight` synchronously via `WidgetsBinding.addPostFrameCallback` or direct call) to avoid leaks

## 4. Snackbar

- [x] 4.1 After dismissal, show a `SnackBar` via `ScaffoldMessenger.of(context)` with label "Flight deleted" and duration of 5 seconds
- [x] 4.2 Add an "Undo" `SnackBarAction` that cancels the timer and re-inserts the flight into the local list at its original index
- [x] 4.3 Dismiss any previously open snackbar before showing a new one (`ScaffoldMessenger.of(context).hideCurrentSnackBar()`) to handle rapid successive deletes cleanly

## 5. Guest User Guard

- [x] 5.1 Conditionally disable or omit the `Dismissible` wrapper for anonymous users (check `FirebaseAuth.instance.currentUser?.isAnonymous`)

## 6. Verification

- [ ] 6.1 Test: swipe a flight, let the snackbar expire — confirm flight is gone from Firestore
- [ ] 6.2 Test: swipe a flight, tap Undo — confirm flight reappears in list and Firestore document still exists
- [ ] 6.3 Test: swipe multiple flights in quick succession — confirm each has independent undo behavior
- [ ] 6.4 Test: navigate away during the 5-second window — confirm no crash and deletion commits correctly
