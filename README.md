# PORTAL (iOS)

SwiftUI app that runs a language model fully on-device with [MLX Swift](https://github.com/ml-explore/mlx-swift-lm)
and uses the iPhone camera. See `ROADMAP.md` for what exists today and what is next.

The model downloads from Hugging Face once (first launch), then everything runs on the phone.

## Build without a Mac
GitHub Actions builds it on a free cloud Mac (`.github/workflows/build-ipa.yml`).

1. Push to the `main` branch of the GitHub repository (public repositories get unlimited free build minutes).
2. On GitHub: **Actions** tab -> **Build IPA**. Takes roughly 15 minutes.
3. Open the finished run -> **Artifacts** -> download `LocalAssistant-ipa` -> unzip to get `LocalAssistant.ipa`.

If the build fails, open the failed step's log: compiler errors are also listed as annotations on the run page.

## Install on the iPhone (free Apple ID)
1. Install iTunes and iCloud from apple.com (not the Microsoft Store versions), then [Sideloadly](https://sideloadly.io).
2. iPhone: Settings -> Privacy & Security -> **Developer Mode** -> on (appears after the first install attempt).
3. Connect the iPhone by USB, drag `LocalAssistant.ipa` into Sideloadly, enter your Apple ID, **Start**.
   Always use the same Apple ID and leave the bundle ID alone, so updates reuse the same App ID.
4. iPhone: Settings -> General -> VPN & Device Management -> trust your Apple ID.

A free Apple ID's signature lasts **7 days**: reinstall weekly (the app and its downloaded model stay).

## Layout
- `Sources/Agent/`: model loading, JSON action loop, tools, notes storage (no UI)
- `Sources/Vision/`: on-device image analyzers (Apple Vision OCR and classification) and their result types
- `Sources/Portal/`: screens and design system (`Theme.swift` holds the design tokens)
- `Sources/Assets.xcassets/`: app icon (1024px source, single-size icon)
- `project.yml`: XcodeGen project definition (the `.xcodeproj` is generated in CI)
