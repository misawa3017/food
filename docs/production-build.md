# Production build guide

Firebase environments are selected explicitly at compile time:

- `dev` → `food-9a095`
- `prod` → `food-prod-9a095`

## Local development

```powershell
flutter run --flavor dev --dart-define=FIREBASE_ENV=dev
```

To use the local Firebase Emulator Suite, also include
`--dart-define=USE_FIREBASE_EMULATORS=true`.

## Production Android build

```powershell
flutter build appbundle --flavor prod --release --dart-define=FIREBASE_ENV=prod
```

The resulting AAB is at `build/app/outputs/bundle/prodRelease/`. Do not use a
bundle without both `--flavor prod` and `FIREBASE_ENV=prod` for a release.

## Production web build

After creating the production reCAPTCHA Enterprise key in Firebase App Check:

```powershell
flutter build web --release `
  --dart-define=FIREBASE_ENV=prod `
  --dart-define=ADSENSE_PUBLISHER_ID=ca-pub-xxxxxxxxxxxxxxxx `
  --dart-define=FIREBASE_APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY=<site-key>
```

The release web build stops at startup if the App Check site key is omitted.
The AdSense publisher ID is optional; when omitted, no AdSense script is loaded.

## Before enabling Google sign-in in production

1. Enable Google in the production Firebase Authentication providers.
2. Add the release SHA-1 and SHA-256 fingerprints to the production Android app.
3. Download the refreshed `google-services.json` from the production Android
   Firebase app and replace `android/app/src/prod/google-services.json`.
4. Build and test the prod flavor on a physical Android device.

The two Android flavors deliberately use the same application ID, so installing
one replaces the other on a device. This prevents a development build and a
production build from accidentally sharing local app state.

For Play Console registration, internal testing, and Play App Signing
fingerprints, see [Android Play Console internal testing](android-play-console-internal-testing.md).
