# Bodify UI

Flutter app for Bodify. The screens are a clone of the
`fitness_workout_app_flutter_3_ui` kit (UI only - none of its mock logic was
carried over); the auth flow is wired to the Bodify FastAPI backend.

## Setup

```bash
flutter pub get
```

## Running against the backend

Start the backend so it listens on all interfaces, otherwise a phone or the
Android emulator cannot reach it:

```bash
# in D:\BodifyBackend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Then run the app:

| Target | Command |
| --- | --- |
| Android emulator | `flutter run` (uses `http://10.0.2.2:8000`) |
| iOS simulator / desktop | `flutter run` (uses `http://127.0.0.1:8000`) |
| Real device | `flutter run --dart-define=API_BASE_URL=http://<your-lan-ip>:8000` |

The base URL logic lives in `lib/core/api_config.dart`.

## Auth flow

| Screen | Endpoint |
| --- | --- |
| `view/login/signup_view.dart` | `POST /api/v1/auth/register` |
| `view/login/login_view.dart` | `POST /api/v1/auth/login` |
| app start (`main.dart` → `AuthGate`) | `GET /api/v1/auth/me`, `POST /api/v1/auth/refresh` |
| `view/profile/profile_view.dart` → Logout | clears the stored session |

Accounts live in Supabase Auth; this app only ever holds the tokens the backend
returns.

### Structure

```
lib/
  core/       api base URL + error parsing
  models/     auth_models.dart - mirrors the backend's response schemas
  services/   auth_service.dart (API calls), token_storage.dart (persistence)
  common/, common_widget/, view/   the UI kit
```

## Known gaps

- Tokens are kept in `SharedPreferences`, which is not encrypted. Move to
  `flutter_secure_storage` before shipping real accounts.
- "Complete Profile" and "What is your goal" are still UI-only - there is no
  backend endpoint for them yet, so the values are not saved.
- Google / Facebook buttons are decorative; only email + password is wired.
- Android `applicationId` is still `com.codeforany.fitness` from the source kit.
