# Local Assistant (iOS)

SwiftUI chat app that runs an LLM fully on-device with [MLX Swift](https://github.com/ml-explore/mlx-swift-lm).
Scope for now: chat interface + local model loading only. No tools yet.

The model downloads from Hugging Face once (first launch), then everything runs on the phone.

## Build without a Mac
GitHub Actions builds it on a free cloud Mac (`.github/workflows/build-ipa.yml`).

1. Create a free GitHub account and an **empty public repository** (public = unlimited free build minutes).
2. From this folder:
   ```
   git init -b main
   git add .
   git commit -m "Initial app"
   git remote add origin https://github.com/<you>/<repo>.git
   git push -u origin main
   ```
3. On GitHub: **Actions** tab -> **Build IPA** (it starts on push; or "Run workflow").
   Takes roughly 10-25 minutes the first time.
4. Open the finished run -> **Artifacts** -> download `LocalAssistant-ipa` -> unzip to get `LocalAssistant.ipa`.

If the build fails, open the failed step's log and send it over; first builds usually need a fix or two.

## Install on the iPhone (free Apple ID)
1. Install iTunes and iCloud from apple.com (not the Microsoft Store versions), then [Sideloadly](https://sideloadly.io).
2. iPhone: Settings -> Privacy & Security -> **Developer Mode** -> on (restarts the phone).
3. Connect the iPhone by USB, drag `LocalAssistant.ipa` into Sideloadly, enter your Apple ID, **Start**.
   (A spare Apple ID is a good idea for sideloading.)
4. iPhone: Settings -> General -> VPN & Device Management -> trust your Apple ID.

A free Apple ID's signature lasts **7 days**: repeat step 3 weekly (the app and its downloaded model stay).

## Files
- `Sources/ChatViewModel.swift`: model loading + streaming chat (the only place that talks to the LLM)
- `Sources/ChatView.swift`: interface
- `Sources/ModelOption.swift`: model list
- `project.yml`: XcodeGen project definition (the `.xcodeproj` is generated in CI)
