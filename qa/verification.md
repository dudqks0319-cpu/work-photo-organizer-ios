# iOS Verification

- Project: `/Users/jyb-m3max/Desktop/codex/work-photo-organizer-ios/WorkPhotoOrganizer.xcodeproj`
- Scheme: `WorkPhotoOrganizer`
- Simulator: `iPhone 17`, iOS 26.2, `4DA36EEC-BC72-4A36-A304-D9516AB1CCAB`
- Bundle ID: `com.codex.workphotoorganizer`

## RED Evidence

- `test_sim` initially failed because `WorkPhotoOrganizer` app module did not exist.
- After app files were added, `test_sim` failed at `AppIntentsSSUTraining` because processed `Info.plist` lacked required bundle keys.
- v0.2 RED: `test_sim` failed after adding candidate-classification tests because `assetLocalIdentifier`, `CaptureKind`, `ClassificationSource`, `WorkClassificationSettings`, and v1 migration APIs did not exist.
- v0.2.1 RED: `test_sim` failed after adding timezone/reclassification tests because `timeZoneIdentifier` and `reclassifyRecentRecords` did not exist.

## GREEN Evidence

- `test_sim`: passed 11/11 domain tests.
- Covered tests: multi-import validation, asset identifier dedupe, screenshot classification, work location candidate, timezone-aware work schedule, weekday/weekend selection, recent-record reclassification, confirmed-work preservation, export redaction, v1 migration, text sanitization.
- `build_run_sim`: succeeded, installed and launched on iPhone 17 simulator.
- Runtime UI snapshot: project summary counts, multi-photo picker, status filter, work candidate filter, capture kind filter, category filter, photo grid, inspector, settings button, and export button visible.
- Settings UI snapshot: company name, latitude, longitude, radius, location classification, weekday selector, timezone field, schedule classification, work mode, and Face ID/passcode lock controls visible.
- Screenshot: `/var/folders/dx/2zprs00s3050gd97w54748700000gn/T/screenshot_optimized_d03ddb9c-7c43-40a2-a016-e63c66f59f87.jpg`
- GitHub Actions CI: `.github/workflows/ios.yml` added for push and pull_request; it runs `xcodegen generate` and `xcodebuild test` against an available iPhone simulator on macOS.

## App Intents

- `OpenPhotoOrganizerIntent`: opens the app to all/review/done/upload destinations.
- `ShowReviewPhotosIntent`: opens the app filtered to review photos.
- `OpenWorkCandidatesIntent`: opens the app filtered to work candidates.
- `SetWorkModeIntent`: writes local work-mode state, updates the running app store through `AppIntentRouter.workModeOverride`, and opens work candidates.
- `ReclassifyRecentPhotosIntent`: reclassifies already registered photos from the last 7 days with current settings and opens work candidates. It does not scan the full Photos library.
- `WorkPhotoOrganizerShortcuts`: exposes Shortcuts phrases for organizer, review photos, work candidates, work mode, and reclassification.

## Real iPhone QA Checklist

- [ ] 실제 iPhone에서 사진 30장 다중 선택
- [ ] 실제 스크린샷이 스크린샷으로 분류되는지 확인
- [ ] 위치 정보가 있는 사진이 회사 반경 안이면 후보로 들어가는지 확인
- [ ] 위치 정보가 없는 사진이 업무시간 기준으로 후보 처리되는지 확인
- [ ] 한국 시간 기준 업무시간 분류가 정확한지 확인
- [ ] 업무 모드 켠 뒤 새 사진 추가 시 후보로 들어가는지 확인
- [ ] Face ID 실패/성공 플로우 확인
- [ ] JSON export에 `assetLocalIdentifier`, 좌표, base64, blob, local path 미포함 확인

## Security Gate

- Secrets: PASS. No API keys or secrets added.
- AuthN/AuthZ: N/A. Local-only iOS app with no backend or accounts.
- Input validation: PASS. Domain accepts only JPEG, PNG, WebP under 20MB.
- Output encoding: PASS. Stored text strips markup metacharacters.
- Dependencies: PASS. No package dependencies added; XcodeGen is a local project generation tool.
- Sensitive data minimization: PASS. Export payload excludes preview/raw photo data, `assetLocalIdentifier`, location coordinates, base64, blob, and local file paths; original picked images are memory-only.
- Abuse controls: N/A. No network, auth session, CSRF, replay, or server endpoint.
- Negative-path tests: PASS. Unsupported/oversized images, duplicate asset IDs, export redaction, timezone boundary, weekday exclusion, confirmed-work preservation, and markup metacharacter stripping covered.
- Residual risk: Real-device PhotosPicker import with a real library, PHAsset screenshot subtype, real location metadata, and Face ID/passcode prompt behavior were not exercised on physical iPhone. Owner: user/product. Due: before TestFlight or production use.
