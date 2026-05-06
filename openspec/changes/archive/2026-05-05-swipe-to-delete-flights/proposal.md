## Why

Users have no way to remove flights they've logged incorrectly or no longer want tracked. Adding swipe-to-delete with undo support gives users control over their flight history without the risk of accidental data loss.

## What Changes

- Flight list items become swipeable — swiping left reveals a delete action
- Deleting a flight shows a snackbar with an "Undo" button (5-second window)
- If undo is tapped, the flight is restored to Firestore and re-inserted in the list
- If the snackbar times out, the deletion is committed permanently
- Firestore deletion is deferred until the undo window closes

## Capabilities

### New Capabilities
- `flight-deletion`: Swipe-to-delete gesture on flight list items with optimistic UI removal, Firestore deletion, and snackbar-based undo within a 5-second window

### Modified Capabilities

## Impact

- `lib/screens/home/` — flight list widget gains `Dismissible` wrapper
- `lib/services/firestore_service.dart` — new `deleteFlight(flightId)` method
- No new dependencies required (Flutter's built-in `Dismissible` + `ScaffoldMessenger`)
