# SereneScapes → Blankie Migration Roadmap

_Last updated: 2026-02-24_

## Mission
Use Blankie as the base app shell and migrate core SereneScapes functionality on top of it:
1. Sound loops + playback reliability
2. Image packs + immersive player visuals
3. Player experience (full-screen + mini-player style behavior)
4. Mixer/blends
5. Downloaded content and offline resilience

## Current Status
- ✅ Sleep timer MVP + polish merged
- ✅ Manifest model + cache/fallback foundation merged
- ✅ Basic full-screen player exists in Blankie
- ⚠️ Image-pack-driven player visuals are not yet parity with SereneScapes
- ⚠️ Mixer and blend workflows need parity validation

## Phases

### Phase 1 — Content & Data Parity
- Manifest schema alignment (remote sounds + image pack metadata)
- Bundled content parity fields
- Cache/fallback behavior and failure-mode hardening

### Phase 2 — Player & Visual Parity
- Image-pack aware full-screen player backgrounds
- Ken Burns/slideshow behavior in single-sound player
- Mini-player behavior parity targets

### Phase 3 — Mixer/Blend Parity
- Blend creation/edit/load parity
- Per-track controls and save/load behavior checks
- UX alignment with SereneScapes expectations

### Phase 4 — Library/Download Parity
- Download management UX parity
- Clear offline/online source state
- Safe fallback to built-in content

### Phase 5 — Polish + QA
- Gap checklist closeout
- Regression suite pass
- Merge readiness and release prep

## Rules for Next Tickets
- Every ticket must map to a phase and gap matrix item.
- Prefer parity-first implementation over speculative new features.
- Keep behavior deterministic and test-covered where practical.
