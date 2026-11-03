# Moments

A private iOS timeline manager: keep any number of timelines of photos, videos, notes and voice memos. Any entry can be marked as a milestone (a birth, a move, a first day), and a milestones view shows the time between them. Entries can keep where they happened: the current place when location access is allowed, the photo's own place for imports, or one searched for.

## Setup
1. `brew install xcodegen`
2. From the repo root, run `xcodegen`
3. For a device: set `DEVELOPMENT_TEAM` and your own bundle ID in `project.yml` (iCloud sync needs a paid Apple Developer Program team), run `xcodegen` again, then open `Moments.xcodeproj` and run (the camera needs real hardware).
4. Website: `docs/` is the app's site (plain HTML, no build): a home page with support and the tip link, and `privacy.html`. Replace `support@example.com` and the Ko-fi address, publish the folder (GitHub Pages can serve `docs/` from `main`), then set `RootView.website` to its address to show a "Moments Website" link in the title menu. In App Store Connect, use the site as the support URL and `privacy.html` as the privacy policy URL.

## Design
- Timelines, entries and voice memos sync through the user's private iCloud (SwiftData + CloudKit), so changing phone loses nothing. No account needed.
- Photos and videos are saved to Photos. The app stores only the asset IDs (including the iCloud Photos ID, so links work on a new phone), so nothing is duplicated.
- Each timeline's settings pick the album its new media goes into: its own album (renamed with the timeline), a shared "Moments" album, or none. Gallery imports can optionally be added to that album too.

## Next steps
- Merge a timeline from another person (export/import; entries already carry a stable ID and last-modified date).
- Handle assets deleted in Photos (`PHPhotoLibraryChangeObserver`).
- Scrapbook / yearly PDF export.
