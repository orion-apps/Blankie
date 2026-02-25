# SereneScapes → Blankie Gap Matrix

_Last updated: 2026-02-25_

## Legend
- ✅ Done
- 🟡 Partial
- ❌ Missing
- 🚧 In Progress

| GAP | Area | Status | Notes |
|-----|------|--------|-------|
| GAP-01 | Image packs in player | ✅ Done | Player image-pack foundation added |
| GAP-02 | Ken Burns in player | ✅ Done | Slideshow + animation tuning complete |
| GAP-03 | Manifest/content model | ✅ Done | Retry/backoff, timeout, cache-policy tuning |
| GAP-04 | Built-in fallback mode | ✅ Done | Mode/state surfaced across Home, Player, Mixer, Settings |
| GAP-05 | Mixer/blends workflow | ✅ Done | Full blend workflow, pan/mute/solo, autosave, blend player |
| GAP-06 | Library/download UX | ✅ Done | Download lifecycle, background URLSession, remote playback |

## Additional Work Completed
- ✅ VoiceOver accessibility (PlayerView, NowPlayingBar, SoundCard, MixerView, SleepTimerSheet, LibraryView)
- ✅ AudioManager deadlock crash fix
- ✅ Sleep timer (MVP + polish + tests)

## Remaining Items

### QA Pass (Device)
- [ ] Ken Burns animation feel on physical device
- [ ] Background transfer wake/resume behavior
- [ ] Blend workflow click-path validation
- [ ] Sound loops edge-case parity checks

### Optional Hardening
- [ ] Checksum/size validation after download
- [ ] Deeper remote metadata (artwork/duration/category when available)

## Merge Readiness
- **Branch:** `migration-gap-01-player-images` (37 commits ahead of main)
- **Tests:** 33/33 passing
- **Recommendation:** Ready for PR #2 merge after device QA pass
