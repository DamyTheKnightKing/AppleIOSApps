# Release Checklist (Device + TestFlight + App Store)

## A) Device install checklist (your iPhone)
- [ ] Connect iPhone to Mac
- [ ] Open `BudgetPlanner.xcodeproj`
- [ ] Set `Team` in Signing
- [ ] Set unique app bundle id
- [ ] Select physical iPhone destination
- [ ] Run app from Xcode
- [ ] Confirm app opens (no white screen)
- [ ] Add sample expenses and verify insights load

## B) TestFlight checklist (other users)
- [ ] App record exists in App Store Connect
- [ ] Version/build updated in Xcode
- [ ] Archive created from `Any iOS Device (arm64)`
- [ ] Build uploaded to App Store Connect
- [ ] Build processing completed
- [ ] Internal testers added
- [ ] External testing info completed (if needed)
- [ ] Invite link shared with testers

## C) App Store submission checklist
- [ ] Subtitle, description, keywords filled
- [ ] Screenshots uploaded for required devices
- [ ] App privacy answers completed
- [ ] Support URL added
- [ ] Privacy policy URL added
- [ ] Build selected under App Store version
- [ ] Submit for review

## D) Regression test checklist before every release
- [ ] Add custom category (e.g. Internet/Phone/Hotel/Flight Ticket)
- [ ] Add expense in custom category
- [ ] Verify Dashboard totals update
- [ ] Verify Insights `Monthly Suggestions` renders
- [ ] Verify CSV export works
- [ ] Verify PDF export works
- [ ] Verify recurring expense still auto-adds correctly

## E) Useful commands
```bash
cd BudgetPlanner
xcodegen generate
xcodebuild -project BudgetPlanner.xcodeproj -scheme BudgetPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```
