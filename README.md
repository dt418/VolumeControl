# 🔊 VolumePro v3

> An advanced volume controller for Windows 11, written in AutoHotkey v2.  
> Integrates with the native Windows 11 volume flyout, a custom overlay, and a modern Mixer GUI.

---

## 📋 Requirements

| Component | Version |
|---|---|
| AutoHotkey | v2.0 or later |
| Operating System | Windows 11 (22H2+ recommended for Mica effect) |

---

## 🚀 Getting Started

```
Double-click VolumePro.ahk
```

The script runs silently in the system tray. The AHK icon appears in the bottom-right corner of the taskbar.

---

## ⌨️ Hotkeys

### Media Keys (keyboard / headset)
| Key | Action |
|---|---|
| `Volume Up` | Increase volume (Windows default step ~2%) |
| `Volume Down` | Decrease volume |
| `Volume Mute` | Toggle mute (via `SoundSetMute(-1)`) |

> These keys trigger the **native Windows 11 volume flyout** and simultaneously sync the Mixer GUI.

### Custom Hotkeys
| Key | Action |
|---|---|
| `Ctrl + ↑` | Increase 2% |
| `Ctrl + ↓` | Decrease 2% |
| `Shift + Ctrl + ↑` | Increase 10% |
| `Shift + Ctrl + ↓` | Decrease 10% |
| `Ctrl + Scroll Up` | Increase 2% |
| `Ctrl + Scroll Down` | Decrease 2% |
| `Ctrl + M` | Toggle mute |
| `Ctrl + V` | Open / close Mixer GUI |
| `Ctrl + R` | Reset to 50% |

> Custom hotkeys show a **dedicated overlay** in the bottom-right corner of the screen.

> 💡 The modifier key (`Ctrl` by default) is configurable in `VolumePro.ini`. Set `Modifier = Alt | Ctrl | CtrlAlt | WinKey` to change it globally. Hotkeys are dynamically re-registered without restarting the script.

> 🚫 **Blacklist** — hotkeys are automatically suppressed when certain apps are focused (e.g. VS Code, Chrome, Explorer). A short beep signals the block. Configure the list in `VolumePro.ini` under `[Blacklist]`.

---

## 🏗️ Architecture & How It Works

```
┌─────────────────────────────────────────────────────────┐
│                      VolumePro.ahk                      │
│                                                         │
│  ┌─────────────┐    ┌──────────────┐   ┌─────────────┐ │
│  │  HOTKEYS    │    │  AUDIO CORE  │   │   TIMER     │ │
│  │             │───▶│              │   │  150ms poll │ │
│  │ Media keys  │    │ GetVolume()  │◀──│             │ │
│  │ Ctrl+Up/Down │    │ SetVolume()  │   │ DetectExt.  │ │
│  │ ScrollWheel │    │ ToggleMute() │   │ Change()    │ │
│  └─────────────┘    └──────┬───────┘   └─────────────┘ │
│                            │                            │
│              ┌─────────────┼─────────────┐              │
│              ▼             ▼             ▼              │
│       ┌──────────┐  ┌──────────┐  ┌──────────┐         │
│       │  OVERLAY │  │ MIXER GUI│  │  SYNC UI │         │
│       │          │  │          │  │          │         │
│       │ Bottom-  │  │ Win11    │  │ Updates  │         │
│       │ right    │  │ flyout   │  │ slider & │         │
│       │ corner   │  │ style    │  │ label    │         │
│       └──────────┘  └──────────┘  └──────────┘         │
└─────────────────────────────────────────────────────────┘
```

### 1. Startup (`InitTray` + `InitOverlay`)

Two init functions are called immediately when the script starts:

- **`InitTray()`** — Builds the right-click system tray menu with entries: Mixer, Mute, Exit.
- **`InitOverlay()`** — Pre-creates the overlay window in memory (hidden), using a caption-less `Gui` that stays on top (`+AlwaysOnTop`). Rounded corners and Mica effect are applied via `DwmSetWindowAttribute`. The overlay is only `Show`n when needed — never re-created on each call.

Then `SetTimer(DetectExternalChange, 150)` starts the 150ms background polling loop.

---

### 2. Media Key Flow (`Volume_Up / Down / Mute`)

```
User presses Volume_Up / Volume_Down
        │
        ▼
AHK intercepts the key (low-level hook)
        │
        ├──▶ Send "{Volume_Up}"
        │         └──▶ Windows handles it: raises volume + shows native Win11 flyout
        │
        └──▶ SetTimer(ShowCurrentVolume, -60ms)
                  └──▶ Re-reads SoundGetVolume() after 60ms
                            └──▶ SyncUI() — updates Mixer if it's open

User presses Volume_Mute  (or Ctrl + M)
        │
        ▼
SoundSetMute(-1)   ← calls Windows Audio API directly, NO Send used
        │          ← prevents AHK from re-triggering its own hotkey → infinite loop
        └──▶ SetTimer(ShowMuteState, -60ms)
                  └──▶ SyncUI() — refreshes icon + label in Mixer
```

The 60ms delay gives Windows time to actually commit the volume change before we read it back with `SoundGetVolume()`.

> ⚠️ **Why `Send "{Volume_Mute}"` is NOT used:**  
> Using `Send` causes AHK to re-fire its own `Volume_Mute::` or `^m::` hotkey, creating a recursive loop — dozens of hotkeys per second — triggering the warning dialog *"X hotkeys have been received in the last Nms"*. `SoundSetMute(-1)` talks directly to Windows Audio and generates no keyboard event.

---

### 3. Custom Hotkey Flow (`Ctrl+Up`, `Ctrl+ScrollWheel`…)

```
User presses Ctrl+↑
        │
        ▼
ChangeVolume(+2)
        │
        ▼
SetVolume(v + 2)
        ├──▶ SoundSetVolume(v)     ← writes directly to Windows Audio
        ├──▶ SoundSetMute(0)       ← unmutes if currently muted
        ├──▶ ShowOverlay(v)        ← shows overlay in bottom-right corner
        ├──▶ SyncUI()              ← updates Mixer GUI if open
        └──▶ UpdateLastState(v)    ← stores value for comparison
```

The overlay is **not used** for media keys (the Win11 flyout handles that) — only for custom hotkeys.

---

### 4. External Change Detection (`DetectExternalChange`)

A 150ms timer runs continuously in the background:

```
Every 150ms:
  v     = SoundGetVolume()
  muted = SoundGetMute()

  If v ≠ lastVolume OR muted ≠ lastMuted
      → SyncUI()   ← update Mixer GUI
      → Store new values
```

This keeps the Mixer GUI in sync even when volume is changed by:
- The Windows tray icon
- Spotify, a browser, or another app
- A Bluetooth device auto-adjusting

---

### 5. Mixer GUI — Windows 11 Flyout Style

The Mixer is not a standard window — it uses `-Caption` to hide the title bar, combined with:

| Technique | API | Purpose |
|---|---|---|
| Rounded corners | `DwmSetWindowAttribute(33, DWMWCP_ROUND)` | Win11-style 8px corner radius |
| Dark mode | `DwmSetWindowAttribute(20, 1)` | Dark title bar |
| Mica Alt | `DwmSetWindowAttribute(38, 4)` | Frosted Mica background blur |
| Dark buttons | `SetWindowTheme("DarkMode_Explorer")` | Dark-themed buttons matching Win11 |

The Mixer is positioned in the bottom-right corner using `SysGet(16)` (screen width) and `SysGet(17)` (screen height), mirroring the native flyout position.

---

### 6. Threshold Color System

All UI elements (overlay bar, icon, percentage label, accent strip) share a single `GetVolumeColor()` function:

```
GetVolumeColor(vol, muted):
  Muted or 0%     → #888888  ████  Gray
  1%  – 40%       → #27AE60  ████  Green   (low)
  41% – 75%       → #0078D4  ████  Blue    (medium — Win11 accent)
  76% – 100%      → #E05C00  ████  Orange-red  (high)
```

Color updates in real time at three points:
- When dragging the Mixer slider → `MixerSliderChange()`
- When a hotkey is pressed → `ShowOverlay()` + `SyncUI()`
- When Windows changes volume externally → `DetectExternalChange()` → `SyncUI()`


---

### 7. First-run Welcome & Help Window

On the very first launch, VolumePro creates a sentinel file `VolumePro.firstrun` next to the script. When this file is absent, a **Welcome/Help window** is shown automatically after 800ms (giving the overlay time to initialize).

The Help window can be reopened at any time via **tray → ❓ Help / Hotkeys** and contains three sections:

| Section | Contents |
|---|---|
| ⌨️ Hotkeys | All custom shortcuts, auto-populated from the active `Modifier` setting |
| 🖱️ System Tray | Description of every tray menu entry |
| 🔔 Beep Guide | Meaning of each beep tone (blocked vs limit) |

Two footer buttons are provided: **Edit Config** (opens `VolumePro.ini` in Notepad) and **Got it!** (closes the window). To force the Welcome screen to reappear, delete `VolumePro.firstrun`.

---

## 📁 Function Reference

```
VolumePro.ahk
├── Init
│   ├── InitTray()            — Build tray menu
│   └── InitOverlay()         — Pre-create overlay GUI in RAM
│
├── Hotkeys
│   ├── Volume_Up/Down/Mute   — Media keys: pass-through + sync
│   └── Ctrl+*/Scroll/...    — Custom hotkeys, call ChangeVolume()
│
├── Audio Core
│   ├── GetVolume()           — Read SoundGetVolume(), round to integer
│   ├── SetVolume(v)          — Write + clamp 0–100 + unmute if needed
│   ├── ChangeVolume(step)    — SetVolume(current + step)
│   └── ToggleMute()          — SoundSetMute(-1) directly + sync after 60ms
│
├── Overlay
│   ├── ShowOverlay(vol, muted) — Show popup bottom-right, auto-hide after 1.8s
│   └── HideOverlay()           — Hide overlay
│
├── Mixer GUI
│   ├── ToggleMixer()         — Toggle Mixer window visibility
│   ├── OpenMixer()           — Build & show Mixer in Win11 style
│   └── MixerSliderChange()   — Handle slider drag in real time
│
├── Sync & Detection
│   ├── SyncUI()              — Refresh all Mixer GUI elements to current volume
│   ├── DetectExternalChange()— 150ms poll, detect changes from outside
│   └── UpdateLastState()     — Store lastVolume / lastMuted
│
├── Config
│   ├── LoadConfig()          — Read VolumePro.ini, apply all settings
│   ├── ValidateConfig()      — Validate all values, auto-reset bad ones, show warnings
│   ├── WatchConfig()         — 3s timer: auto-reload when .ini file changes
│   └── RegisterHotkeys()     — Dynamically register hotkeys based on Modifier setting
│
├── Help
│   └── ShowHelp()            — Welcome/Help window (auto on first run, tray on demand)
│
└── Helpers
    ├── GetVolumeColor(vol, muted) — Return HEX color per threshold
    ├── GetVolumeIcon(vol, muted)  — Return emoji 🔇🔈🔉🔊
    ├── ApplyWin11Style(hwnd)      — Rounded corners + Mica + Dark mode via DWM API
    ├── BeepBlocked()              — Low beep when hotkey suppressed by blacklist
    └── BeepLimit()                — High beep when volume hits 0% or 100%
```

---

## 🔧 Quick Customization

All settings are in `VolumePro.ini` (auto-generated on first run). Edit it — the script reloads changes within 3 seconds.

**Change modifier key:**
```ini
[Hotkeys]
Modifier = Ctrl         ; Alt | Ctrl | CtrlAlt | WinKey
```

**Change volume step size:**
```ini
[Hotkeys]
VolumeStep = 2          ; 1–50
VolumeStepLarge = 10    ; 1–50, must be > VolumeStep
```

**Change overlay duration:**
```ini
[Hotkeys]
OverlayDuration = 1800  ; milliseconds (200–10000)
```

**Add or remove apps from the blacklist:**
```ini
[Blacklist]
Apps = chrome.exe, Code.exe, explorer.exe
; Hotkeys are suppressed when these apps are focused.
; A low beep (400 Hz) signals the block.
```

**Change beep settings:**
```ini
[Beep]
Enabled = true          ; true | false
BlockedFreq = 400       ; Hz (37–32767)
BlockedDuration = 80    ; ms (10–2000)
LimitFreq = 600         ; Hz (37–32767)
LimitDuration = 60      ; ms (10–2000)
```

**Change color thresholds (edit `.ahk`):**
```autohotkey
GetVolumeColor(vol, muted) {
    if vol <= 40   ; ← "low" threshold
        return "27AE60"
    if vol <= 75   ; ← "medium" threshold
        return "0078D4"
    return "E05C00"  ; ← "high" color
}
```

---

## 💡 Technical Notes

- **`SoundSetMute(-1)`** — The value `-1` means toggle (flip the current state). Used instead of `Send "{Volume_Mute}"` to prevent AHK from re-triggering its own hotkey, which would cause an infinite loop and the warning dialog *"X hotkeys in Nms"*.
- **`#SingleInstance Force`** — If the script is launched a second time, the previous instance exits automatically to prevent conflicts.
- **`+E0x20` (WS_EX_TRANSPARENT)** — The overlay ignores mouse clicks, passing them through to whatever window is underneath.
- **`NoActivate`** in `Show()` — The window appears without stealing focus, so it never interrupts what the user is doing.
- **`SetTimer(..., -N)`** — A negative value means run **once** after N milliseconds, as opposed to a positive value which repeats indefinitely.
- **DWM API** — All Win11 visual effects (rounded corners, Mica, dark mode) are called directly through `dwmapi.dll` with no external libraries required.
