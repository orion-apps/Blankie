# GAP-05 Mixer/Blend Parity Checklist (SereneScapes → Blankie)

_Last updated: 2026-02-24_

## Goal
Validate Blankie mixer/blend behavior against SereneScapes expectations and close practical parity gaps in controlled slices.

## Checklist

### A) Blend lifecycle
- [x] Create a new blend from current state
- [x] Save-as flow from mixer
- [x] Apply saved blend
- [x] Delete saved blend
- [x] Reset/start new blend workflow
- [x] Update active blend from current mixer state
- [x] Unique name handling for duplicate preset names

### B) Track controls
- [ ] Add/remove tracks dynamically
- [x] Per-track volume control
- [x] Per-track pan control parity (SereneScapes has explicit pan UX)
- [x] Solo/mute semantics parity (single/multi-solo modes + clear solo)
- [ ] Per-track play/pause parity

### C) Playback/session behavior
- [x] Master volume control
- [x] Sleep timer accessible in mixer flow
- [ ] Blend playback from blend cards / dedicated blend player parity
- [ ] Autosave semantics parity while editing loaded blend

### D) Persistence and resilience
- [x] Basic preset persistence
- [ ] Bundled vs user blend distinction parity
- [ ] Edit blend metadata/name in mixer context parity
- [ ] Defensive handling for missing/deleted sounds in saved blend

### E) UX parity
- [x] Content source status visible in mixer
- [ ] Studio-like dedicated mixer workspace (tabs/layout) parity
- [ ] Error/success messaging parity for blend operations

## This Slice (completed now)
- Added explicit blend workflow controls in Blankie mixer:
  - New Blend (reset to default)
  - Update Current Blend
- Added unique preset naming logic in PresetManager
- Added tests for unique naming + overwrite-current behavior
- Enabled Sleep Timer entry in Mixer (removed placeholder)

## Next GAP-05 patch targets
1. Add pan control in Blankie `SoundMixerRow`
2. Add explicit mute/solo controls in Blankie mixer rows
3. Add blend edit/rename affordance in mixer list
4. Add missing-sound warning path when applying saved presets
