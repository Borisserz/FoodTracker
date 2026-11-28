# App Store Review Notes — FoodTracker

Paste into App Store Connect → App Review Information → Notes.

---

## How to review

1. Launch the app and tap **Continue as Guest** on the Welcome screen (confirming in the guest confirmation sheet — no demo account required).
2. Complete the 5-step onboarding (**Welcome → Body → Goal → Tools → Plan**). Activity selection on the Goal step is required.
3. After onboarding, the optional in-app Spotlight tour can be skipped with **Skip**.
4. Core flows work offline for local meal/water logging. **Internet is required** for AI (Coach, Chef, plate/menu/cooking/before-after analysis), food search proxies, and account linking.

## Sign-in

- Optional: **Sign in with Apple** or **Continue with Google**.
- Guest mode uses Firebase Anonymous Auth for API access; meal and health logs stay on-device / iCloud.

## AI features (Guideline 5.1.2)

- AI photo / chat features show an explicit consent sheet before any upload, disclosing data sent, named partner AI providers, and a link to the Privacy Policy.
- Consent can be revoked anytime in **AI Coach tab → Profile & Settings → Settings (gear) → AI Data & Photo Privacy**.
- Backend: Firebase Cloud Functions proxy → OpenRouter (`data_collection: deny`, provider training/data collection disabled) → named partner AI models (Google and Recursive), with automatic fallback to Google Cloud Vertex AI (Gemini) when free vision pools are rate-limited.
- **Apple Health (HealthKit) data is never sent to AI.**

## Account deletion

**AI Coach tab → Profile & Settings → Settings (gear) → Account → Delete Account**.

## HealthKit & iCloud Background Sync

Optional. Used only on-device when the user enables Apple Health sync:
- **Read:** Body Mass, Step Count, Active Energy Burned, and Workouts.
- **Write:** Dietary Energy Consumed, Dietary Water, Active Energy Burned, Body Mass, and Workouts.
- **Apple Health (HealthKit) data is never sent to third-party AI services** or used for advertising/marketing.
- `UIBackgroundModes` includes `remote-notification` solely for silent SwiftData private iCloud (`CloudKit`) database change notifications (no marketing push notifications).

## Optional Companion App (WorkoutTracker)

FoodTracker supports optional local ecosystem sync with our companion app **WorkoutTracker** (`workouttracker://` URL scheme and shared App Group `group.com.borisdev.WorkoutTracker`). If WorkoutTracker is also installed on the same device, daily workout calorie totals and pure water intake can be synced locally on-device. FoodTracker works completely independently without WorkoutTracker installed.

## Monetization

The app is **100% free**. There are no In-App Purchases or subscriptions in this build.

## Legal

- Privacy: https://borisserz.github.io/workouttracker-privacy/Privacy%20Policy%20-%20FoodTracker.html
- Terms: https://borisserz.github.io/workouttracker-privacy/Terms%20of%20Use%20-%20FoodTracker.html
- Support: https://borisserz.github.io/workouttracker-privacy/Support%20-%20FoodTracker.html

Also linked in-app from Profile.
