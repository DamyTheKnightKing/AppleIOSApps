# BudgetPlanner iOS App (V1.1)

A SwiftUI iOS app to:
- track expenses by category,
- set monthly category budgets,
- view spending insights,
- identify where to save more.

## Features
- Home dashboard with monthly spend, savings estimate, and category progress.
- Add expense screen with date/category/note.
- Insights screen with spending chart and savings opportunities.
- Advanced analytics: 6-month trend, month-over-month comparison, category change, next-month forecast.
- Settings screen to edit income and per-category budgets.
- Recurring expenses (weekly/monthly auto-entry).
- Daily local reminder notification.
- iCloud key-value sync toggle (same Apple ID devices).
- Export current-month report as CSV or PDF and share.
- Local JSON persistence in app documents directory.

## Project setup
This repo uses `xcodegen` to generate an Xcode project.

1. Install tools on macOS:
```bash
brew install xcodegen
```
2. Generate project:
```bash
cd BudgetPlanner
xcodegen generate
```
3. Open in Xcode:
```bash
open BudgetPlanner.xcodeproj
```
4. Pick an iOS Simulator and run.

## Deploy to App Store (TestFlight -> Public)
See [Docs/AppStore-Deployment.md](Docs/AppStore-Deployment.md).
Use [Docs/Release-Checklist.md](Docs/Release-Checklist.md) during each release.

## Notes
- Bundle identifier is currently `com.yourname.budgetplanner` in `project.yml`. Replace with your own unique identifier.
- iOS deployment target is `17.0`.
- For iCloud sync in production, enable iCloud capability in Xcode for your app target.
