#Requires AutoHotkey v2.0
#SingleInstance Force

; ╔══════════════════════════════════════════════════╗
; ║   VolumePro v3 — Windows 11 Flyout Style         ║
; ║   Config-driven blacklist + smart beep           ║
; ╚══════════════════════════════════════════════════╝

; ── Auto-add to Startup on first run ──
StartupShortcut := A_Startup "\VolumePro.lnk"
if !FileExist(StartupShortcut)
    FileCreateShortcut(A_ScriptFullPath, StartupShortcut)

; ========= GLOBAL =========
global mixerGui     := 0
global mixerSlider  := 0
global mixerLabel   := 0
global mixerIcon    := 0
global mixerMuteBtn := 0

global overlayGui   := 0
global overlayBar   := 0
global overlayText  := 0
global helpGui      := 0

global isMixerOpen  := false
global lastVolume   := -1
global lastMuted    := -1

; ── Config globals ──
global CFG_Modifier       := "Ctrl"
global CFG_Step           := 2
global CFG_StepLarge      := 10
global CFG_OverlayMs      := 1800
global CFG_BlacklistExes  := []      ; Array of lowercase exe names
global CFG_BeepEnabled    := true
global CFG_BeepBlockedHz  := 400
global CFG_BeepBlockedMs  := 80
global CFG_BeepLimitHz    := 600
global CFG_BeepLimitMs    := 60

global configPath         := A_ScriptDir "\VolumePro.ini"
global configLastModified := ""

; ── Boot sequence ──
LoadConfig()
InitTray()
InitOverlay()
RegisterHotkeys()
SetTimer(DetectExternalChange, 150)
SetTimer(WatchConfig, 3000)

; ── Show Welcome on first run ──
firstRunFlag := A_ScriptDir "\VolumePro.firstrun"
if !FileExist(firstRunFlag) {
    FileAppend("done", firstRunFlag)
    SetTimer(ShowHelp, -800)   ; short delay so overlay finishes init
}

; ========= CONFIG LOADER =========
LoadConfig() {
    global CFG_Modifier, CFG_Step, CFG_StepLarge, CFG_OverlayMs
    global CFG_BlacklistExes
    global CFG_BeepEnabled, CFG_BeepBlockedHz, CFG_BeepBlockedMs
    global CFG_BeepLimitHz, CFG_BeepLimitMs
    global configPath, configLastModified

    if !FileExist(configPath)
        CreateDefaultConfig()

    configLastModified := FileGetTime(configPath)

    CFG_Modifier     := IniRead(configPath, "Hotkeys", "Modifier",        "Ctrl")
    CFG_Step         := Integer(IniRead(configPath, "Hotkeys", "VolumeStep",      "2"))
    CFG_StepLarge    := Integer(IniRead(configPath, "Hotkeys", "VolumeStepLarge", "10"))
    CFG_OverlayMs    := Integer(IniRead(configPath, "Hotkeys", "OverlayDuration", "1800"))

    CFG_BeepEnabled   := (IniRead(configPath, "Beep", "Enabled",          "true") = "true")
    CFG_BeepBlockedHz := Integer(IniRead(configPath, "Beep", "BlockedFreq",     "400"))
    CFG_BeepBlockedMs := Integer(IniRead(configPath, "Beep", "BlockedDuration", "80"))
    CFG_BeepLimitHz   := Integer(IniRead(configPath, "Beep", "LimitFreq",       "600"))
    CFG_BeepLimitMs   := Integer(IniRead(configPath, "Beep", "LimitDuration",   "60"))

    raw := IniRead(configPath, "Blacklist", "Apps", "")
    CFG_BlacklistExes := []
    for part in StrSplit(raw, ",") {
        trimmed := Trim(part)
        if trimmed != ""
            CFG_BlacklistExes.Push(StrLower(trimmed))
    }

    errors := ValidateConfig()
    if errors.Length > 0 {
        msg := "⚠️ VolumePro — Config errors found:`n`n"
        for e in errors
            msg .= "  • " e "`n"
        msg .= "`nDefaults will be used for invalid values."
        MsgBox(msg, "VolumePro Config Warning", "Icon! T10")
    }
}

; ========= CONFIG VALIDATOR =========
ValidateConfig() {
    global CFG_Modifier, CFG_Step, CFG_StepLarge, CFG_OverlayMs
    global CFG_BeepEnabled, CFG_BeepBlockedHz, CFG_BeepBlockedMs
    global CFG_BeepLimitHz, CFG_BeepLimitMs
    global CFG_BlacklistExes

    errors := []

    ; ── [Hotkeys] ──
    validModifiers := ["alt", "ctrl", "ctrlalt", "winkey"]
    modOk := false
    for m in validModifiers {
        if (StrLower(CFG_Modifier) = m) {
            modOk := true
            break
        }
    }
    if !modOk {
        errors.Push('Modifier "' CFG_Modifier '" is invalid. Use: Alt | Ctrl | CtrlAlt | WinKey')
        CFG_Modifier := "Ctrl"
    }

    if !(CFG_Step >= 1 && CFG_Step <= 50) {
        errors.Push("VolumeStep=" CFG_Step " out of range (1–50). Reset to 2.")
        CFG_Step := 2
    }

    if !(CFG_StepLarge >= 1 && CFG_StepLarge <= 50) {
        errors.Push("VolumeStepLarge=" CFG_StepLarge " out of range (1–50). Reset to 10.")
        CFG_StepLarge := 10
    }

    if CFG_StepLarge <= CFG_Step {
        errors.Push("VolumeStepLarge (" CFG_StepLarge ") must be > VolumeStep (" CFG_Step "). Reset to " (CFG_Step * 5) ".")
        CFG_StepLarge := CFG_Step * 5
    }

    if !(CFG_OverlayMs >= 200 && CFG_OverlayMs <= 10000) {
        errors.Push("OverlayDuration=" CFG_OverlayMs " out of range (200–10000 ms). Reset to 1800.")
        CFG_OverlayMs := 1800
    }

    ; ── [Beep] ──
    if !(CFG_BeepBlockedHz >= 37 && CFG_BeepBlockedHz <= 32767) {
        errors.Push("BlockedFreq=" CFG_BeepBlockedHz " out of range (37–32767 Hz). Reset to 400.")
        CFG_BeepBlockedHz := 400
    }

    if !(CFG_BeepBlockedMs >= 10 && CFG_BeepBlockedMs <= 2000) {
        errors.Push("BlockedDuration=" CFG_BeepBlockedMs " out of range (10–2000 ms). Reset to 80.")
        CFG_BeepBlockedMs := 80
    }

    if !(CFG_BeepLimitHz >= 37 && CFG_BeepLimitHz <= 32767) {
        errors.Push("LimitFreq=" CFG_BeepLimitHz " out of range (37–32767 Hz). Reset to 600.")
        CFG_BeepLimitHz := 600
    }

    if !(CFG_BeepLimitMs >= 10 && CFG_BeepLimitMs <= 2000) {
        errors.Push("LimitDuration=" CFG_BeepLimitMs " out of range (10–2000 ms). Reset to 60.")
        CFG_BeepLimitMs := 60
    }

    ; ── [Blacklist] ──
    for exe in CFG_BlacklistExes {
        if !RegExMatch(exe, "^[\w\-\+\.]+\.exe$")
            errors.Push('Blacklist entry "' exe '" looks invalid (expected: name.exe)')
    }

    return errors
}

; ── Watch config file, auto-reload on change ──
WatchConfig() {
    global configPath, configLastModified
    if !FileExist(configPath)
        return
    newMod := FileGetTime(configPath)
    if (newMod != configLastModified) {
        configLastModified := newMod
        LoadConfig()      ; ValidateConfig() is called inside LoadConfig()
        RegisterHotkeys()
        ShowToast("⚙️  Config reloaded")
    }
}

; ========= DYNAMIC HOTKEY REGISTRATION =========
RegisterHotkeys() {
    global CFG_Modifier, CFG_Step, CFG_StepLarge, CFG_BlacklistExes

    prefix       := ModifierPrefix(CFG_Modifier)
    blacklist    := CFG_BlacklistExes
    stepVal      := CFG_Step
    stepLargeVal := CFG_StepLarge

    ; Clear previously registered hotkeys
    static registered := []
    for hk in registered {
        try Hotkey(hk, "Off")
    }
    registered := []

    ; ── Blacklist check function (closure) ──
    IsBlocked(*) {
        try
            exe := StrLower(WinGetProcessName("A"))
        catch
            return false
        for blocked in blacklist {
            if (exe = blocked)
                return true
        }
        return false
    }

    ; ── Handlers ──
    HK_Up(*) {
        if IsBlocked()
            BeepBlocked()
        else
            ChangeVolume(stepVal)
    }
    HK_Down(*) {
        if IsBlocked()
            BeepBlocked()
        else
            ChangeVolume(-stepVal)
    }
    HK_UpLarge(*) {
        if IsBlocked()
            BeepBlocked()
        else
            ChangeVolume(stepLargeVal)
    }
    HK_DownLarge(*) {
        if IsBlocked()
            BeepBlocked()
        else
            ChangeVolume(-stepLargeVal)
    }
    HK_WheelUp(*) {
        if IsBlocked()
            BeepBlocked()
        else
            ChangeVolume(stepVal)
    }
    HK_WheelDown(*) {
        if IsBlocked()
            BeepBlocked()
        else
            ChangeVolume(-stepVal)
    }
    HK_Mute(*) {
        if IsBlocked()
            BeepBlocked()
        else
            ToggleMute()
    }
    HK_Mixer(*) {
        if IsBlocked()
            BeepBlocked()
        else
            ToggleMixer()
    }
    HK_Reset(*) {
        if IsBlocked()
            BeepBlocked()
        else
            SetVolume(50)
    }

    ; ── Register hotkeys ──
    keys := Map(
        prefix "Up",       HK_Up,
        prefix "Down",     HK_Down,
        "+" prefix "Up",   HK_UpLarge,
        "+" prefix "Down", HK_DownLarge,
        prefix "WheelUp",  HK_WheelUp,
        prefix "WheelDown",HK_WheelDown,
        prefix "m",        HK_Mute,
        prefix "v",        HK_Mixer,
        prefix "r",        HK_Reset,
    )

    for hk, fn in keys {
        try {
            Hotkey(hk, fn, "On")
            registered.Push(hk)
        }
    }
}

ModifierPrefix(mod) {
    switch StrLower(mod) {
        case "alt":     return "!"
        case "ctrl":    return "^"
        case "ctrlalt": return "^!"
        case "winkey":  return "#"
        default:        return "!"
    }
}

; ========= TRAY =========
InitTray() {
    global configPath
    A_TrayMenu.Delete()
    A_TrayMenu.Add("🔊 Volume Mixer",  ToggleMixer)
    A_TrayMenu.Add("🔇 Mute / Unmute", (*) => ToggleMute())
    A_TrayMenu.Add()
    A_TrayMenu.Add("❓ Help / Hotkeys",  (*) => ShowHelp())
    A_TrayMenu.Add()
    A_TrayMenu.Add("⚙️  Edit Config",  (*) => Run('notepad.exe "' configPath '"'))
    A_TrayMenu.Add("🔄 Reload Config", (*) => (LoadConfig(), RegisterHotkeys(), ShowToast("⚙️  Config reloaded")))
    A_TrayMenu.Add()
    A_TrayMenu.Add("❌ Exit",          (*) => ExitApp())
}

; ========= MEDIA KEYS =========
; Media keys — Windows triggers native flyout, we only sync UI
Volume_Up:: {
    Send "{Volume_Up}"
    SetTimer(ShowCurrentVolume, -60)
}
Volume_Down:: {
    Send "{Volume_Down}"
    SetTimer(ShowCurrentVolume, -60)
}
Volume_Mute:: {
    SoundSetMute(-1)
    SetTimer(ShowMuteState, -60)
}

; ========= BEEP =========
BeepBlocked() {
    global CFG_BeepEnabled, CFG_BeepBlockedHz, CFG_BeepBlockedMs
    if CFG_BeepEnabled
        SoundBeep(CFG_BeepBlockedHz, CFG_BeepBlockedMs)
}

BeepLimit() {
    global CFG_BeepEnabled, CFG_BeepLimitHz, CFG_BeepLimitMs
    if CFG_BeepEnabled
        SoundBeep(CFG_BeepLimitHz, CFG_BeepLimitMs)
}

; ========= OVERLAY =========
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
    global overlayGui, overlayBar, overlayText, CFG_OverlayMs

    icon  := GetVolumeIcon(vol, muted)
    label := muted ? "Muted" : vol "%"
    overlayText.Text := icon "  " label

    color := GetVolumeColor(vol, muted)
    overlayBar.Value := vol
    overlayBar.Opt("c" color)
    overlayText.Opt("c" color)

    monH := SysGet(17)
    monW := SysGet(16)
    overlayGui.Show("x" (monW - 330) " y" (monH - 140) " w300 h78 NoActivate")
    SetTimer(HideOverlay, -CFG_OverlayMs)
}

; ── Toast for system notifications ──
ShowToast(msg) {
    global overlayGui, overlayText, overlayBar, CFG_OverlayMs
    overlayText.Text := msg
    overlayText.Opt("cFFFFFF")
    overlayBar.Value := 0
    overlayBar.Opt("c444444")
    monH := SysGet(17)
    monW := SysGet(16)
    overlayGui.Show("x" (monW - 330) " y" (monH - 140) " w300 h78 NoActivate")
    SetTimer(HideOverlay, -CFG_OverlayMs)
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
    prev := GetVolume()
    v    := Max(0, Min(100, v))

    ; Beep when already at limit and still pressing
    if (v = 0 && prev = 0) || (v = 100 && prev = 100)
        BeepLimit()

    SoundSetVolume(v)
    if (v > 0 && SoundGetMute())
        SoundSetMute(0)
    ShowOverlay(v)
    SyncUI()
    UpdateLastState(v, SoundGetMute())
}

ChangeVolume(step) => SetVolume(GetVolume() + step)

ToggleMute() {
    SoundSetMute(-1)
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
        DllCall("dwmapi\DwmSetWindowAttribute",
            "Ptr", hwnd, "UInt", 33, "Int*", 2, "UInt", 4)
        if darkMode
            DllCall("dwmapi\DwmSetWindowAttribute",
                "Ptr", hwnd, "UInt", 20, "Int*", 1, "UInt", 4)
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

    mixerGui := Gui("-Caption +AlwaysOnTop +ToolWindow")
    mixerGui.BackColor := "272727"
    mixerGui.SetFont("s10", "Segoe UI Variable Text")

    color := GetVolumeColor(v, muted)

    mixerGui.AddProgress("x0 y0 w360 h3 c" color " Background" color, 100)

    mixerIcon := mixerGui.AddText("x18 y16 w56 h56 c" color " Center", GetVolumeIcon(v, muted))
    mixerIcon.SetFont("s30", "Segoe UI Emoji")

    mixerLabel := mixerGui.AddText("x82 y22 w120 h30 c" color, (muted ? "Muted" : v "%"))
    mixerLabel.SetFont("s20 bold", "Segoe UI Variable Display")

    subLabel := mixerGui.AddText("x82 y54 w200 cAAAAAA", "System Volume")
    subLabel.SetFont("s9", "Segoe UI Variable Text")

    mixerSlider := mixerGui.AddSlider("x18 y88 w324 h28 Range0-100 NoTicks Thick16 Line2", v)
    mixerGui.AddText("x18 y126 w324 h1 Background3F3F3F", "")

    mixerMuteBtn := mixerGui.AddButton("x18 y136 w158 h32 -Default", (muted ? "  Unmute" : "  Mute"))
    mixerMuteBtn.SetFont("s10", "Segoe UI Variable Text")

    resetBtn := mixerGui.AddButton("x186 y136 w156 h32 -Default", "  Reset to 50%")
    resetBtn.SetFont("s10", "Segoe UI Variable Text")

    mixerSlider.OnEvent("Change", MixerSliderChange)
    mixerMuteBtn.OnEvent("Click", (*) => ToggleMute())
    resetBtn.OnEvent("Click",     (*) => SetVolume(50))
    mixerGui.OnEvent("Close",     (*) => (isMixerOpen := false, mixerGui.Hide()))

    monH := SysGet(17)
    monW := SysGet(16)
    mixerGui.Show("x" (monW - 378) " y" (monH - 210) " w360 h178 NoActivate")
    ApplyWin11Style(mixerGui.Hwnd)

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


; ========= HELP / WELCOME WINDOW =========
ShowHelp(*) {
    global helpGui, CFG_Modifier

    ; Close if already open
    if IsObject(helpGui) {
        try helpGui.Destroy()
    }

    mod := CFG_Modifier

    ; Map modifier display name
    modDisplay := Map("Alt","Alt", "Ctrl","Ctrl", "CtrlAlt","Ctrl+Alt", "WinKey","Win")
    modLabel   := modDisplay.Has(mod) ? modDisplay[mod] : mod

    helpGui := Gui("-Caption +AlwaysOnTop +ToolWindow")
    helpGui.BackColor := "1E1E1E"
    helpGui.SetFont("s10", "Segoe UI Variable Text")

    W := 460   ; window width

    ; ── Accent bar top ──
    helpGui.AddProgress("x0 y0 w" W " h3 c0078D4 Background0078D4", 100)

    ; ── Header ──
    hdr := helpGui.AddText("x0 y12 w" W " h34 cFFFFFF Center", "🔊  VolumePro v3")
    hdr.SetFont("s16 bold", "Segoe UI Variable Display")

    sub := helpGui.AddText("x0 y46 w" W " h20 c888888 Center", "Advanced Volume Controller for Windows 11")
    sub.SetFont("s9", "Segoe UI Variable Text")

    ; ── Divider ──
    helpGui.AddText("x20 y72 w" (W-40) " h1 Background2D2D2D", "")

    ; ── Section: Hotkeys ──
    sec1 := helpGui.AddText("x20 y82 w200 h18 c0078D4", "⌨️  HOTKEYS  (Modifier: " modLabel ")")
    sec1.SetFont("s8 bold", "Segoe UI Variable Text")

    rows := [
        [modLabel " + ↑ / ↓",          "Volume ±" CFG_Step "%"],
        ["Shift + " modLabel " + ↑ / ↓","Volume ±" CFG_StepLarge "%"],
        [modLabel " + Scroll",          "Volume ±" CFG_Step "% (mouse wheel)"],
        [modLabel " + M",               "Toggle Mute"],
        [modLabel " + V",               "Open / Close Mixer"],
        [modLabel " + R",               "Reset to 50%"],
        ["Volume Up / Down / Mute",     "Media keys (native flyout)"],
    ]

    y := 104
    for row in rows {
        keyCol := helpGui.AddText("x28 y" y " w170 h18 cCCCCCC", row[1])
        keyCol.SetFont("s9", "Segoe UI Variable Text")
        helpGui.AddText("x200 y" y " w" (W-220) " h18 c888888", row[2])
        y += 20
    }

    ; ── Divider ──
    helpGui.AddText("x20 y" (y+4) " w" (W-40) " h1 Background2D2D2D", "")
    y += 14

    ; ── Section: Tray ──
    sec2 := helpGui.AddText("x20 y" y " w200 h18 c0078D4", "🖱️  SYSTEM TRAY  (right-click icon)")
    sec2.SetFont("s8 bold", "Segoe UI Variable Text")
    y += 20

    trayRows := [
        ["Volume Mixer",    "Open visual mixer panel"],
        ["Mute / Unmute",   "Toggle system mute"],
        ["Help / Hotkeys",  "Show this window"],
        ["Edit Config",     "Open VolumePro.ini in Notepad"],
        ["Reload Config",   "Apply config changes immediately"],
    ]

    for row in trayRows {
        col1 := helpGui.AddText("x28 y" y " w140 h18 cCCCCCC", row[1])
        col1.SetFont("s9", "Segoe UI Variable Text")
        helpGui.AddText("x170 y" y " w" (W-190) " h18 c888888", row[2])
        y += 20
    }

    ; ── Divider ──
    helpGui.AddText("x20 y" (y+4) " w" (W-40) " h1 Background2D2D2D", "")
    y += 14

    ; ── Section: Beep guide ──
    sec3 := helpGui.AddText("x20 y" y " w200 h18 c0078D4", "🔔  BEEP GUIDE")
    sec3.SetFont("s8 bold", "Segoe UI Variable Text")
    y += 20

    beepRows := [
        ["Low beep (400 Hz)",  "Hotkey blocked — current app is in blacklist"],
        ["High beep (600 Hz)", "Volume at limit (0% or 100%)"],
    ]

    for row in beepRows {
        col1 := helpGui.AddText("x28 y" y " w160 h18 cCCCCCC", row[1])
        col1.SetFont("s9", "Segoe UI Variable Text")
        helpGui.AddText("x190 y" y " w" (W-210) " h18 c888888", row[2])
        y += 20
    }

    ; ── Divider ──
    helpGui.AddText("x20 y" (y+6) " w" (W-40) " h1 Background2D2D2D", "")
    y += 16

    ; ── Footer buttons ──
    editBtn := helpGui.AddButton("x20 y" y " w" (W//2 - 26) " h30 -Default", "⚙️  Edit Config")
    editBtn.SetFont("s9", "Segoe UI Variable Text")

    closeBtn := helpGui.AddButton("x" (W//2 + 6) " y" y " w" (W//2 - 26) " h30 -Default", "✓  Got it!")
    closeBtn.SetFont("s9 bold", "Segoe UI Variable Text")

    y += 46

    ; ── Events ──
    editBtn.OnEvent("Click",  (*) => Run('notepad.exe "' A_ScriptDir '\VolumePro.ini"'))
    closeBtn.OnEvent("Click", (*) => helpGui.Hide())
    helpGui.OnEvent("Close",  (*) => helpGui.Hide())

    ; ── Position — center of screen ──
    monW := SysGet(16)
    monH := SysGet(17)
    helpGui.Show("x" ((monW - W) // 2) " y" ((monH - y) // 2) " w" W " h" y)
    ApplyWin11Style(helpGui.Hwnd)

    try {
        DllCall("uxtheme\SetWindowTheme", "Ptr", editBtn.Hwnd,  "Str", "DarkMode_Explorer", "Ptr", 0)
        DllCall("uxtheme\SetWindowTheme", "Ptr", closeBtn.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
    }
}

; ========= DEFAULT CONFIG CREATOR =========
CreateDefaultConfig() {
    global configPath
    defaultIni :=
    (
"; VolumePro v3 — Configuration File`n"
"; Edit this file — the script auto-reloads within 3 seconds.`n`n"
"[Hotkeys]`n"
"; Valid modifiers: Alt | Ctrl | CtrlAlt | WinKey`n"
"Modifier = Ctrl`n"
"VolumeStep = 2`n"
"VolumeStepLarge = 10`n"
"OverlayDuration = 1800`n`n"
"[Blacklist]`n"
"Apps = msedge.exe, firefox.exe, brave.exe, opera.exe, vivaldi.exe, Code.exe, idea64.exe, webstorm64.exe, phpstorm64.exe, sublime_text.exe, notepad++.exe, cursor.exe, WindowsTerminal.exe, pwsh.exe, cmd.exe, mintty.exe, explorer.exe, slack.exe, discord.exe, figma.exe`n`n"
"[Beep]`n"
"Enabled = true`n"
"BlockedFreq = 400`n"
"BlockedDuration = 80`n"
"LimitFreq = 600`n"
"LimitDuration = 60`n"
    )
    FileAppend(defaultIni, configPath, "UTF-8")
}
