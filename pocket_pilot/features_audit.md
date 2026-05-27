# Pocket Pilot — Full Audit Report
## Part 1: Features Audit
> Comparing claimed features vs. what actually exists in the codebase
> Comparing claimed features vs. what actually exists in the codebase

---

## Legend
| Status | Meaning |
|---|---|
| ✅ Implemented | File exists and code is active |
| ⚠️ Partial | File exists but code is **commented out** or incomplete |
| ❌ Missing | File/class does not exist anywhere in the project |

---

## 1. Authentication & Security

| Claimed Feature | File | Status | Notes |
|---|---|---|---|
| Login / Signup / Logout | `login_view.dart`, `signup_view.dart`, `auth_service.dart`, `token_service.dart` | ✅ Implemented | Active code confirmed |
| OTP Email Verification (`OTPVerificationPage`) | — | ❌ Missing | No file or class named `OTPVerificationPage` found anywhere |
| Forgot Password (`ForgotPasswordPage`) | — | ❌ Missing | No file or class found |
| Reset Password (`ResetPasswordPage`) | — | ❌ Missing | No file or class found |
| Biometric Login | `biometric_service.dart` | ⚠️ Partial | Service file exists but NOT listed in the feature description and not wired to any view |

> **Summary:** Only basic login/signup is live. OTP, Forgot Password, and Reset Password screens **do not exist** in the frontend.

---

## 2. Dashboard & Reports

| Claimed Feature | File | Status | Notes |
|---|---|---|---|
| Home Dashboard | `home_body.dart`, `home_page.dart`, `home_service.dart` | ✅ Implemented | Fully active |
| Stats & Reports | `stats_page.dart` | ✅ Implemented | Fully active |

> **Summary:** ✅ Both features fully match.

---

## 3. Income Management

| Claimed Feature | File | Status | Notes |
|---|---|---|---|
| Initial Income Setup (MoneyInfoView) | `money_info_view.dart` | ✅ Implemented | Active |
| Income Screen (list) | `income_screen.dart` | ❌ Commented Out | Entire file is `// commented out` — not functional |
| Add Income | `add_income_body.dart`, `income_service.dart` | ✅ Implemented | Active |

> **Summary:** `IncomeScreen` (the list view for browsing past incomes) is completely commented out and non-functional.

---

## 4. Expenses & Subscriptions

| Claimed Feature | File | Status | Notes |
|---|---|---|---|
| Fixed Expenses | `fixed_expense_page.dart`, `fixed_expenses_service.dart` | ✅ Implemented | Active |
| Variable Expenses | `expenses_screen.dart` (→ `add_body.dart`), `variable_expenses_service.dart` | ✅ Implemented | Active |
| Subscription Tracking (`subscriptions_page`, `subscription_service`) | `subscription_radar_view.dart` | ⚠️ Partial | **The view exists** as `SubscriptionRadarView`, but the feature description uses wrong filenames (`subscriptions_page.dart`, `subscription_service.dart` — neither exists). No dedicated `subscription_service.dart` found. |

> **Summary:** Subscriptions screen exists but under a different name. No standalone `subscription_service.dart`.

---

## 5. AI Features

| Claimed Feature | File | Status | Notes |
|---|---|---|---|
| AI Pilot Chat | `ai_pilot_page.dart`, `gemini_chat_service.dart` | ✅ Implemented | Active |
| AI Receipt Scanner | `receipt_scanner_view.dart`, `receipt_ai_service.dart`, `gemini_receipt_service.dart`, `receipt_parser.dart`, `receipt_ocr_service.dart` | ✅ Implemented | Active |
| Receipt Confirmation Page (`receipt_confirmation_page`) | — | ❌ Missing | The description names `receipt_confirmation_page.dart` — this file **does not exist**. The scanner goes directly into `receipt_scanner_view.dart`. |

> **Summary:** Both AI features work, but the description uses a wrong filename for the confirmation page.

---

## 6. Goals & Collaboration

| Claimed Feature | File | Status | Notes |
|---|---|---|---|
| Personal Saving Goals | `goals_page.dart`, `add_goal_page.dart` | ✅ Implemented | Active |
| Shared Goals (`shared_goals_page`, `SharedGoalsPage`) | — | ❌ Missing | No file, class, or service for shared goals exists anywhere in the project |

> **Summary:** Personal goals work. Shared Goals feature **does not exist**.

---

## 7. Gamification & Streaks

| Claimed Feature | File | Status | Notes |
|---|---|---|---|
| Points, Levels, Streaks, Badges (`gamification_screen`) | `gamification_view.dart`, `gamification_service.dart` | ⚠️ Partial | Feature works, but the description uses wrong filename (`gamification_screen.dart`). Actual file is `gamification_view.dart`. |

> **Summary:** Feature exists but under a different filename than claimed.

---

## 8. Bank SMS Integration

| Claimed Feature | File | Status | Notes |
|---|---|---|---|
| Auto-parse bank SMS messages | `bank_sms_service.dart` | ✅ Implemented | Service file is active |

> **Summary:** ✅ Matches (service layer exists).

---

## 9. Geofencing Reminders

| Claimed Feature | File | Status | Notes |
|---|---|---|---|
| Location-based reminders (`geo_reminders_settings_page`, `geo_reminder_service`) | `geospatial_view.dart`, `geospatial_service.dart` | ⚠️ Partial | Feature works, but under different names than claimed. Description says `geo_reminders_settings_page.dart` and `geo_reminder_service.dart` — actual files are `geospatial_view.dart` and `geospatial_service.dart`. |

> **Summary:** Feature exists under different filenames.

---

## 10. Financial Forecasting

| Claimed Feature | File | Status | Notes |
|---|---|---|---|
| Future balance forecasting (`forecast_screen`) | `time_travel_page.dart` | ⚠️ Partial | Feature exists but under a completely different name (`TimeTravelPage`). Description says `forecast_screen.dart` — this file does not exist. |

> **Summary:** Feature exists under the name `TimeTravelPage`, not `forecast_screen`.

---

## 11. Theme Customization (Dark/Light Mode)

| Claimed Feature | File | Status | Notes |
|---|---|---|---|
| Dark/Light Mode (`ThemeService`) | — | ❌ Missing | No `ThemeService`, no `theme_service.dart`, and `main.dart` has no `ThemeMode` or dynamic theming at all. |

> **Summary:** Dark mode **does not exist** in the current codebase.

---

## Overall Summary Table

| # | Feature | Status |
|---|---|---|
| 1a | Login / Signup / Logout | ✅ |
| 1b | OTP Verification | ❌ Missing |
| 1c | Forgot Password | ❌ Missing |
| 1d | Reset Password | ❌ Missing |
| 2 | Dashboard & Stats | ✅ |
| 3a | MoneyInfoView (initial income) | ✅ |
| 3b | Income Screen (list) | ⚠️ Commented Out |
| 3c | Add Income | ✅ |
| 4a | Fixed Expenses | ✅ |
| 4b | Variable Expenses | ✅ |
| 4c | Subscription Tracking | ⚠️ Wrong filename in description |
| 5a | AI Pilot Chat | ✅ |
| 5b | AI Receipt Scanner | ✅ |
| 6a | Personal Goals | ✅ |
| 6b | **Shared Goals** | ❌ Missing |
| 7 | Gamification / Streaks | ⚠️ Wrong filename in description |
| 8 | Bank SMS Integration | ✅ |
| 9 | Geofencing Reminders | ⚠️ Wrong filename in description |
| 10 | Financial Forecasting | ⚠️ Wrong filename (TimeTravelPage) |
| 11 | **Dark/Light Theme** | ❌ Missing |

---

## Part 2: Security Features Audit

> Comparing 6 claimed security measures vs. what is actually in the code

---

### Security 1 — JWT Stored Securely (Token Management)

**Claimed:** Token is stored using `shared_preferences` (plain XML).

**Reality:** ✅ **Better than claimed** — code actually uses `flutter_secure_storage` with `AndroidOptions(encryptedSharedPreferences: true)`, which means Android Keystore / iOS Keychain — hardware-backed encryption. **NOT** plain `shared_preferences` as described.

| Sub-claim | Reality |
|---|---|
| `saveToken()` exists | ✅ Line 17 of `token_service.dart` |
| `clearToken()` on logout | ✅ Line 25 of `token_service.dart` — called in `splash_view.dart` on invalid token |
| Storage library used | ⚠️ Description says `shared_preferences` — code uses `flutter_secure_storage` (stronger, correct your docs!) |

---

### Security 2 — Auto Bearer Token in All Requests (ApiService)

**Claimed:** `ApiService` auto-attaches `Authorization: Bearer <token>` to every protected request.

**Reality:** ✅ **Matches** — confirmed in `api_service.dart` line 15:
```dart
if (token != null) "Authorization": "Bearer $token",
```

⚠️ **Gap found:** `ApiService` only implements a `POST` method. There is **no `GET`, `PUT`, or `DELETE`** method — meaning any screen that calls `http.get(...)` directly (like `login_view.dart` itself) **bypasses `ApiService` entirely** and manually attaches the token (or doesn't at all). The centralized protection is incomplete.

---

### Security 3 — Route Protection via SplashView

**Claimed:** SplashView checks token validity by calling user profile from server. Invalid/expired token → auto-cleared and redirected to login.

**Reality:** ✅ **Matches and is actually better:**
- Calls `UserService.getProfile()` on startup ✅
- Clears token if expired (`TokenService.clearToken()`) ✅
- Redirects to `LoginView` on failure ✅
- **Bonus (not mentioned in description):** Also runs `BiometricService.authenticate()` if biometric lock is enabled — an extra security layer ✅

---

### Security 4 — Password Obscuring (obscureText + Eye Toggle)

**Claimed:** All sensitive fields use `obscureText` with a show/hide eye icon toggle. Applies to login, signup, and reset password screens.

**Reality:**

| Screen | obscureText | Eye Toggle |
|---|---|---|
| `login_view.dart` | ✅ Line 294 | ✅ Lines 302–313 |
| `signup_view.dart` | ✅ Lines 160, 172 | ✅ Lines 161–164, 173–176 |
| Reset Password screen | ❌ Screen doesn't exist | ❌ N/A |

⚠️ **Gap:** Reset password screen is claimed but **the entire page does not exist** in the codebase, so the claim of protecting it with `obscureText` cannot be verified.

---

### Security 5 — Frontend Validation

**Claimed:** Email format check (`@`), password ≥ 6 chars (signup), password ≥ 8 chars (reset), confirm password match.

**Reality (from `signup_provider.dart`):**

| Validation Rule | Claimed | Actual |
|---|---|---|
| Email contains `@` | ✅ | ✅ Line 29 |
| Password ≥ 6 chars (signup) | ✅ | ✅ Line 31 |
| Password ≥ 8 chars (reset) | ✅ | ❌ Reset page doesn't exist |
| Passwords match | ✅ | ✅ Lines 33–34 and 55–59 |

**Login validation (`login_view.dart`):**
- ✅ Checks empty email
- ✅ Checks empty password
- ❌ Does **NOT** validate email format (`@` check) on the login screen — only on signup

⚠️ **Bonus feature not mentioned:** Login has a **rate-limiting lockout** — after `AppConfig.maxLoginAttempts` failed tries, the login button locks for `AppConfig.loginLockoutSeconds` seconds. This is a real security feature that was **not described** in your documentation.

---

### Security 6 — Permission Handling (permission_handler)

**Claimed:** SMS and GPS features request explicit user permission via `permission_handler`. If denied, app handles it safely without crashing.

**Reality:**

| Permission | Library Used | Request Before Access | Safe Denial Handling |
|---|---|---|---|
| SMS (`bank_sms_service.dart`) | ✅ `permission_handler` (line 2) | ✅ `Permission.sms.request()` (line 12) | ✅ Returns `false` / throws readable exception |
| Location (`geospatial_service.dart`) | ⚠️ Uses `geolocator` (not `permission_handler`) | ✅ `Geolocator.requestPermission()` (line 58) | ✅ Returns `null`/`false` on denial, no crash |

⚠️ **Small discrepancy:** Location permissions are handled via `geolocator`'s built-in permission API, not `permission_handler` as stated. Both are valid approaches but the description is inaccurate about the library used.

---

### Security Overall Summary

| # | Security Feature | Status | Key Finding |
|---|---|---|---|
| 1 | JWT Secure Storage | ✅ Implemented | Uses `flutter_secure_storage` (stronger than described — fix your docs) |
| 2 | Auto Bearer Token | ⚠️ Partial | Only `POST` is centralized — `GET` requests bypass `ApiService` |
| 3 | Route Protection (SplashView) | ✅ Implemented + Bonus | Also does biometric check (not documented) |
| 4 | Password obscureText | ✅ Implemented | Login & Signup ✅ — Reset Password screen doesn't exist |
| 5 | Frontend Validation | ⚠️ Partial | Email format not validated on login screen; rate-limiting lockout exists but undocumented |
| 6 | Permission Handling | ✅ Implemented | SMS uses `permission_handler`, GPS uses `geolocator` (both correct, small naming mismatch) |

### 🔴 Undocumented Security Features (In Code But Not Mentioned)
- **Brute-force lockout** on login after N failed attempts (`login_view.dart`)
- **Biometric authentication** gate at app startup (`biometric_service.dart` + `splash_view.dart`)
- **Hardware-backed encryption** for the JWT (Android Keystore / iOS Keychain)
