# Nikud

A background macOS menu-bar app that proofreads, polishes, completes, and fixes
punctuation in Hebrew and English — using AI models that run entirely on your Mac.

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon Mac recommended (models run much faster on Apple Silicon)
- Xcode 26 to build

## Building

1. Open `Nikud.xcodeproj` in Xcode.
2. Select the **Nikud** target → **Signing & Capabilities** → set your Team
   (or leave it on "Sign to Run Locally").
3. Build and Run (⌘R).

The project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen)
from `project.yml`. If you add or move files, run `xcodegen generate` to rebuild
the `.xcodeproj`. `llama.cpp` ships as a prebuilt xcframework in `Frameworks/` —
there is nothing else to install.

## First run

Nikud has no Dock icon — it lives in the menu bar. Click the menu-bar icon for
the composer; click the gear for Settings.

## Downloading a model

Open **Settings → Models** and click **Get** on a model. Models are a few GB and
download to `~/Library/Application Support/Nikud/Models`.

| Model | Notes |
|-------|-------|
| DictaLM 2.0 | Recommended — best balance of Hebrew quality and speed |
| DictaLM 3.0 | Strongest Hebrew; needs more memory |
| Gemma 2 9B  | Capable multilingual model |
| Qwen 2.5 7B | Faster multilingual model |
| Gemma 2 2B  | Small and fast; basic Hebrew |

Until a model is installed, the built-in rules engine still handles **Proofread**
and **Punctuation** (spacing, punctuation, capitalization). **Polish** and
**Complete** require a model.

## The global shortcut

Select text in any app and press the shortcut (default **⌥⌘P**) to work on it in
place. This needs Accessibility permission:

> System Settings → Privacy & Security → Accessibility → enable **Nikud**

**Settings → Shortcut** shows the permission status and lets you record a
different shortcut.

## Tasks

- **Complete** — finish the current sentence naturally
- **Proofread** — fix grammar, spelling, and punctuation
- **Polish** — rewrite more clearly (professional, friendly, or concise)
- **Punctuation** — correct only punctuation and spacing

## Privacy

Inference runs locally with llama.cpp. Text you proofread never leaves your Mac.
Only model downloads touch the network (from Hugging Face).

## Notes

- The app is intentionally **not sandboxed** — that is required to read selected
  text system-wide — so it is meant for direct distribution, not the Mac App Store.
- Regenerate the app icon at any time: `swift Tools/GenerateIcon.swift`.

## Credits

- [llama.cpp](https://github.com/ggml-org/llama.cpp) — on-device inference
- DictaLM by [Dicta](https://huggingface.co/dicta-il), Gemma by Google,
  Qwen by Alibaba — the language models
