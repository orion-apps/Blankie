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
| Library/download UX | Downloaded/available + server workflows | 🚧 Added Library status + refresh + searchable lists, remote filtering (all/downloaded/not-downloaded), real remote file download/local storage, persisted task states, progress/retry/remove UI, local-file reconciliation, downloaded-remote playback controls, background URLSession pipeline + app wiring, preset/blend schema inclusion for selected remote tracks, per-remote volume/pan controls, and multi-remote blend-card summary polish | Remaining: final device QA polish and deeper remote metadata presentation refinements | Medium | Run parity QA pass and apply UI polish fixes |
| Built-in fallback mode | Reliable bundled content fallback | ✅ Mode/state surfaced across Home, Player, Mixer, and Settings | Minor copy polish only | High | Closed (monitor during QA) |

## Immediate Ticket Queue
1. **QA-01 (next): Device parity QA pass** (player visuals, mixer/blends, library/download background behavior)
2. **GAP-03 (🚧): Manifest hardening closeout** (telemetry depth + cache-policy tuning)
3. **UX-Polish:** Remote metadata presentation refinements in Library
