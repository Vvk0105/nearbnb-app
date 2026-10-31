# NearBnB guest app (Flutter)

The guest side of NearBnB on Android (iOS later): search by the hour, request a stay, pay by card, manage trips,
notifications and the account. Hosts and admins keep using the website.

The app talks to the same API as the website (`https://api.nearbnb.com/api/v1`, code in the `nearbnb` repo).
Nothing here holds a secret: Stripe's publishable key comes from the API at payment time, and the Firebase file
(`google-services.json`) is not secret but is kept out of git so each environment uses its own.

> **Status:** first version, generated and not yet compiled or run on a device. Expect small compile fixes on the first
> `flutter analyze`. Please report anything bigger with the template in `docs/BUG_REPORT.md`.

## First-time setup

Needs Flutter 3.27 or newer (`flutter --version`).

```bash
# 1. Generate the Android and iOS project folders (this repo holds lib/, test/ and pubspec.yaml only).
#    --project-name must stay nearbnb_app (the Dart imports use it).
flutter create . --project-name nearbnb_app --org com.nearbnb --platforms android,ios

# 2. Get the packages. If a version below is no longer available, `flutter pub upgrade --major-versions` and re-run tests.
flutter pub get

# 3. Check and test
flutter analyze
flutter test
```

### Android settings the packages need

`flutter create` makes defaults that need these changes:

1. **App id** `com.nearbnb.app` (cannot change after the first Play release). In `android/app/build.gradle(.kts)`:
   set `applicationId = "com.nearbnb.app"` and `namespace = "com.nearbnb.app"`, and move `MainActivity` to
   `android/app/src/main/kotlin/com/nearbnb/app/MainActivity.kt` with `package com.nearbnb.app`.
2. **Stripe** needs a fragment activity and an AppCompat theme:
   - `MainActivity` extends `io.flutter.embedding.android.FlutterFragmentActivity` (not `FlutterActivity`).
   - In `android/app/src/main/res/values/styles.xml` (and `values-night`), both styles' parents become
     `Theme.MaterialComponents.DayNight.NoActionBar` (LaunchTheme can keep its background drawable).
3. **minSdk 23** (`minSdk = 23` in `defaultConfig`) for Stripe and Firebase.
4. **Notifications** (`flutter_local_notifications`) need core library desugaring:
   `compileOptions { isCoreLibraryDesugaringEnabled = true }` and
   `dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }`.
5. **Internet in release builds**: add `<uses-permission android:name="android.permission.INTERNET"/>` to
   `android/app/src/main/AndroidManifest.xml` (flutter create only puts it in the debug manifest).
6. **Firebase**: put `google-services.json` (Firebase console, Android app `com.nearbnb.app`) in `android/app/`, and add
   the Google services Gradle plugin (`com.google.gms.google-services`) to `settings.gradle(.kts)` and `app/build.gradle(.kts)`,
   as the Firebase console shows. Without the file the app still runs, just without push notifications.
7. App name: `android:label="NearBnB"` in the manifest. App icon: replace the `mipmap` icons (or use `flutter_launcher_icons`).

## Running

```bash
flutter run                                                       # against the live API
flutter run --dart-define=API_ORIGIN=http://10.0.2.2:8000         # emulator -> the API in Docker on your PC
flutter run --dart-define=API_ORIGIN=http://192.168.1.20:8000     # real phone -> your PC on the same Wi-Fi
```

Plain `http://` only works in debug builds: add `android:usesCleartextTraffic="true"` to
`android/app/src/debug/AndroidManifest.xml` when testing against a local API.

**Payments in testing:** the live server uses Stripe **test** keys for now, so use test cards such as
`4242 4242 4242 4242`, any future date, any CVC. A local API without Stripe keys shows a "Test payment" dialog instead of the card form.

## How it fits together

```
lib/
  main.dart                 start-up: Firebase (optional), theme, router
  app/router.dart           every screen's address + how website links in notifications map to screens
  app/shell.dart            bottom tabs (Explore, Trips, Alerts, Profile) and the "accept updated terms" gate
  core/api.dart             the HTTP client: X-Client: mobile, bearer token, one automatic refresh, ApiException
  core/providers.dart       sign-in state (AuthController): login, register + email code, logout, delete account
  core/push.dart            Firebase push: register the phone after sign-in, remove it before sign-out, open taps
  core/models.dart          API responses as Dart classes (field names follow the API)
  core/theme.dart           brand colours (same teal as the website) and component styles
  features/...              one folder per area: auth, explore, property (+ booking), trips, notifications, profile
  widgets/...               shared pieces: property card, month calendar, price breakdown, status badge
test/                       unit tests (formatting, search params, link mapping, models, token refresh)
```

**Sign-in.** The app sends `X-Client: mobile`, so `/auth/login` and `/auth/verify-email` return
`{"tokens": {"access_token", "refresh_token"}}` in the body instead of cookies. Tokens live in the phone's secure storage.
Every request sends `Authorization: Bearer <access>`; on a 401 the client calls `/auth/refresh` with
`X-Refresh-Token` once and repeats the request. A used refresh token is dead (the server rotates it), so never retry a refresh.
The app has no captcha; the API relies on rate limits for the app.

**Booking rules live on the server.** The app never decides availability or price: it asks `/units/{id}/quote` and shows
the answer, including the server's message and alternative times when a slot is taken.

**Push.** Every in-app notification is also pushed (see the API's `notifications/push.py`). The push's `data.link` is a
website path; `appRouteFor()` opens the matching screen, or the website for host/admin pages.

## Before a Play Store release

- Bump `version:` in `pubspec.yaml` (`0.1.0+1` -> `0.1.1+2`: the number after `+` must always go up).
- Signing key: create an upload keystore, keep it and its passwords **out of git** (see `.gitignore`), and back it up.
- Play Console: privacy policy URL `https://nearbnb.com/legal/privacy`; account deletion URL `https://nearbnb.com/delete-account`
  (deleting is also in the app: Profile, Delete account).
- Data safety form: the app collects name, email, phone, date of birth, profile links, booking and payment history
  (card details go straight to Stripe), and a push token. Data is encrypted in transit; users can delete their account.
- Release through **internal testing** first.
