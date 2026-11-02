# PORTAL roadmap and development tracker

PORTAL is a local-first visual AI agent for iPhone: point the camera at something, ask about it,
and get an explanation from models running on the phone. Original roadmap: unchanged below.

| Phase | Scope | Status |
|---|---|---|
| 1 | Existing app audit and plan | Complete |
| 2 | Product interface: home, camera, conversation, analysis, discover, memory screens | Complete |
| 3 | Camera integration: permission, live preview, photo capture, gallery selection | Complete (confirmed by owner) |
| - | Visual refinement and branding (minimal design system, home screen, app icon) | Complete (cloud build #10 passed; on-device look to be confirmed by owner) |
| **4a** | **Local visual intelligence, part 1: OCR and whole-image classification (Apple Vision), shown on the analysis screen with source labels** | **In progress: implemented, awaiting cloud build and on-device test** |
| 4b | Local visual intelligence, part 2: vision-language model via MLXVLM. **Live Look**: ask about what the camera sees (Qwen2-VL 2B or SmolVLM2 500M, switchable and timed on the phone so they can be compared) | In progress: implemented, awaiting cloud build and on-device test |
| 5 | Agent integration: routing, structured outputs, validation, visual context, follow-ups | Planned |
| 6 | Persistent visual memory and saved discoveries (no Memory tab; design to be decided, keeping the UI minimal) | Planned |
| 7 | Live visual awareness (throttled frame detection; no live reasoning claims) | Planned |
| 8 | Optimization and on-device testing (memory, battery, speed, offline) | Planned |

## Current status

- Language model: Llama 3.2 3B (4-bit) via MLX Swift. Works on the iPhone 15. Loaded automatically on launch
  (skipped on cellular so a first download never uses mobile data); a different chosen model is remembered.
- Chat: one main screen (orb and greeting that turn into the conversation, one input, camera shortcut) plus
  a Discover tab. The Memory tab and the notes tools were removed on request (they weren't working well).
  Replies stream from Llama 3.2 3B as a plain conversation.
- Agent framework: kept, with **no tools registered**. Registering a tool in `AgentViewModel.makeTools()`
  switches requests to the validated JSON action router, with results shown as action cards in the chat.
- Camera: live preview, capture and gallery picker work. Captured images are kept in memory only.
- Live Look (Phase 4b, camera screen): live preview; each question captures one frame (plus Apple Vision OCR text)
  and a vision model answers about it; after the first question the frame is held so follow-ups reason about
  the same image; "look again" returns to live. **This is not continuous real-time understanding**: answers take
  seconds and are based on the frame captured when you ask. The language model is unloaded while the camera is
  open (both models don't fit in memory together) and reloaded when it closes. First use downloads the vision
  model (about 1 to 1.3 GB) after asking the user. Answers are labeled VISION MODEL (can be wrong).
- Visual analysis (Phase 4a): the analysis screen runs Apple Vision OCR and whole-image classification on the phone.
  OCR text and classifier labels are shown separately, with the analyzers' own confidences and timings.
  **Not implemented yet:** object detection with locations, continuous (per-frame) live understanding, and the
  Llama 3B language model reasoning over visual results (Phase 5).
- Visual refinement: complete (design tokens in `Theme.swift`, icon-only tab bar, minimal home screen,
  asset-catalog app icon). Cloud build #10 passed. Not yet checked on the device.

## Rules that stay fixed

- Bundle ID stays `com.mazen.localassistant` (free Apple ID: 10 App IDs per 7 days). The display name is PORTAL.
- No app extensions or capabilities that need extra App IDs without asking first.
- Findings are labeled by source: OCR, DETECTED, VISION MODEL, INFERRED. No guess is shown as fact.
- Everything runs on the phone. Model downloads are the only network use.

## Build and install

See `README.md`. Push to `main`, GitHub Actions builds an unsigned IPA, install with Sideloadly.
