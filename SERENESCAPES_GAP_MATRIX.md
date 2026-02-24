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
| Mixer/blends workflow | Studio + saved blends + blend player | ✅ Added blend workflow controls + rename/delete + pan + mute/solo + per-track play/pause + missing-sound warnings + blend player cards + autosave semantics + studio workspace toggle + messaging polish | Minor UX polish only after device QA | High | Closed (monitor in QA) |
| Library/download UX | Downloaded/available + server workflows | 🚧 Added Library status + refresh + searchable lists, real remote file download/local storage, persisted task states, progress/retry/remove UI, local-file reconciliation, downloaded-remote playback controls, background URLSession pipeline + app wiring, and preset/blend schema inclusion for selected remote tracks (save/apply) with mixer toggles | Remaining: richer remote-track mixing controls (per-remote volume/pan) and full blend-card preview parity for multi-remote sets | Medium | Add per-remote blend controls + polish multi-remote playback UX |
| Built-in fallback mode | Reliable bundled content fallback | ✅ Mode/state surfaced across Home, Player, Mixer, and Settings | Minor copy polish only | High | Closed (monitor during QA) |

## Immediate Ticket Queue
1. **GAP-03 (🚧): Manifest hardening (telemetry depth + cache-policy tuning)**
2. **GAP-05: Mixer/blend parity validation + missing behavior patches**
3. **GAP-06: Library/download UX parity (progress/state handling)**
