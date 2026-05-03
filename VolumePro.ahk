#Requires AutoHotkey v2.0
#SingleInstance Force

; ========= GLOBAL =========
global mixerGui := 0
global mixerSlider := 0
global mixerLabel := 0

global overlayGui := 0
global overlayBar := 0
global overlayText := 0

global isMixerOpen := false

InitTray()
InitOverlay()

; Sync realtime (quan trọng)
SetTimer(SyncUI, 200)

; ========= TRAY =========
InitTray() {
    A_TrayMenu.Delete()
    A_TrayMenu.Add("🎛 Mixer", ToggleMixer)
    A_TrayMenu.Add("❌ Exit", (*) => ExitApp())
}

; ========= HOTKEY =========
!Up::ChangeVolume(2)
!Down::ChangeVolume(-2)

+!Up::ChangeVolume(10)
+!Down::ChangeVolume(-10)

!WheelUp::ChangeVolume(2)
!WheelDown::ChangeVolume(-2)

!m::ToggleMute()
!v::ToggleMixer()
!r::SetVolume(50)

; ========= OVERLAY =========
InitOverlay() {
    global overlayGui, overlayBar, overlayText

    overlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    overlayGui.BackColor := "1e1e1e"

    overlayBar := overlayGui.AddProgress("w260 h12 c00ffcc Background333333", 50)
    overlayText := overlayGui.AddText("cffffff Center w260", "")
}

ShowOverlay(vol) {
    global overlayGui, overlayBar, overlayText

    overlayBar.Value := vol
    overlayText.Text := "🔊 " vol "%"

    overlayGui.Show("xCenter y80 NoActivate")
    SetTimer(HideOverlay, -600)
}

HideOverlay() {
    global overlayGui
    overlayGui.Hide()
}

; ========= AUDIO =========
GetVolume() {
    return Round(SoundGetVolume())
}

SetVolume(v) {
    SoundSetVolume(v)
    ShowOverlay(v)
    SyncUI()
}

ChangeVolume(step) {
    v := GetVolume()
    v += step

    if (v > 100)
        v := 100
    if (v < 0)
        v := 0

    SetVolume(v)
}

ToggleMute() {
    Send "{Volume_Mute}"
    SetTimer(SyncUI, -50)
}

; ========= SYNC UI =========
SyncUI() {
    global mixerSlider, mixerLabel

    if (mixerSlider) {
        v := GetVolume()
        mixerSlider.Value := v
        mixerLabel.Text := v "%"
    }
}

; ========= MIXER =========
ToggleMixer(*) {
    global isMixerOpen, mixerGui
    isMixerOpen := !isMixerOpen

    if isMixerOpen
        OpenMixer()
    else if mixerGui
        mixerGui.Hide()
}

OpenMixer() {
    global mixerGui, mixerSlider, mixerLabel

    mixerGui := Gui("+Resize", "🎛 Volume Control")
    mixerGui.SetFont("s10", "Segoe UI")

    mixerSlider := mixerGui.AddSlider("x20 y40 w300 Range0-100", GetVolume())
    mixerLabel  := mixerGui.AddText("x330 y40 w60", GetVolume() "%")

    mixerSlider.OnEvent("Change", (*) => (
        val := mixerSlider.Value,
        SetVolume(val),
        mixerLabel.Text := val "%"
    ))

    mixerGui.Show("w420 h120")
}