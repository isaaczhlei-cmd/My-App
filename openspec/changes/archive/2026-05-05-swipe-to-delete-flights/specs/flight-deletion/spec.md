## ADDED Requirements

### Requirement: Swipe-to-delete gesture
Each flight list item SHALL support a left swipe (`endToStart`) gesture that triggers deletion. A red background with a delete icon SHALL be revealed as the user swipes to provide visual affordance.

#### Scenario: User swipes a flight item to the left
- **WHEN** a signed-in user swipes a flight tile fully to the left
- **THEN** the flight is immediately removed from the visible list

#### Scenario: Partial swipe does not delete
- **WHEN** a user begins a left swipe but releases before completing it
- **THEN** the tile snaps back to its original position and no deletion occurs

### Requirement: Deletion confirmation snackbar
After a flight is dismissed, the system SHALL display a `SnackBar` with the message "Flight deleted" and an "Undo" action. The snackbar SHALL remain visible for 5 seconds.

#### Scenario: Snackbar appears after swipe
- **WHEN** a flight tile is fully dismissed by swipe
- **THEN** a snackbar reading "Flight deleted" with an "Undo" button appears at the bottom of the screen

#### Scenario: Snackbar auto-dismisses after 5 seconds
- **WHEN** the snackbar is shown and the user takes no action
- **THEN** after 5 seconds the snackbar closes and the flight deletion is permanently committed to Firestore

### Requirement: Undo deletion
The system SHALL allow users to undo a flight deletion within the 5-second snackbar window. Tapping "Undo" SHALL restore the flight to its original position in the list and cancel the Firestore deletion.

#### Scenario: User taps Undo within the window
- **WHEN** the user taps the "Undo" button on the snackbar before it expires
- **THEN** the flight reappears in the list at its previous position and is NOT deleted from Firestore

#### Scenario: Undo is unavailable after snackbar closes
- **WHEN** the snackbar has expired and the deletion is committed
- **THEN** the flight is permanently removed and no undo action is available

### Requirement: Guest users cannot delete flights
The delete gesture SHALL be disabled or inaccessible for anonymous (guest) users, consistent with the app's pattern of restricting data mutations to authenticated accounts.

#### Scenario: Guest user views flight list
- **WHEN** an anonymous user views the flight list
- **THEN** swipe-to-delete is not functional (the `Dismissible` widget is not present or is non-interactive)
