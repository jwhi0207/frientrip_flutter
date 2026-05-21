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
- ✅ Full feature parity with Android app (all 10 screens complete)
- ✅ App ID: `com.bennybokki.frientrip` (matches Android)
- ✅ Firebase connected — Auth, Firestore, Storage
- ✅ Google Sign-In: debug SHA-1 registered in Firebase Console
- ⏳ iOS: `GoogleService-Info.plist` + URL schemes still needed (Phase 3)
- ⏳ Release signing keystore not yet configured (Phase 8)

## Sensitive files (NOT in git — must be obtained per machine)
- `lib/firebase_options.dart` — regenerate with `flutterfire configure`
- `android/app/google-services.json` — download from Firebase Console → Project Settings → Android app (`com.bennybokki.frientrip`)
- `ios/Runner/GoogleService-Info.plist` — download from Firebase Console → Project Settings → iOS app, then add to Xcode Runner target

## First-time setup on a new machine
1. Clone the repo
2. Install Flutter SDK (`C:\Users\PC\flutter` on this machine)
3. Run `flutter pub get`
4. Download `android/app/google-services.json` from Firebase Console → Project Settings → Android app (`com.bennybokki.frientrip`)
5. Run `flutterfire configure` → select `frientrip-1e322` project (generates `lib/firebase_options.dart`)
6. **Android Google Sign-In**: get your machine's debug SHA-1 and register it in Firebase Console:
   - Use Android Studio's JDK keytool (not JDK 8):
     `"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android`
   - Copy the SHA1 line → Firebase Console → Project Settings → Android app → Add fingerprint
   - Download the updated `google-services.json` and replace `android/app/google-services.json`
7. Run `flutter run`

## This machine's registered debug SHA-1
`20:83:51:0B:40:81:60:77:AE:B9:0C:EB:57:5E:C8:87:D2:60:60:F4` (registered 2026-05-20)

## Release signing
- Keystore: `C:\Users\PC\keystores\frientrip-release.jks` (NOT in git — keep backed up)
- Alias: `frientrip`
- Release SHA-1: `BB:2B:2E:73:13:AF:EA:36:60:B4:BD:47:33:18:03:8F:E1:EA:A0:7F` (registered in Firebase Console)
- Credentials stored in `android/key.properties` (gitignored) — must be recreated on new machines
- Build release APK: `flutter build apk --release`
- Build release App Bundle (for Play Store): `flutter build appbundle --release`

## Firebase rules deployment
- Firestore rules: `firestore.rules` → `firebase deploy --only firestore:rules`
- Storage rules: `storage.rules` → `firebase deploy --only storage`
- Both at once: `firebase deploy --only firestore:rules,storage`
