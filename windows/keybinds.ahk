#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%

; Desktop Navigation
#k:: ^#Right
return
#j:: ^#Left
return

; Moving windows between monitors
#+h:: #+Left
return
#+l:: #+Right
return

; Moving windows between desktops
#+j::
  WinGetTitle, Title, A
  WinSet, ExStyle, ^0x80, %Title%
  Send {LWin down}{Ctrl down}{Left}{Ctrl up}{LWin up}
  sleep, 50
  WinSet, ExStyle, ^0x80, %Title%
  WinActivate, %Title%
Return

#+k::
  WinGetTitle, Title, A
  WinSet, ExStyle, ^0x80, %Title%
  Send {LWin down}{Ctrl down}{Right}{Ctrl up}{LWin up}
  sleep, 50
  WinSet, ExStyle, ^0x80, %Title%
  WinActivate, %Title%
Return

; Snapping Windows
#^h:: SendEvent {LWin down}{Left down}
#^l:: SendEvent {LWin down}{Right down}
#^k:: SendEvent {LWin down}{Up down}
#^j:: SendEvent {LWin down}{Down down}

; Maximize/Minimize Window
#m::
WinGet, currentWindow, MinMax, A
if (currentWindow = 1) {
    Send {LWin down}{Down down}
    sleep, 50
    SendInput, {LWin up}{Down up}
} else {
    WinMaximize, A
}
return

; Run WSL
^!t::
Run, wt
return

; Screenshot
#s:: Send {PrintScreen}
return

; Start Menu
#a:: Send {LWin down}{LWin up}
return

; Sleep
#+s::
DllCall("PowrProf\SetSuspendState", "int", 0, "int", 1, "int", 0)
return

; Volume controls
#Up::
	SoundGet, volume
	Send, {volume_up}
	SoundSet, volume + 2
return

#Down::
	SoundGet, volume
	Send, {volume_down}
	SoundSet, volume - 2
return
