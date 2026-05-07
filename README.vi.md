# 🔊 VolumePro v3

> Bộ điều khiển âm lượng nâng cao cho Windows 11, viết bằng AutoHotkey v2.  
> Tích hợp flyout gốc Windows 11, overlay tùy chỉnh, và Mixer GUI kiểu modern.

---

## 📋 Yêu cầu

| Thành phần | Phiên bản |
|---|---|
| AutoHotkey | v2.0 trở lên |
| Hệ điều hành | Windows 11 (khuyến nghị 22H2+ để có Mica effect) |

---

## 🚀 Cách chạy

```
Nhấp đôi vào VolumePro.ahk
```

Script chạy ẩn dưới system tray. Biểu tượng AHK xuất hiện ở góc phải taskbar.

---

## ⌨️ Phím tắt

### Phím Media (bàn phím / tai nghe)
| Phím | Hành động |
|---|---|
| `Volume Up` | Tăng âm lượng (bước Windows mặc định ~2%) |
| `Volume Down` | Giảm âm lượng |
| `Volume Mute` | Bật / tắt mute (dùng `SoundSetMute(-1)`) |

> Các phím này kích hoạt **flyout gốc của Windows 11** đồng thời sync Mixer GUI.

### Phím tắt tùy chỉnh
| Phím | Hành động |
|---|---|
| `Ctrl + ↑` | Tăng 2% |
| `Ctrl + ↓` | Giảm 2% |
| `Shift + Ctrl + ↑` | Tăng 10% |
| `Shift + Ctrl + ↓` | Giảm 10% |
| `Ctrl + Scroll Up` | Tăng 2% |
| `Ctrl + Scroll Down` | Giảm 2% |
| `Ctrl + M` | Toggle mute |
| `Ctrl + V` | Mở / đóng Mixer GUI |
| `Ctrl + R` | Reset về 50% |

> Các phím tùy chỉnh hiển thị **overlay riêng** ở góc dưới phải màn hình.

> 💡 Phím modifier (`Ctrl` mặc định) có thể cấu hình trong `VolumePro.ini`. Đặt `Modifier = Alt | Ctrl | CtrlAlt | WinKey` để thay đổi toàn bộ. Hotkey được đăng ký lại động mà không cần restart script.

> 🚫 **Blacklist** — hotkey tự động bị vô hiệu khi các app nhất định đang được focus (VS Code, Chrome, Explorer...). Một tiếng beep ngắn báo hiệu bị chặn. Cấu hình danh sách trong `VolumePro.ini` mục `[Blacklist]`.

---

## 🏗️ Kiến trúc & Nguyên lý hoạt động

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
│       │ Góc dưới │  │ Flyout   │  │ Cập nhật │         │
│       │ phải màn │  │ Win11    │  │ slider & │         │
│       │ hình     │  │ style    │  │ label    │         │
│       └──────────┘  └──────────┘  └──────────┘         │
└─────────────────────────────────────────────────────────┘
```

### 1. Khởi động (`InitTray` + `InitOverlay`)

Khi script chạy, hai hàm init được gọi ngay:

- **`InitTray()`** — Xây dựng menu chuột phải trên system tray với các mục: Mixer, Mute, Exit.
- **`InitOverlay()`** — Tạo sẵn cửa sổ overlay trong bộ nhớ (ẩn), dùng `Gui` không có caption, luôn ở trên cùng (`+AlwaysOnTop`). Áp dụng bo góc và Mica effect qua `DwmSetWindowAttribute`. Overlay chỉ được `Show` khi cần, không tạo mới mỗi lần.

Sau đó `SetTimer(DetectExternalChange, 150)` bắt đầu vòng lặp nền 150ms.

---

### 2. Luồng phím Media (`Volume_Up / Down / Mute`)

```
Người dùng nhấn Volume_Up / Volume_Down
        │
        ▼
AHK bắt sự kiện (hook phím)
        │
        ├──▶ Send "{Volume_Up}"
        │         └──▶ Windows xử lý: tăng âm lượng thật + hiện flyout gốc Win11
        │
        └──▶ SetTimer(ShowCurrentVolume, -60ms)
                  └──▶ Đọc lại SoundGetVolume() sau 60ms
                            └──▶ SyncUI() — cập nhật Mixer nếu đang mở

Người dùng nhấn Volume_Mute  (hoặc Ctrl + M)
        │
        ▼
SoundSetMute(-1)   ← gọi thẳng Windows Audio API, KHÔNG dùng Send
        │          ← tránh AHK bắt lại sự kiện → vòng lặp vô hạn
        └──▶ SetTimer(ShowMuteState, -60ms)
                  └──▶ SyncUI() — cập nhật icon + label Mixer
```

Lý do delay 60ms: Windows cần một chút thời gian để thực sự thay đổi giá trị âm lượng trước khi ta đọc lại bằng `SoundGetVolume()`.

> ⚠️ **Lưu ý quan trọng — Tại sao không dùng `Send "{Volume_Mute}"`:**  
> Nếu dùng `Send`, AHK sẽ tự kích hoạt lại hotkey `Volume_Mute::` hoặc `^m::` của chính mình, tạo vòng đệ quy → hàng chục hotkey/giây → hộp thoại cảnh báo *"X hotkeys have been received in the last Nms"*. `SoundSetMute(-1)` giao tiếp trực tiếp với Windows Audio, không phát sinh keyboard event.

---

### 3. Luồng phím tùy chỉnh (`Ctrl+Up`, `Ctrl+ScrollWheel`…)

```
Người dùng nhấn Ctrl+↑
        │
        ▼
ChangeVolume(+2)
        │
        ▼
SetVolume(v + 2)
        ├──▶ SoundSetVolume(v)     ← ghi thẳng vào Windows Audio
        ├──▶ SoundSetMute(0)       ← bỏ mute nếu đang muted
        ├──▶ ShowOverlay(v)        ← hiện overlay góc dưới phải
        ├──▶ SyncUI()              ← cập nhật Mixer GUI nếu đang mở
        └──▶ UpdateLastState(v)    ← ghi nhớ giá trị để so sánh
```

Overlay **không dùng** cho phím media (vì flyout Win11 đã lo), chỉ dùng cho hotkey tùy chỉnh.

---

### 4. Phát hiện thay đổi từ bên ngoài (`DetectExternalChange`)

Timer 150ms chạy liên tục trong nền:

```
Mỗi 150ms:
  v     = SoundGetVolume()
  muted = SoundGetMute()
  
  Nếu v ≠ lastVolume HOẶC muted ≠ lastMuted
      → SyncUI()   ← cập nhật Mixer GUI
      → Lưu giá trị mới
```

Điều này đảm bảo Mixer GUI luôn đồng bộ kể cả khi âm lượng bị thay đổi bởi:
- Tray icon Windows
- Spotify, trình duyệt, hoặc app khác
- Thiết bị Bluetooth tự điều chỉnh

---

### 5. Mixer GUI — Windows 11 Flyout Style

Mixer không phải cửa sổ thông thường — nó dùng `-Caption` để ẩn title bar, cộng với:

| Kỹ thuật | API | Mục đích |
|---|---|---|
| Bo góc tròn | `DwmSetWindowAttribute(33, DWMWCP_ROUND)` | Bo góc 8px kiểu Win11 |
| Dark mode | `DwmSetWindowAttribute(20, 1)` | Thanh tiêu đề tối |
| Mica Alt | `DwmSetWindowAttribute(38, 4)` | Hiệu ứng nền mờ Mica |
| Dark button | `SetWindowTheme("DarkMode_Explorer")` | Nút tối theo theme Win11 |

Mixer được định vị tại góc dưới phải màn hình bằng `SysGet(16)` (chiều rộng) và `SysGet(17)` (chiều cao), bắt chước vị trí flyout gốc.

---

### 6. Hệ thống màu theo ngưỡng

Toàn bộ giao diện (overlay bar, icon, label %, dải accent) dùng chung hàm `GetVolumeColor()`:

```
GetVolumeColor(vol, muted):
  Muted hoặc 0%   → #888888  ████  Xám
  1% – 40%        → #27AE60  ████  Xanh lá  (nhỏ)
  41% – 75%       → #0078D4  ████  Xanh Win11 (vừa)
  76% – 100%      → #E05C00  ████  Đỏ cam   (lớn)
```

Màu được cập nhật realtime tại 3 điểm:
- Khi kéo slider Mixer → `MixerSliderChange()`
- Khi nhấn phím hotkey → `ShowOverlay()` + `SyncUI()`
- Khi Windows thay đổi từ ngoài → `DetectExternalChange()` → `SyncUI()`


---

### 7. Màn hình Welcome & Cửa sổ Help

Lần đầu chạy, VolumePro tạo file sentinel `VolumePro.firstrun` cạnh script. Khi file này chưa tồn tại, **cửa sổ Welcome/Help** sẽ tự hiện sau 800ms (chờ overlay khởi tạo xong).

Cửa sổ Help có thể mở lại bất cứ lúc nào qua **tray → ❓ Help / Hotkeys** và gồm 3 section:

| Section | Nội dung |
|---|---|
| ⌨️ Hotkeys | Toàn bộ phím tắt, tự đọc từ `Modifier` đang dùng |
| 🖱️ System Tray | Giải thích từng mục menu tray |
| 🔔 Beep Guide | Ý nghĩa từng tiếng beep (bị chặn vs chạm giới hạn) |

Hai nút footer: **Edit Config** (mở `VolumePro.ini` trong Notepad) và **Got it!** (đóng cửa sổ). Để hiện lại màn hình Welcome, xóa file `VolumePro.firstrun`.

---

## 📁 Cấu trúc hàm

```
VolumePro.ahk
├── Init
│   ├── InitTray()            — Menu tray
│   └── InitOverlay()         — Tạo overlay GUI sẵn trong RAM
│
├── Hotkeys
│   ├── Volume_Up/Down/Mute   — Phím media, pass-through + sync
│   └── Ctrl+*/Scroll/...    — Hotkey tùy chỉnh, dynamic qua RegisterHotkeys()
│
├── Audio Core
│   ├── GetVolume()           — Đọc SoundGetVolume(), làm tròn
│   ├── SetVolume(v)          — Ghi + clamp 0–100 + bỏ mute
│   ├── ChangeVolume(step)    — SetVolume(current + step)
│   └── ToggleMute()          — SoundSetMute(-1) trực tiếp + sync sau 60ms
│
├── Overlay
│   ├── ShowOverlay(vol, muted) — Hiện popup góc dưới phải, auto-hide 1.8s
│   └── HideOverlay()           — Ẩn overlay
│
├── Mixer GUI
│   ├── ToggleMixer()         — Bật/tắt cửa sổ Mixer
│   ├── OpenMixer()           — Tạo & hiện Mixer Win11 style
│   └── MixerSliderChange()   — Xử lý kéo slider realtime
│
├── Sync & Detection
│   ├── SyncUI()              — Cập nhật toàn bộ Mixer GUI theo âm lượng hiện tại
│   ├── DetectExternalChange()— Poll 150ms, phát hiện thay đổi từ ngoài
│   └── UpdateLastState()     — Lưu lastVolume / lastMuted
│
├── Config
│   ├── LoadConfig()          — Đọc VolumePro.ini, áp dụng toàn bộ cài đặt
│   ├── ValidateConfig()      — Kiểm tra giá trị, tự reset lỗi, hiện cảnh báo
│   ├── WatchConfig()         — Timer 3s: tự reload khi file .ini thay đổi
│   └── RegisterHotkeys()     — Đăng ký hotkey động theo Modifier đang dùng
│
├── Help
│   └── ShowHelp()            — Cửa sổ Welcome/Help (tự động lần đầu, tray khi cần)
│
└── Helpers
    ├── GetVolumeColor(vol, muted) — Trả màu HEX theo ngưỡng
    ├── GetVolumeIcon(vol, muted)  — Trả emoji 🔇🔈🔉🔊
    ├── ApplyWin11Style(hwnd)      — Bo góc + Mica + Dark mode qua DWM API
    ├── BeepBlocked()              — Beep thấp khi hotkey bị chặn bởi blacklist
    └── BeepLimit()                — Beep cao khi âm lượng chạm 0% hoặc 100%
```

---

## 🔧 Tùy chỉnh nhanh

Toàn bộ cài đặt nằm trong `VolumePro.ini` (tự tạo ở lần chạy đầu). Chỉnh sửa file này — script tự reload sau 3 giây.

**Thay đổi phím modifier:**
```ini
[Hotkeys]
Modifier = Ctrl         ; Alt | Ctrl | CtrlAlt | WinKey
```

**Thay đổi bước nhảy âm lượng:**
```ini
[Hotkeys]
VolumeStep = 2          ; 1–50
VolumeStepLarge = 10    ; 1–50, phải > VolumeStep
```

**Thay đổi thời gian hiện overlay:**
```ini
[Hotkeys]
OverlayDuration = 1800  ; millisecond (200–10000)
```

**Thêm hoặc xóa app khỏi blacklist:**
```ini
[Blacklist]
Apps = chrome.exe, Code.exe, explorer.exe
; Hotkey bị vô hiệu khi các app này đang focus.
; Tiếng beep thấp (400 Hz) báo hiệu bị chặn.
```

**Thay đổi cài đặt beep:**
```ini
[Beep]
Enabled = true          ; true | false
BlockedFreq = 400       ; Hz (37–32767)
BlockedDuration = 80    ; ms (10–2000)
LimitFreq = 600         ; Hz (37–32767)
LimitDuration = 60      ; ms (10–2000)
```

**Thay đổi ngưỡng màu (sửa `.ahk`):**
```autohotkey
GetVolumeColor(vol, muted) {
    if vol <= 40   ; ← ngưỡng "nhỏ"
        return "27AE60"
    if vol <= 75   ; ← ngưỡng "vừa"
        return "0078D4"
    return "E05C00"  ; ← màu "lớn"
}
```

---

## 💡 Ghi chú kỹ thuật

- **`SoundSetMute(-1)`** — Giá trị `-1` nghĩa là toggle (đảo trạng thái hiện tại). Dùng thay cho `Send "{Volume_Mute}"` để tránh AHK tự kích hoạt lại hotkey của mình, gây vòng lặp vô hạn và hộp thoại cảnh báo *"X hotkeys in Nms"*.
- **`#SingleInstance Force`** — Nếu chạy script lần thứ hai, instance cũ sẽ tự tắt, tránh xung đột.
- **`+E0x20` (WS_EX_TRANSPARENT)** — Overlay không nhận click chuột, click xuyên qua xuống cửa sổ bên dưới.
- **`NoActivate`** trong `Show()` — Cửa sổ hiện ra mà không lấy focus, không làm gián đoạn việc đang làm.
- **`SetTimer(..., -N)`** — Số âm nghĩa là chạy **một lần** sau N millisecond, khác với số dương chạy lặp vô hạn.
- **DWM API** — Tất cả hiệu ứng Win11 (bo góc, Mica, dark mode) được gọi trực tiếp qua `dwmapi.dll`, không dùng thư viện bên ngoài.
