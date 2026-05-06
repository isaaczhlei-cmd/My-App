## Context

The home screen displays a list of logged flights. Currently there is no way to remove a flight once added. The `FirestoreService` handles all CRUD for `users/{uid}/flights/{flightId}` but has no delete method. Flutter's `Dismissible` widget provides built-in swipe gesture support with zero additional dependencies.

## Goals / Non-Goals

**Goals:**
- Let users delete any flight by swiping left on its list tile
- Give users a 5-second undo window via a snackbar before the deletion is permanent
- Keep the UI feeling instant (optimistic removal before Firestore confirms)

**Non-Goals:**
- Bulk delete / select-all
- Long-press context menu
- Delete confirmation dialog (snackbar undo replaces this pattern)
- Syncing undo state across multiple devices or tabs

## Decisions

**Optimistic UI with deferred Firestore delete**
Remove the flight from the local list immediately for a snappy feel, then call `FirestoreService.deleteFlight()` only after the 5-second snackbar expires. If the user taps Undo, re-insert the flight and skip the Firestore call entirely.
Alternative: delete from Firestore immediately and restore on undo. Rejected because it generates an extra write on every accidental swipe and requires a round-trip to restore.

**`Dismissible` with `DismissDirection.endToStart`**
Use Flutter's built-in `Dismissible` wrapping each flight tile. `endToStart` (right-to-left swipe) is the standard destructive gesture on mobile. A red background with a trash icon is revealed as the user swipes, providing clear affordance.
Alternative: `flutter_slidable` package. Rejected to avoid adding a dependency for functionality Flutter's stdlib already covers.

**Snackbar via `ScaffoldMessenger`**
Show a `SnackBar` with label "Flight deleted" and an "Undo" action using `ScaffoldMessenger.of(context)`. Duration: 5 seconds. This is the Material Design pattern for recoverable destructive actions.

**Timer to commit deletion**
Use a `Timer(Duration(seconds: 5), commitDelete)` started when the item is dismissed. Cancelled immediately if undo is tapped. The timer reference is held in local widget state.

## Risks / Trade-offs

- **Fast repeated swipes** — if the user dismisses multiple flights quickly, each gets its own independent timer. No consolidation needed since each flight is a separate Firestore document.
- **Widget disposed before timer fires** — if the user navigates away before the 5 s window, the `Timer` must be cancelled in `dispose()` and the deletion committed synchronously (or via `WidgetsBinding.addPostFrameCallback`). Committed in `dispose()` to avoid a leak.
- **Firestore write failure on delete** — rare, but if `deleteFlight()` throws after the snackbar closes, the flight will reappear on next list refresh. Risk is low; no retry logic needed for v1.

## Migration Plan

No data migration required. The change is purely additive: a new `deleteFlight` method on `FirestoreService` and UI changes to the flight list widget. Rollback is a revert of those two files.
