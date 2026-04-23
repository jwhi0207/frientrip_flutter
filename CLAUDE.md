# Frientrip Flutter Project

## What this is
Flutter port of the Frientrip Android app (Kotlin/Compose). The goal is feature parity with the Android app plus iOS support. Both apps share the same Firebase project and Firestore database.

## Android source of truth
The Android app lives at a sibling repo. When in doubt about how a feature should behave, refer to the Android implementation.

## Stack
- Flutter + Dart
- Firebase Auth + Firestore + Storage (same Firebase project as Android app)
- **State management**: Riverpod (`flutter_riverpod` + `riverpod_annotation`)
- **Navigation**: `go_router`
- **Images**: `cached_network_image`
- **Formatting**: `intl`
- **Auth**: `firebase_auth` + `google_sign_in`

## Project structure
```
lib/
  main.dart               — Firebase init, ProviderScope, MaterialApp.router
  router.dart             — GoRouter with auth redirect (routerProvider)
  firebase_options.dart   — NOT in git, regenerate with: flutterfire configure
  models/                 — Dart data classes (Trip, TripMember, UserProfile, SupplyItem, etc.)
  providers/              — Riverpod providers (auth_provider.dart, trip_provider.dart, etc.)
  repositories/           — Firestore operations (TripRepository, UserRepository)
  screens/
    auth/                 — login_screen.dart, register_screen.dart
    trips/                — trip_list_screen.dart
    trip/                 — per-trip screens (dashboard, supplies, expenses, carpool, etc.)
    profile/              — profile_screen.dart
  widgets/                — shared widgets (AvatarWidget, VividCard, etc.)
  utils/                  — CostCalculator, helpers
```

## Architecture patterns
- **Riverpod `StreamProvider`** for all Firestore real-time streams (equivalent of Kotlin `callbackFlow`)
- **`@riverpod class XNotifier extends _$XNotifier`** for all mutations (equivalent of Android ViewModel)
- **`ConsumerWidget`** for all screens that read state (equivalent of `@Composable` + `collectAsState`)
- **`ref.watch(provider)`** to read state, **`ref.read(provider.notifier).method()`** to trigger actions
- **`ref.listen(provider, callback)`** for one-shot side effects (navigation after save, error snackbars)
- Trip-scoped providers are family providers keyed by `tripId`: e.g. `ref.watch(tripDetailsProvider(tripId))`

## Navigation
GoRouter with `StatefulShellRoute.indexedStack` for the 5-tab trip shell:
```
/login
/register
/profile
/trips
/trips/:tripId/dashboard    ← tab 0
/trips/:tripId/lodging      ← tab 1
/trips/:tripId/supplies     ← tab 2
/trips/:tripId/carpool      ← tab 3
/trips/:tripId/group        ← tab 4
/trips/:tripId/expenses     ← pushed (not a tab)
/trips/:tripId/manage       ← drawer access
/trips/:tripId/history      ← drawer access
```

## Firestore schema (shared with Android)
- `/users/{uid}` — displayName, email, avatarSeed (int), avatarColor (int), role
- `/trips/{tripId}` — name, ownerId, houseURL, thumbnailURL, totalNights, totalCost, memberIds[], deactivatedMemberIds[], pendingInviteEmails[], inviteCode, inviteCodeEnabled, address, checkInMillis, checkOutMillis, description, emoji
- `/trips/{tripId}/members/{uid}` — displayName, email, avatarSeed, avatarColor, nightsStayed, amountPaid, pendingPaymentAmount, pendingPaymentStatus, status
- `/trips/{tripId}/supplies/{id}` — name, category, quantity, sortOrder, claimedByUids[], claimedByName
- `/trips/{tripId}/expenses/{id}` — description, amount, splitMethod, approved, submittedByUid, submittedByName, createdAt, linkedSupplyId
- `/trips/{tripId}/rides/{id}` — vehicleEmoji, vehicleLabel, driverUid, driverName, totalSeats, passengerUids[], passengerNames[], departureTime, returnTime, departureLocation, notes
- `/trips/{tripId}/rideRequests/{uid}` — uid, displayName
- `/trips/{tripId}/history/{id}` — category, description, timestamp

## Avatar system
- `avatarSeed` (int 0–12) — selects which DiceBear Pixel Art character
- `avatarColor` (int 0–11) — selects background color from fixed palette
- DiceBear URL: `https://api.dicebear.com/9.x/pixel-art/png?seed=$seed&size=128`

## Invite / join flow
- Codes are `XXXX-XXXX` format (alphabet excludes I/L/O/0/1)
- `findTripByInviteCode` queries by `inviteCode` + `inviteCodeEnabled == true`
- Firestore rule: members `allow read` includes `|| request.auth.uid == uid` (needed for deactivation check before joining)

## Current build status
- ✅ Firebase connected (`firebase_options.dart` generated — not in git, must be regenerated on each machine)
- ✅ Auth screens: email/password + Google Sign-In
- ✅ Router with auth redirect
- ✅ Models: Trip, TripMember, UserProfile
- 🚧 Trip list screen — stub only
- ❌ Everything else not yet built

## Implementation plan
See the 10-phase plan:
- Phase 0: Foundation (models, repositories, shared widgets, CostCalculator)
- Phase 1: Trip List Screen (full)
- Phase 2: Trip Shell (navigation scaffold)
- Phase 3: Trip Dashboard
- Phase 4: House Details
- Phase 5: Supplies Screen
- Phase 6: Expenses Screen
- Phase 7: Carpool Screen
- Phase 8: Group/Invite Screen
- Phase 9: Manage Group + Trip History
- Phase 10: Profile Screen

## First-time setup on a new machine
1. Clone the repo
2. Install Flutter SDK
3. Run `flutter pub get`
4. Run `flutterfire configure` and select the `frientrip` Firebase project (generates `lib/firebase_options.dart`)
5. For Google Sign-In on Android: register the machine's debug SHA-1 in Firebase Console → Project Settings → Android app
6. Run `flutter run`
