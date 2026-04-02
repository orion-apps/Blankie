# GAP-06 Library/Download Parity Checklist (SereneScapes → Blankie)

_Last updated: 2026-02-24_

## Goal
Reach practical parity for library/download workflows: discovery, download state visibility, recovery, and playback usability for server-origin (remote) content.

## A) Catalog + discovery
- [x] Library screen exists and is reachable from Home
- [x] Catalog status (source + counts)
- [x] Manual refresh flow with loading indicator
- [x] Search across bundled/remote items
- [x] Filter remote list (all/downloaded/not-downloaded)
- [x] Sorting favors downloaded-first for quick access

## B) Download lifecycle UX
- [x] State model: not-downloaded / queued / downloading / completed / failed
- [x] Row-level progress UI
- [x] Retry action for failed downloads
- [x] Cancel/remove actions
- [x] Persisted state across relaunch
- [x] Interrupted download recovery on app start

## C) Backend behavior
- [x] Real network download path (URLSession)
- [x] Local file persistence to app documents storage
- [x] Reconcile status against actual local file presence
- [x] Background URLSession pipeline configured
- [x] App-level background session event wiring
- [ ] Full end-to-end background completion QA on physical device (pending manual validation)

## D) Playback + blend integration
- [x] Play/stop for downloaded remote items from Library
- [x] Play/stop for downloaded remote items from Mixer
- [x] Include remote tracks in blend state
- [x] Save/apply remote selection in presets
- [x] Per-remote volume/pan controls in Mixer
- [x] Multi-remote blend UX polish (counts, clear selection, blend card summaries)

## E) Remaining parity gaps (targeted)
1. Device QA pass for true background transfer wake/resume behavior
2. Deeper remote metadata presentation polish (artwork/duration/category when available)
3. Optional hardening: checksum/size validation after download

## Merge-readiness recommendation
- **Engineering readiness:** High (feature-complete for app-level usage)
- **QA readiness:** Needs one focused device pass for background transfer behavior
- **Recommended next action:** Run QA script in Xcode + on-device, then merge PR #2
