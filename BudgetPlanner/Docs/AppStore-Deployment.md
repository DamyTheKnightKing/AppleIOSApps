# App Store Deployment Guide (BudgetPlanner)

Use this flow in order:
1. Install on your own iPhone (developer build)
2. Share to testers via TestFlight
3. Submit for public App Store release

## 0) One-time prerequisites
- Full Xcode installed and signed into your Apple ID.
- Apple Developer Program membership active.
- Unique bundle identifier (do not use `com.yourname.budgetplanner`).

## 1) Generate and open project
From project root:
```bash
cd BudgetPlanner
xcodegen generate
open BudgetPlanner.xcodeproj
```

## 2) Configure signing and identity
In Xcode:
1. Select target `BudgetPlanner`.
2. Open `Signing & Capabilities`.
3. Set `Team` to your developer team.
4. Ensure `Automatically manage signing` is enabled.
5. Set unique bundle id (example: `com.<yourcompany>.budgetplanner`).
6. Keep `Bundle Identifier` in App Store Connect exactly the same.

Current defaults are in `project.yml`:
- App bundle id: `PRODUCT_BUNDLE_IDENTIFIER`
- Test bundle id: `com.yourname.budgetplanner.tests`

## 3) Test on your own iPhone (direct install)
1. Connect iPhone to Mac.
2. Select your iPhone as run destination in Xcode.
3. Press Run.
4. If prompted on device:
- trust computer
- enable Developer Mode
- relaunch app

This gives you immediate install for internal validation before TestFlight.

## 4) Create App Store Connect record
In App Store Connect:
1. Apps -> `+` -> New App
2. Fill:
- Name: `Budget Planner`
- Primary language
- Bundle ID (must match Xcode target exactly)
- SKU (any unique internal id, e.g. `budgetplanner-ios-001`)

## 5) Archive and upload build
In Xcode:
1. Select destination: `Any iOS Device (arm64)`.
2. `Product -> Archive`.
3. Organizer opens -> select archive -> `Distribute App`.
4. Choose `App Store Connect` -> `Upload`.
5. Complete upload flow (automatic signing/rebuild if asked).

## 6) TestFlight distribution
After processing in App Store Connect:
1. Open your app -> `TestFlight`.
2. Internal testing:
- Add internal testers (fastest).
3. External testing:
- Add external group, complete beta app info.
- First external build requires Beta App Review.
4. Share TestFlight invite link/email.

Testers install via Apple TestFlight app from App Store.

## 7) Public App Store release
In App Store Connect -> App Store tab:
1. Fill listing metadata (name, subtitle, description, keywords).
2. Upload required screenshots.
3. Set App Privacy answers.
4. Add support URL and privacy policy URL.
5. Select the uploaded build.
6. `Submit for Review`.

After approval:
- release manually, or
- set automatic release.

## 8) Versioning rules before each upload
In Xcode target (`General`):
- `Version` (marketing version): e.g. `1.0.1`
- `Build` (build number): must increase every upload (e.g. `2`, `3`, `4`)

## 9) Notes specific to this app
- Local reminders use local notifications only (no push server required).
- iCloud sync feature requires iCloud capability enabled if you want production cross-device sync.
- App Store upload policy changes over time; verify latest requirements before final submission.
