' Opens the KFUPM Sorter window without a console window behind it.
Option Explicit
Dim sh, dir, cmd
Set sh = CreateObject("WScript.Shell")
dir = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
cmd = "powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & dir & "Picker.ps1"""
sh.Run cmd, 0, False
