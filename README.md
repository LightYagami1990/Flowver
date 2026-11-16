# Flowver

Make reading simple again. Let voice take you into the world of words.

Flowver is a minimal EPUB audiobook app designed for iOS. Our core mission: in this fast-paced, information-overloaded society, more and more people find it hard to sit down and finish a book. Flowver lowers the barrier to reading, helps users build a reading habit, and enables the blind, low-vision, and people with reading disabilities to equally enjoy the pleasure and knowledge of books.

---

## Why Flowver

- **Make reading simpler**: No need to hold a paper book, no need to stare at the screen word by word. Import an EPUB novel, tap play, and let voice read every paragraph to you.
- **Build a reading habit**: Extremely simple operation, no complex settings. “Open and listen” is the default experience, helping users turn listening into a daily habit, and gradually return to reading text.
- **Serve special groups**: The blind, low-vision users, and people with reading disabilities often lack accessible digital reading channels. Flowver is listening-first, paired with system speech synthesis, so they can enjoy books independently.

---

## Core Features

### 1. Volume Key Page Turning (Fixed Volume)
With system volume fixed, the device’s side volume keys no longer adjust volume, but are mapped to:
- **Volume Up → Next sentence**
- **Volume Down → Previous sentence**

Volume automatically resets to the fixed value and does not change system volume. You don’t need to look at the screen or unlock your phone — one hand is enough to smoothly control the previous and next sentence of the novel. Ideal for blind users, low-vision users, and anyone who wants to listen while walking, doing housework, or resting with eyes closed.

### 2. Lock Screen Background Playback + Lock Screen Media Controls
- Supports `UIBackgroundModes = audio`, so speech continues playing when the screen is locked and is not suspended by the system.
- Integrated with `MPRemoteCommandCenter`; the lock screen “Previous / Next / Play / Pause” media buttons are mapped to the novel’s **Previous Sentence / Next Sentence / Pause / Continue**, so blind users can operate without unlocking the phone.

### 3. Reading Progress Auto-Save
When you leave the app or lock the screen, the next time you open it, it automatically restores to the last chapter and sentence you were at — no need to start over.

### 4. EPUB Support
Import local EPUB files; chapters are automatically parsed and split into sentences for system speech synthesis sentence-by-sentence playback.

### 5. System Speech Synthesis (Multi-language Support)
Uses Apple’s `AVSpeechSynthesizer`, automatically detecting the language of the text and switching the synthesis voice, supporting:
- **English (en-US)**
- **Chinese (zh-CN)**
- **Japanese (ja-JP)**
- **Korean (ko-KR)**

In Settings, you can manually fix the language, adjust speech rate (0.1 ~ 1.0), and set fixed volume (10% ~ 100%).

### 6. Eye-Care Minimal UI
Background is eye-care cream, text is pure black, with generous line spacing. UI references Apple Books. No font color, font size, or theme adjustments — only play/pause, chapter progress, and sentence text are kept, so attention stays on the content.

### 7. Accessibility (VoiceOver)
All buttons and text areas have `accessibilityLabel` and `accessibilityHint` added. Paired with system VoiceOver, visually impaired users can operate the app independently.

---

## Project Structure

```
Flowver/
├── Package.swift                # Swift Package dependency description (optional; Xcode can also drag in sources directly)
├── .gitignore
├── LICENSE                      # MIT License
├── CONTRIBUTING.md              # Contribution guide
├── README.md
├── Info.plist.example           # Info.plist reference (copy into Xcode project and configure)
└── ListenBooks/                 # Source directory (retains historical directory name, does not affect compilation)
    ├── App.swift                # @main entry (FlowverApp)
    ├── ContentView.swift        # Bottom tabs (Library / Listen / Settings)
    ├── LibraryView.swift        # Library: lists EPUBs under Documents/Books, supports import
    ├── ReaderView.swift         # Reader: eye-care background, sentence text, playback control, accessibility labels
    ├── SettingsView.swift       # Minimal settings: language, speech rate, volume, about
    ├── ChapterPickerView.swift  # Chapter jumping
    ├── Book.swift               # Data model
    ├── BookStore.swift          # Global book sharing + reading progress persistence (UserDefaults)
    ├── EPUBParser.swift         # EPUB unzip + OPF/NCX/XHTML parsing + sentence splitting + error handling
    ├── SpeechManager.swift      # AVSpeechSynthesizer wrapper (multi-language auto-detect + lock screen media control + progress saving)
    └── VolumeKeyHandler.swift   # Volume key interception (fixed volume + page-turn mapping)
```

---

## Dependencies (Swift Package Manager)

- [Zip](https://github.com/marmelroy/Zip): unzip EPUB
- [Fuzi](https://github.com/cezheng/Fuzi): lightweight XML/HTML parser (reads OPF, XHTML and extracts plain text)

---

## How to Build and Run (Requires Mac + Xcode)

Flowver is native iOS Swift source code, **cannot be compiled directly on iPhone or iPad**. Please follow these steps on a Mac:

1. On Mac, open Xcode, create a new project → **App** → Interface: **SwiftUI** → Life Cycle: **SwiftUI** → Language: **Swift**.
2. Drag all `.swift` files under `ListenBooks/` into the Xcode project (check "Copy items if needed").
3. Add Swift Package dependencies in Xcode:
   - File → Add Packages…
   - Enter `https://github.com/marmelroy/Zip.git`
   - Enter `https://github.com/cezheng/Fuzi.git`
4. Copy `Info.plist.example` to your project’s `Info.plist`, or manually add in Xcode’s Info panel:
   - `UIBackgroundModes` → `App plays audio` (required, otherwise speech stops when the screen is locked)
   - `CFBundleDisplayName` → `Flowver`
5. Press `Cmd + R` to run on a connected iPhone or simulator.

> Note: The code has not yet been verified on a real device. If you encounter compilation errors, feel free to report them in GitHub Issues or submit a Pull Request directly.

---

## How to Add Books

1. Copy EPUB files to the app’s `Documents/Books` directory;
2. Or tap the **+** button in the top-right of the library screen to import EPUB via the system file picker.

---

## Volume Key Principle (Brief)

`VolumeKeyHandler` adds an invisible `MPVolumeView` to the window and observes the system volume `UISlider` value changes. When the user presses the side volume keys, the app captures the change, immediately resets the volume to the fixed value (default 50%), and maps it to:
- Volume up → Next sentence
- Volume down → Previous sentence

This is an interaction technique based on public APIs; it does not involve jailbreaking or private APIs.

---

## Open Source & License

This project is open sourced under the **MIT License**, welcome to fork, modify, and contribute.

If you have a Mac environment, you can compile and run it directly. If you want to view or participate on GitHub, the code is open at:  
🔗 https://github.com/LightYagami1990/Flowver

---

## Future Roadmap (Stay Minimal)

- No font color, font size, or theme switching will be added for now, staying true to “listening first”.
- To publish on the App Store, you will need to handle privacy policy, file import entitlements, and review guidelines yourself.

---

> Flowver, may everyone who wants to slow down and read find their own rhythm.
