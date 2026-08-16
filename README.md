# DENA Portal

A Flutter dealer portal integrated with a DENA Supabase backend.

## What this project includes

- login flow using Supabase auth when configured
- dealer profile validation against `dealer_profiles`
- product journey rows from `product_journey`
- approval queue and decisions in `approval_decisions`
- fallback demo mode for local development when credentials are not set

## Required environment variables

The configured DENA project URL is:

```bash
export DENA_SUPABASE_URL="https://mjcscqrwlvjzptxnyhsl.supabase.co"
```

The anon key is stored locally in the ignored `dart_defines.json` file.

The app also supports the standard names for compatibility:

```bash
export SUPABASE_URL="https://mjcscqrwlvjzptxnyhsl.supabase.co"
# Use the same anon key as dart_defines.json when setting this alias.
export SUPABASE_ANON_KEY="<DENA anon key>"
```

## Supabase migration

Run the SQL in [supabase_schema.sql](supabase_schema.sql) in the Supabase SQL editor.

This creates the following tables:

- `dealer_profiles`
- `portal_roles`
- `product_journey`
- `approval_decisions`
- `portal_notifications`
- `web_mobile_pairings`

It also creates indexes, seeded role definitions, RLS policies, and
`updated_at` triggers. Run the migration before using the configured
administrator role editor. Role assignments are stored in `dealer_profiles`,
while predefined role names and permissions are stored in the protected
`portal_roles` table.

The `Notify` action creates one protected `portal_notifications` row for each
profile assigned to the product journey's actor or role. Recipients can read
only their own notifications; portal administrators can inspect all
notification records.

For push delivery to `mobdlrprtl`, deploy
`supabase/functions/send-journey-notification` and configure its
`FCM_SERVICE_ACCOUNT_JSON` secret with the Firebase service-account JSON. The
mobile app must register its Firebase Cloud Messaging token in
`mobile_device_tokens` under its authenticated profile email.

The login QR uses the `idigi://pair/<pairing-id>` payload and a five-minute
five-digit challenge. Deploy `supabase/functions/claim-web-pairing` for the
mobile app to submit the authenticated user's code; the web app polls the
pairing row and opens the portal with the approved registered profile.

## Deep Link Integration

The app integrates with native deep link handlers on Android and iOS:

- **Android**: Listens via `MainActivity.kt` for `idigi` and `eu.fivea.idigi` schemes
- **iOS**: Listens via `SceneDelegate.swift` and `AppDelegate.swift` for `idigi` and `eu.fivea.idigi` schemes
- **Flutter**: `DeepLinkService` provides a centralized Dart API for handling deep links

Supported deep link formats:
- `idigi://pair/<pairing-id>` - Initiates mobile-to-web pairing
- `eu.fivea.idigi://pair/<pairing-id>` - Alternative scheme for the same functionality

## Administrator authentication

Create `otjeh@fivea.eu` as a user in Supabase Authentication with its password,
then run [supabase_schema.sql](supabase_schema.sql). The SQL seeds the matching
`Portal Administrator` profile. The app signs the administrator in through
Supabase Auth; the database `is_portal_admin()` function and RLS policies enforce
the role for staff-directory writes.

To enable administrator password changes, deploy the Edge Function in
`supabase/functions/admin-update-user-password`. It verifies the caller's
`Portal Administrator` profile and uses the Supabase service role only on the
server to update the selected Auth user. Never put the service role key in the
Flutter app.

When running without Supabase configuration, demo mode accepts
`otjeh@fivea.eu` with password `password123`. This credential is local demo data
only and is not used when Supabase is configured.

Do not put a production administrator password in `dart_defines.json`, source
code, or client configuration. Production password validation belongs to
Supabase Auth.

## Run locally

```bash
flutter pub get
flutter run --dart-define-from-file=dart_defines.json
```

The local `dart_defines.json` file contains the DENA project values and is
ignored by Git. Do not commit it or share it publicly.

## Notes

- The app starts in demo mode if the DENA Supabase environment variables are not configured.
- Once configured, the app will authenticate against Supabase and read/write the DENA backend records.
# webdrlprtl
