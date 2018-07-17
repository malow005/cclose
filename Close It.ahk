#NoEnv
#SingleInstance ignore ; allow only one instance of this script to be running

; add tray menu
Menu, Tray, Icon, , , 1
Menu, Tray, NoStandard
Menu, Tray, Add, Autostart, AutostartProgram
Menu, Tray, Add, Suspend, SuspendProgram
Menu, Tray, Add
Menu, Tray, Add, Help, HelpMsg
Menu, Tray, Add, Exit, ExitProgram
Menu, Tray, Tip, Close It

SplitPath, A_Scriptname, , , , ScriptNameNoExt
IniDir := A_AppDataCommon . "\" . ScriptNameNoExt
IniFile := IniDir . "\" . ScriptNameNoExt . ".ini"
IniRead, IsAutostart, %IniFile%, setting, autostart ; retrieve autostart setting, the result can be on of the following: true/false/ERROR
IsAutostart := %IsAutostart% ; ensure the keyword true/false is saved, instead of the string "true/false"

if A_IsAdmin ; if run as administrator
{
	if (IsAutostart = true)
	{
		RegWrite, REG_SZ, HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run, %ScriptNameNoExt%, %A_ScriptFullPath% ; enable autostart
	}
	else if (IsAutostart = false)
	{
		RegDelete, HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run, %ScriptNameNoExt% ; disable autostart
	}
	; else in case of ERROR, do nothing
}

; update Autostart menu
RegRead, RegValue, HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run, %ScriptNameNoExt% ; retrieve autostart status
if (RegValue=A_ScriptFullPath) ; if autostart is enabled
{
	Menu, Tray, Check, Autostart ; check Autostart menu
	IsAutostart := true
}
else
{
	Menu, Tray, Uncheck, Autostart ; uncheck Autostart menu
	IsAutostart := false
}

; update autostart setting
if !InStr(FileExist(IniDir), "D") ; ensure IniDir exists
{
	FileCreateDir, %IniDir%
}
if IsAutostart
{
	IniWrite, true, %IniFile%, setting, autostart
}
else
{
	IniWrite, false, %IniFile%, setting, autostart
}

Return ; end of auto-execute section

AutostartProgram:
if A_IsAdmin ; if run as administrator, update menu, setting file, and registry
{
	if IsAutostart
	{
		Menu, Tray, Uncheck, Autostart
		IniWrite, false, %IniFile%, setting, autostart
		RegDelete, HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run, %ScriptNameNoExt% ; disable autostart
		IsAutostart := false
	}
	else
	{
		Menu, Tray, Check, Autostart
		IniWrite, true, %IniFile%, setting, autostart
		RegWrite, REG_SZ, HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run, %ScriptNameNoExt%, %A_ScriptFullPath% ; enable autostart
		IsAutostart := true
	}
}
else ; else update setting file only
{
	if IsAutostart
	{
		IniWrite, false, %IniFile%, setting, autostart
	}
	else
	{
		IniWrite, true, %IniFile%, setting, autostart
	}
}

; try restart the script and run as administrator
; https://autohotkey.com/docs/commands/Run.htm#RunAs
full_command_line := DllCall("GetCommandLine", "str")
if !(A_IsAdmin or RegExMatch(full_command_line, " /restart(?!\S)"))
{
	try
	{
		if A_IsCompiled
		{
			Run *RunAs "%A_ScriptFullPath%" /restart
		}
		else
		{
			Run *RunAs "%A_AhkPath%" /restart "%A_ScriptFullPath%"
		}
		ExitApp
	}
}

; if run as administrator failed, rollback the autostart setting
if !A_IsAdmin
{
	if IsAutostart
	{
		IniWrite, true, %IniFile%, setting, autostart
	}
	else
	{
		IniWrite, false, %IniFile%, setting, autostart
	}
}
Return

SuspendProgram:
Menu, Tray, ToggleCheck, Suspend
Suspend, Toggle
Return

HelpMsg:
MsgBox, 0, Help,
(
Middle click 	+ title bar 	= close window.
Right click 	+ title bar 	= minize window.
Hold left click 	+ title bar 	= toggle window always on top.
Double press 	+ Esc key  	= close active window.
Right click 	+ taskbar button 	= pointer moves to "Close window".
)
Return

ExitProgram:
ExitApp

RemoveToolTip:
SetTimer, RemoveToolTip, Off
ToolTip
Return

MouseIsOver(WinTitle)
{
	MouseGetPos, , , win
	Return, WinExist(WinTitle . " ahk_id " . win)
}

MouseIsOverTitlebar()
{
	static WM_NCHITTEST := 0x84, HTCAPTION := 2
	CoordMode, Mouse, Screen
	MouseGetPos, x, y, win
	if WinExist("ahk_class Shell_TrayWnd ahk_id " win) || WinExist("ahk_class Chrome_WidgetWin_1 ahk_id " win) || WinExist("ahk_class MozillaWindowClass ahk_id " win) ; exclude taskbar, Chrome, and Firefox
	{
		Return
	}
	SendMessage, WM_NCHITTEST, , x | (y << 16), , ahk_id %win%
	WinExist("ahk_id " win) ; set Last Found Window for convenience
	Return, ErrorLevel = HTCAPTION
}

#If MouseIsOver("ahk_class Shell_TrayWnd") ; apply the following hotkey only when the mouse is over the taskbar
~RButton:: ; when right clicked
Sleep 500 ; wait for the Jump List to pop up (if clicked on apps)
if WinActive("ahk_class Windows.UI.Core.CoreWindow") ; if Jump List pops up
{
	WinGetPos, , , width, height, A ; get active window (Jump List) position
	MouseMove, (width - 128), (height - 24), 1 ; move mouse to the bottom of the Jump List (Close window)
}
Return

; https://autohotkey.com/board/topic/82066-minimize-by-right-click-titlebar-close-by-middle-click/#entry521659
#If MouseIsOverTitlebar() ; apply the following hotkey only when the mouse is over title bars
RButton::WinMinimize
MButton::WinClose
~LButton::
CoordMode, Mouse, Screen
MouseGetPos, xOld, yOld
WinGet, ExStyle, ExStyle ; get extended window style
if (ExStyle & 0x8) ; 0x8 is WS_EX_TOPMOST
{
	ExStyle = Not always on top
}
else
{
	ExStyle = Always on top
}
KeyWait, LButton, T1 ; wait for left mouse button to release with timeout set to 1 second
MouseGetPos, xNew, yNew
if % (xOld == xNew) && (yOld == yNew) && ErrorLevel ; if mouse did not move and long clicked
{
	Winset, Alwaysontop, Toggle, A ; toggle always on top
	ToolTip, %ExStyle%, 7, -25 ; display a tooltip with current topmost status
	SetTimer, RemoveToolTip, 1000 ; remove the tooltip after 1 second
}
Return

#If ; apply the following hotkey with no conditions
~Esc::
if (A_TimeSincePriorHotkey < 400) and (A_PriorHotkey = "~Esc") ; if double press Esc
{
	KeyWait, Esc ; wait for Esc to be released
	WinGetClass, class, A
	if class in Shell_TrayWnd,Progman,WorkerW
	{
		Return ; do nothing if the active window is taskbar or desktop
	}
	WinClose, A ; close active window
}
Return
