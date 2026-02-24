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
| Mixer/blends workflow | Studio + saved blends + blend player | 🚧 Added blend workflow controls (new blend/reset, update current blend, unique naming) | Full studio-style multi-track parity still pending | High | Build parity checklist and close remaining gaps |
| Library/download UX | Downloaded/available + server workflows | Partial foundations | Progress/management parity gaps | Medium | Align UX and state handling |
| Built-in fallback mode | Reliable bundled content fallback | ✅ Mode/state surfaced across Home, Player, Mixer, and Settings | Minor copy polish only | High | Closed (monitor during QA) |

## Immediate Ticket Queue
1. **GAP-03 (🚧): Manifest hardening (telemetry depth + cache-policy tuning)**
2. **GAP-05: Mixer/blend parity validation + missing behavior patches**
3. **GAP-06: Library/download UX parity (progress/state handling)**
