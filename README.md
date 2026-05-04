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
| `Volume Mute` | Toggle mute |

> These keys trigger the **native Windows 11 volume flyout** and simultaneously sync the Mixer GUI.

### Custom Hotkeys
| Key | Action |
|---|---|
| `Alt + ↑` | Increase 2% |
| `Alt + ↓` | Decrease 2% |
| `Shift + Alt + ↑` | Increase 10% |
| `Shift + Alt + ↓` | Decrease 10% |
| `Alt + Scroll Up` | Increase 2% |
| `Alt + Scroll Down` | Decrease 2% |
| `Alt + M` | Toggle mute |
| `Alt + V` | Open / close Mixer GUI |
| `Alt + R` | Reset to 50% |

> Custom hotkeys show a **dedicated overlay** in the bottom-right corner of the screen.

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
│  │ Alt+Up/Down │    │ SetVolume()  │   │ DetectExt.  │ │
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
User presses Volume_Up
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
```

The 60ms delay gives Windows time to actually commit the volume change before we read it back with `SoundGetVolume()`.

---

### 3. Custom Hotkey Flow (`Alt+Up`, `Alt+ScrollWheel`…)

```
User presses Alt+↑
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

## 📁 Function Reference

```
VolumePro.ahk
├── Init
│   ├── InitTray()            — Build tray menu
│   └── InitOverlay()         — Pre-create overlay GUI in RAM
│
├── Hotkeys
│   ├── Volume_Up/Down/Mute   — Media keys: pass-through + sync
│   └── Alt+*/Scroll/...      — Custom hotkeys, call ChangeVolume()
│
├── Audio Core
│   ├── GetVolume()           — Read SoundGetVolume(), round to integer
│   ├── SetVolume(v)          — Write + clamp 0–100 + unmute if needed
│   ├── ChangeVolume(step)    — SetVolume(current + step)
│   └── ToggleMute()          — Send Volume_Mute + sync after 60ms
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
└── Helpers
    ├── GetVolumeColor(vol, muted) — Return HEX color per threshold
    ├── GetVolumeIcon(vol, muted)  — Return emoji 🔇🔈🔉🔊
    └── ApplyWin11Style(hwnd)      — Rounded corners + Mica + Dark mode via DWM API
```

---

## 🔧 Quick Customization

Open the `.ahk` file in any text editor and adjust the following:

**Change volume step size:**
```autohotkey
!Up::   ChangeVolume(2)   ; ← change 2 to any number
!Down:: ChangeVolume(-2)
```

**Change color thresholds:**
```autohotkey
GetVolumeColor(vol, muted) {
    if vol <= 40   ; ← "low" threshold
        return "27AE60"
    if vol <= 75   ; ← "medium" threshold
        return "0078D4"
    return "E05C00"  ; ← "high" color
}
```

**Change overlay display duration:**
```autohotkey
SetTimer(HideOverlay, -1800)  ; ← 1800ms = 1.8 seconds
```

---

## 💡 Technical Notes

- **`#SingleInstance Force`** — If the script is launched a second time, the previous instance exits automatically to prevent conflicts.
- **`+E0x20` (WS_EX_TRANSPARENT)** — The overlay ignores mouse clicks, passing them through to whatever window is underneath.
- **`NoActivate`** in `Show()` — The window appears without stealing focus, so it never interrupts what the user is doing.
- **`SetTimer(..., -N)`** — A negative value means run **once** after N milliseconds, as opposed to a positive value which repeats indefinitely.
- **DWM API** — All Win11 visual effects (rounded corners, Mica, dark mode) are called directly through `dwmapi.dll` with no external libraries required.
