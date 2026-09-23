' Silent launcher for KfupmSorter.ps1 - shows no window at all.
Option Explicit
Dim sh, dir, cmd
Set sh = CreateObject("WScript.Shell")
dir = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & dir & "KfupmSorter.ps1"" -Quiet"
sh.Run cmd, 0, False
