#Requires AutoHotkey v2.0
#SingleInstance Force

; ╔══════════════════════════════════════════════════╗
; ║   VolumePro v3 — Windows 11 Flyout Style         ║
; ╚══════════════════════════════════════════════════╝

; ========= GLOBAL =========
global mixerGui     := 0
global mixerSlider  := 0
global mixerLabel   := 0
global mixerIcon    := 0
global mixerMuteBtn := 0

global overlayGui   := 0
global overlayBar   := 0
global overlayText  := 0

global isMixerOpen  := false
global lastVolume   := -1
global lastMuted    := -1

InitTray()
InitOverlay()
SetTimer(DetectExternalChange, 150)

; ========= TRAY =========
InitTray() {
    A_TrayMenu.Delete()
    A_TrayMenu.Add("🔊 Volume Mixer", ToggleMixer)
    A_TrayMenu.Add("🔇 Mute / Unmute", (*) => ToggleMute())
    A_TrayMenu.Add()
    A_TrayMenu.Add("❌ Exit", (*) => ExitApp())
}

; ========= HOTKEYS =========

; Phím media — Windows tự trigger flyout gốc, ta chỉ sync UI
Volume_Up:: {
    Send "{Volume_Up}"
    SetTimer(ShowCurrentVolume, -60)
}

Volume_Down:: {
    Send "{Volume_Down}"
    SetTimer(ShowCurrentVolume, -60)
}

Volume_Mute:: {
    Send "{Volume_Mute}"
    SetTimer(ShowMuteState, -60)
}

; Phím tắt tùy chỉnh — dùng overlay riêng
!Up::        ChangeVolume(2)
!Down::      ChangeVolume(-2)
+!Up::       ChangeVolume(10)
+!Down::     ChangeVolume(-10)
!WheelUp::   ChangeVolume(2)
!WheelDown:: ChangeVolume(-2)
!m::         ToggleMute()
!v::         ToggleMixer()
!r::         SetVolume(50)

; ========= OVERLAY (chỉ dùng cho hotkey tùy chỉnh) =========
InitOverlay() {
    global overlayGui, overlayBar, overlayText

    overlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    overlayGui.BackColor := "1F1F1F"

    overlayText := overlayGui.AddText("x0 y14 w300 h36 cFFFFFF Center", "")
    overlayText.SetFont("s15 bold", "Segoe UI Variable Display")

    overlayBar := overlayGui.AddProgress("x24 y58 w252 h5 c0078D4 Background3D3D3D", 50)

    ApplyWin11Style(overlayGui.Hwnd)
}

ShowOverlay(vol, muted := false) {
    global overlayGui, overlayBar, overlayText

    icon  := GetVolumeIcon(vol, muted)
    label := muted ? "Muted" : vol "%"
    overlayText.Text := icon "  " label

    color := GetVolumeColor(vol, muted)
    overlayBar.Value := vol
    overlayBar.Opt("c" color)
    overlayText.Opt("c" color)

    ; Góc dưới phải màn hình, cách taskbar
    monH := SysGet(17)
    monW := SysGet(16)
    overlayGui.Show("x" (monW - 330) " y" (monH - 140) " w300 h78 NoActivate")
    SetTimer(HideOverlay, -1800)
}

HideOverlay() {
    global overlayGui
    overlayGui.Hide()
}

ShowCurrentVolume() {
    v     := GetVolume()
    muted := SoundGetMute()
    SyncUI()
    UpdateLastState(v, muted)
}

ShowMuteState() => ShowCurrentVolume()

; ========= AUDIO =========
GetVolume() => Round(SoundGetVolume())

SetVolume(v) {
    v := Max(0, Min(100, v))
    SoundSetVolume(v)
    if (v > 0 && SoundGetMute())
        SoundSetMute(0)
    ShowOverlay(v)
    SyncUI()
    UpdateLastState(v, SoundGetMute())
}

ChangeVolume(step) => SetVolume(GetVolume() + step)

ToggleMute() {
    Send "{Volume_Mute}"
    SetTimer(() => (ShowCurrentVolume(), SyncUI()), -60)
}

UpdateLastState(v, muted) {
    global lastVolume, lastMuted
    lastVolume := v
    lastMuted  := muted
}

DetectExternalChange() {
    global lastVolume, lastMuted
    v     := GetVolume()
    muted := SoundGetMute()
    if (v != lastVolume || muted != lastMuted) {
        lastVolume := v
        lastMuted  := muted
        SyncUI()
    }
}

; ========= HELPERS =========

; ── Ngưỡng màu ──────────────────────────────────────
;   Muted / 0        → xám       #888888
;   1  – 40  (nhỏ)  → xanh lá   #27AE60
;   41 – 75  (vừa)  → xanh Win11 #0078D4
;   76 – 100 (lớn)  → đỏ cam    #E05C00
GetVolumeColor(vol, muted) {
    if muted || vol = 0
        return "888888"
    if vol <= 40
        return "27AE60"
    if vol <= 75
        return "0078D4"
    return "E05C00"
}

GetVolumeIcon(vol, muted) {
    if muted || vol = 0
        return "🔇"
    if vol <= 40
        return "🔈"
    if vol <= 75
        return "🔉"
    return "🔊"
}

ApplyWin11Style(hwnd, darkMode := true) {
    try {
        ; Bo góc tròn
        DllCall("dwmapi\DwmSetWindowAttribute",
            "Ptr", hwnd, "UInt", 33, "Int*", 2, "UInt", 4)
        ; Dark mode title bar
        if darkMode
            DllCall("dwmapi\DwmSetWindowAttribute",
                "Ptr", hwnd, "UInt", 20, "Int*", 1, "UInt", 4)
        ; Mica Alt effect (Windows 11 22H2+, value=4)
        DllCall("dwmapi\DwmSetWindowAttribute",
            "Ptr", hwnd, "UInt", 38, "Int*", 4, "UInt", 4)
    }
}

; ========= SYNC UI =========
SyncUI() {
    global mixerSlider, mixerLabel, mixerIcon, mixerMuteBtn
    if !mixerSlider
        return
    v     := GetVolume()
    muted := SoundGetMute()
    color := GetVolumeColor(v, muted)
    mixerSlider.Value := v
    mixerLabel.Text   := (muted ? "Muted" : v "%")
    mixerLabel.Opt("c" color)
    if mixerIcon {
        mixerIcon.Text := GetVolumeIcon(v, muted)
        mixerIcon.Opt("c" color)
    }
    if mixerMuteBtn
        mixerMuteBtn.Text := (muted ? "  Unmute" : "  Mute")
}

; ========= MIXER — Windows 11 Flyout Style =========
ToggleMixer(*) {
    global isMixerOpen, mixerGui
    if isMixerOpen {
        isMixerOpen := false
        if mixerGui
            mixerGui.Hide()
    } else {
        isMixerOpen := true
        OpenMixer()
    }
}

OpenMixer() {
    global mixerGui, mixerSlider, mixerLabel, mixerIcon, mixerMuteBtn, isMixerOpen

    v     := GetVolume()
    muted := SoundGetMute()

    ; Không có title bar — giống flyout Win11
    mixerGui := Gui("-Caption +AlwaysOnTop +ToolWindow")
    mixerGui.BackColor := "272727"
    mixerGui.SetFont("s10", "Segoe UI Variable Text")

    color := GetVolumeColor(v, muted)

    ; ── Dải màu accent ở đỉnh ──
    accentBar := mixerGui.AddProgress("x0 y0 w360 h3 c" color " Background" color, 100)

    ; ── Icon speaker lớn ──
    mixerIcon := mixerGui.AddText("x18 y16 w56 h56 c" color " Center", GetVolumeIcon(v, muted))
    mixerIcon.SetFont("s30", "Segoe UI Emoji")

    ; ── Label % + tên ──
    mixerLabel := mixerGui.AddText("x82 y22 w120 h30 c" color, (muted ? "Muted" : v "%"))
    mixerLabel.SetFont("s20 bold", "Segoe UI Variable Display")

    subLabel := mixerGui.AddText("x82 y54 w200 cAAAAAA", "System Volume")
    subLabel.SetFont("s9", "Segoe UI Variable Text")

    ; ── Slider ──
    mixerSlider := mixerGui.AddSlider("x18 y88 w324 h28 Range0-100 NoTicks Thick16 Line2", v)

    ; ── Separtor ──
    mixerGui.AddText("x18 y126 w324 h1 Background3F3F3F", "")

    ; ── Nút Mute + Reset ──
    mixerMuteBtn := mixerGui.AddButton("x18 y136 w158 h32 -Default", (muted ? "  Unmute" : "  Mute"))
    mixerMuteBtn.SetFont("s10", "Segoe UI Variable Text")

    resetBtn := mixerGui.AddButton("x186 y136 w156 h32 -Default", "  Reset to 50%")
    resetBtn.SetFont("s10", "Segoe UI Variable Text")

    ; ── Events ──
    mixerSlider.OnEvent("Change", MixerSliderChange)
    mixerMuteBtn.OnEvent("Click", (*) => ToggleMute())
    resetBtn.OnEvent("Click",     (*) => SetVolume(50))
    mixerGui.OnEvent("Close",     (*) => (isMixerOpen := false, mixerGui.Hide()))

    ; ── Căn góc dưới phải (giống Win11) ──
    monH := SysGet(17)
    monW := SysGet(16)
    mixerGui.Show("x" (monW - 378) " y" (monH - 210) " w360 h178 NoActivate")

    ; ── Win11 visual style ──
    ApplyWin11Style(mixerGui.Hwnd)

    ; Dark theme cho button
    try {
        DllCall("uxtheme\SetWindowTheme", "Ptr", mixerMuteBtn.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        DllCall("uxtheme\SetWindowTheme", "Ptr", resetBtn.Hwnd,     "Str", "DarkMode_Explorer", "Ptr", 0)
    }
}

MixerSliderChange(*) {
    global mixerSlider, mixerLabel, mixerIcon, mixerMuteBtn
    val   := mixerSlider.Value
    color := GetVolumeColor(val, false)
    SoundSetVolume(val)
    if (val > 0 && SoundGetMute())
        SoundSetMute(0)
    mixerLabel.Text   := val "%"
    mixerLabel.Opt("c" color)
    mixerIcon.Text    := GetVolumeIcon(val, false)
    mixerIcon.Opt("c" color)
    mixerMuteBtn.Text := "  Mute"
}
