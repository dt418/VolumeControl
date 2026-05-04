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
| `Volume Mute` | Bật / tắt mute |

> Các phím này kích hoạt **flyout gốc của Windows 11** đồng thời sync Mixer GUI.

### Phím tắt tùy chỉnh
| Phím | Hành động |
|---|---|
| `Alt + ↑` | Tăng 2% |
| `Alt + ↓` | Giảm 2% |
| `Shift + Alt + ↑` | Tăng 10% |
| `Shift + Alt + ↓` | Giảm 10% |
| `Alt + Scroll Up` | Tăng 2% |
| `Alt + Scroll Down` | Giảm 2% |
| `Alt + M` | Toggle mute |
| `Alt + V` | Mở / đóng Mixer GUI |
| `Alt + R` | Reset về 50% |

> Các phím tùy chỉnh hiển thị **overlay riêng** ở góc dưới phải màn hình.

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
│  │ Alt+Up/Down │    │ SetVolume()  │   │ DetectExt.  │ │
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
Người dùng nhấn Volume_Up
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
```

Lý do delay 60ms: Windows cần một chút thời gian để thực sự thay đổi giá trị âm lượng trước khi ta đọc lại bằng `SoundGetVolume()`.

---

### 3. Luồng phím tùy chỉnh (`Alt+Up`, `Alt+ScrollWheel`…)

```
Người dùng nhấn Alt+↑
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

## 📁 Cấu trúc hàm

```
VolumePro.ahk
├── Init
│   ├── InitTray()            — Menu tray
│   └── InitOverlay()         — Tạo overlay GUI sẵn trong RAM
│
├── Hotkeys
│   ├── Volume_Up/Down/Mute   — Phím media, pass-through + sync
│   └── Alt+*/Scroll/...      — Hotkey tùy chỉnh, gọi ChangeVolume()
│
├── Audio Core
│   ├── GetVolume()           — Đọc SoundGetVolume(), làm tròn
│   ├── SetVolume(v)          — Ghi + clamp 0–100 + bỏ mute
│   ├── ChangeVolume(step)    — SetVolume(current + step)
│   └── ToggleMute()          — Send Volume_Mute + sync sau 60ms
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
└── Helpers
    ├── GetVolumeColor(vol, muted) — Trả màu HEX theo ngưỡng
    ├── GetVolumeIcon(vol, muted)  — Trả emoji 🔇🔈🔉🔊
    └── ApplyWin11Style(hwnd)      — Bo góc + Mica + Dark mode qua DWM API
```

---

## 🔧 Tùy chỉnh nhanh

Mở file `.ahk` bằng bất kỳ text editor nào và chỉnh các giá trị sau:

**Thay đổi bước nhảy âm lượng:**
```autohotkey
!Up::   ChangeVolume(2)   ; ← đổi 2 thành số khác
!Down:: ChangeVolume(-2)
```

**Thay đổi ngưỡng màu:**
```autohotkey
GetVolumeColor(vol, muted) {
    if vol <= 40   ; ← ngưỡng "nhỏ"
        return "27AE60"
    if vol <= 75   ; ← ngưỡng "vừa"
        return "0078D4"
    return "E05C00"  ; ← màu "lớn"
}
```

**Thay đổi thời gian hiện overlay:**
```autohotkey
SetTimer(HideOverlay, -1800)  ; ← 1800ms = 1.8 giây
```

---

## 💡 Ghi chú kỹ thuật

- **`#SingleInstance Force`** — Nếu chạy script lần thứ hai, instance cũ sẽ tự tắt, tránh xung đột.
- **`+E0x20` (WS_EX_TRANSPARENT)** — Overlay không nhận click chuột, click xuyên qua xuống cửa sổ bên dưới.
- **`NoActivate`** trong `Show()` — Cửa sổ hiện ra mà không lấy focus, không làm gián đoạn việc đang làm.
- **`SetTimer(..., -N)`** — Số âm nghĩa là chạy **một lần** sau N millisecond, khác với số dương chạy lặp vô hạn.
- **DWM API** — Tất cả hiệu ứng Win11 (bo góc, Mica, dark mode) được gọi trực tiếp qua `dwmapi.dll`, không dùng thư viện bên ngoài.
