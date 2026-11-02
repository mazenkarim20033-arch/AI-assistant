# PORTAL roadmap and development tracker

PORTAL is a local-first visual AI agent for iPhone: point the camera at something, ask about it,
and get an explanation from models running on the phone. Original roadmap: unchanged below.

| Phase | Scope | Status |
|---|---|---|
| 1 | Existing app audit and plan | Complete |
| 2 | Product interface: home, camera, conversation, analysis, discover, memory screens | Complete |
| 3 | Camera integration: permission, live preview, photo capture, gallery selection | Complete (confirmed by owner) |
| - | Visual refinement and branding (minimal design system, home screen, app icon) | Implemented. Build check: see "Current status" |
| **4** | **Local visual intelligence: OCR and classification (Apple Vision), then vision-language model evaluation** | **Next milestone** |
| 5 | Agent integration: routing, structured outputs, validation, visual context, follow-ups | Planned |
| 6 | Persistent visual memory and saved discoveries | Planned |
| 7 | Live visual awareness (throttled frame detection; no live reasoning claims) | Planned |
| 8 | Optimization and on-device testing (memory, battery, speed, offline) | Planned |

## Current status

- Language model: Llama 3.2 3B (4-bit) via MLX Swift. Works on the iPhone 15.
- Agent: one validated JSON action per request, executed in Swift. Tools today: save / search / list notes.
- Camera: live preview, capture and gallery picker work. Captured images are kept in memory only.
- **Visual analysis is not implemented.** The analysis screen says so. No OCR, detection or vision model yet.
- Visual refinement: implemented (design tokens in `Theme.swift`, icon-only tab bar, minimal home screen,
  asset-catalog app icon). Cloud build: pending at time of writing.

## Rules that stay fixed

- Bundle ID stays `com.mazen.localassistant` (free Apple ID: 10 App IDs per 7 days). The display name is PORTAL.
- No app extensions or capabilities that need extra App IDs without asking first.
- Findings are labeled by source: OCR, DETECTED, VISION MODEL, INFERRED. No guess is shown as fact.
- Everything runs on the phone. Model downloads are the only network use.

## Build and install

See `README.md`. Push to `main`, GitHub Actions builds an unsigned IPA, install with Sideloadly.
