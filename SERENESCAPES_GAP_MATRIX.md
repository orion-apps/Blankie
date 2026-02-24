# SereneScapes → Blankie Gap Matrix

_Last updated: 2026-02-24_

## Legend
- ✅ Done
- 🟡 Partial
- ❌ Missing
- 🚧 In Progress

| Area | SereneScapes Baseline | Blankie Current | Gap | Priority | Next Action |
|---|---|---|---|---|---|
| Sound loops playback | Single/multi playback, fade behavior | Core playback and global controls present | Minor parity checks remain | High | Validate edge-case playback parity tests |
| Sleep timer | Timer + fade + UX controls | Implemented + polished | None (for current scope) | Done | Keep regression coverage |
| Manifest/content model | Remote manifest + cache/fallback | 🚧 Retry/backoff + timeout + transient classification added | Telemetry depth and cache-policy tuning remain | High | Expand telemetry + fallback mode UX hooks |
| Image packs in player | Player visuals use image assets/packs | Gradient-based player in Blankie | No image-pack-driven player background parity | Critical | Add image-aware player background path (start now) |
| Ken Burns in single-sound player | Present in SereneScapes | 🚧 Implemented foundation in Blankie player | Validate behavior against SereneScapes timing/feel | High | Tune animation presets + QA on device |
| Mixer/blends workflow | Studio + saved blends + blend player | Core mixer UI exists | Parity validation incomplete | High | Build parity checklist and close gaps |
| Library/download UX | Downloaded/available + server workflows | Partial foundations | Progress/management parity gaps | Medium | Align UX and state handling |
| Built-in fallback mode | Reliable bundled content fallback | 🚧 Mode/state hooks added (`bundledOnly`/`hybrid`) | Need deeper UX + settings visibility | High | Wire mode state across more views/settings |

## Immediate Ticket Queue
1. **GAP-01 (🚧): Player image-pack background foundation**
2. **GAP-02: Ken Burns/slideshow parity in single-sound player**
3. **GAP-03: Manifest hardening (retry/backoff/timeout classification + tests)**
4. **GAP-04: Built-in-only fallback mode and UI state**
5. **GAP-05: Mixer/blend parity validation + missing behavior patches**
