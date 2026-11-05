# Moments

A private iOS timeline manager: keep any number of timelines of photos, videos, notes and voice memos. Any entry can be marked as a milestone (a birth, a move, a first day), and a milestones view shows the time between them. Entries can keep where they happened: the current place when location access is allowed, the photo's own place for imports, or one searched for.

## Setup
1. `brew install xcodegen`
2. From the repo root, run `xcodegen`
3. For a device: set `DEVELOPMENT_TEAM` and your own bundle ID in `project.yml` (iCloud sync needs a paid Apple Developer Program team), run `xcodegen` again, then open `Moments.xcodeproj` and run (the camera needs real hardware).
4. Website: `docs/` is the app's site (plain HTML, no build): a home page with support and the tip link, and `privacy.html`. Replace `support@example.com` and the Ko-fi address, publish the folder (GitHub Pages can serve `docs/` from `main`), then set `RootView.website` to its address to show "About Moments" in the title menu (it opens the site in an in-app Safari view). In App Store Connect, use the site as the support URL and `privacy.html` as the privacy policy URL.

## Tests
`bundle exec fastlane test` (or `xcodebuild … -scheme Moments test` on a simulator) runs the unit tests in `MomentsTests`.

## TestFlight
`bundle exec fastlane beta` (from the repo root, after `bundle install` once: fastlane is pinned in `Gemfile.lock` and installed into `vendor/bundle`) generates the project, builds with the build number one past the latest on TestFlight, and uploads. It signs automatically with an App Store Connect API key, so no Xcode sign-in is needed:
1. In App Store Connect, create the app record for `it.vincendep.moments` (once).
2. Users and Access → Integrations → App Store Connect API: create a key with the Admin role (needed to create the distribution certificate) and download the `.p8`.
3. Create `fastlane/.env` (git-ignored):
   ```
   ASC_KEY_ID=ABC123DEFG
   ASC_ISSUER_ID=00000000-0000-0000-0000-000000000000
   ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_ABC123DEFG.p8
   ```
Optionally pass the testers' notes: `CHANGELOG="New tabs" bundle exec fastlane beta` (then it waits for processing to set them). The version shown to testers is `MARKETING_VERSION` in `project.yml`. If the build succeeded but the upload failed, `bundle exec fastlane beta skip_build:true` uploads `build/Moments.ipa` again without rebuilding.

## Design
- Timelines, entries and voice memos sync through the user's private iCloud (SwiftData + CloudKit), so changing phone loses nothing. No account needed.
- Photos and videos are saved to Photos. The app stores only the asset IDs (including the iCloud Photos ID, so links work on a new phone), so nothing is duplicated.
- Each timeline's settings pick the album its new media goes into: its own album (renamed with the timeline), a shared "Moments" album, or none. Gallery imports can optionally be added to that album too.

## Next steps
- Merge a timeline from another person (export/import; entries already carry a stable ID and last-modified date).
- Handle assets deleted in Photos (`PHPhotoLibraryChangeObserver`).
- Scrapbook / yearly PDF export.
