<#
    KFUPM Sorter engine  -  sorts the Downloads folder by course, custom filter and file type.
    Settings live in %APPDATA%\KFUPM Sorter\rules.json and are written by the app window.

    Usage:
      .\KfupmSorter.ps1            sort once, now
      .\KfupmSorter.ps1 -Preview   show what would move, move nothing
      .\KfupmSorter.ps1 -Install   run automatically every minute (scheduled task)
      .\KfupmSorter.ps1 -Uninstall stop running automatically
      .\KfupmSorter.ps1 -Status    show whether the scheduled task is alive
      .\KfupmSorter.ps1 -Watch     stay open and check every 15s (manual use)
#>
[CmdletBinding()]
param(
    [switch]$Watch,
    [switch]$Preview,
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Status,
    [switch]$Quiet,
    [int]$IntervalSeconds = 15
)

$ErrorActionPreference = 'Stop'
$ScriptPath  = $MyInvocation.MyCommand.Path
$ScriptDir   = Split-Path -Parent $ScriptPath          # program files (read-only)
$DataDir     = Join-Path $env:APPDATA 'KFUPM Sorter'   # user settings (writable)
if (-not (Test-Path -LiteralPath $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }
$Root        = Join-Path $env:USERPROFILE 'Downloads'  # default target, overridden by rules.json
$RulesPath   = Join-Path $DataDir 'rules.json'
$LogPath     = Join-Path $DataDir 'sorter.log'
$HeartPath   = Join-Path $DataDir 'lastrun.txt'
$TaskName    = 'KFUPM Sorter'

function Say { param([string]$Text) if (-not $Quiet) { Write-Host $Text } }

function Write-Log {
    param([string]$Message)
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    try { Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8 } catch { }
}

function Get-Rules {
    if (-not (Test-Path -LiteralPath $RulesPath)) {
        throw 'No settings yet. Open KFUPM Sorter from the Start menu and pick your courses.'
    }
    $r = Get-Content -LiteralPath $RulesPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($r.watchFolder -and (Test-Path -LiteralPath $r.watchFolder)) {
        $script:Root = $r.watchFolder
    }
    return $r
}

function Test-FileReady {
    param([string]$Path)
    try {
        $fs = [System.IO.File]::Open($Path, 'Open', 'ReadWrite', 'None')
        $fs.Close(); $fs.Dispose()
        return $true
    } catch { return $false }
}

function Get-UniquePath {
    param([string]$Dir, [string]$Name)
    $base = [System.IO.Path]::GetFileNameWithoutExtension($Name)
    $ext  = [System.IO.Path]::GetExtension($Name)
    $candidate = Join-Path $Dir $Name
    $i = 1
    while (Test-Path -LiteralPath $candidate) {
        $candidate = Join-Path $Dir ('{0} ({1}){2}' -f $base, $i, $ext)
        $i++
    }
    return $candidate
}

function Get-Destination {
    param($File, $Rules)
    # custom filters first (your own keywords, e.g. a competition or a club)
    foreach ($rule in @($Rules.customRules)) {
        if (-not $rule) { continue }
        foreach ($pat in $rule.patterns) {
            if ($File.Name -match $pat) { return $rule.folder }
        }
    }
    foreach ($rule in $Rules.courseRules) {
        foreach ($pat in $rule.patterns) {
            if ($File.Name -match $pat) { return $rule.folder }
        }
    }
    if ($Rules.sortByTypeIfNoCourseMatch) {
        $ext = $File.Extension.ToLower()
        foreach ($rule in $Rules.typeRules) {
            if ($rule.extensions -contains $ext) { return $rule.folder }
        }
        # nothing matched: optional catch-all bucket
        if ($Rules.otherFolder -and $ext -ne '') { return $Rules.otherFolder }
    }
    return $null
}

function Invoke-SortOnce {
    param([switch]$DryRun)
    $rules   = Get-Rules
    $skipExt = @($rules.skipExtensions)
    $ignore  = @($rules.ignoreNames)
    $minAge  = [int]$rules.minAgeSeconds
    $count   = 0

    foreach ($f in (Get-ChildItem -LiteralPath $Root -File -Force)) {
        if ($ignore -contains $f.Name)                                { continue }
        if ($f.Name.StartsWith('~$'))                                 { continue }
        if ($f.Attributes -band [IO.FileAttributes]::System)          { continue }
        if ($skipExt -contains $f.Extension.ToLower())                { continue }
        if (((Get-Date) - $f.LastWriteTime).TotalSeconds -lt $minAge) { continue }
        if (-not (Test-FileReady $f.FullName))                        { continue }

        $target = Get-Destination -File $f -Rules $rules
        if (-not $target) { continue }

        if ($DryRun) {
            Say ('  {0,-55} ->  {1}' -f $f.Name, $target)
            $count++
            continue
        }

        $destDir = Join-Path $Root $target
        if (-not (Test-Path -LiteralPath $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        $destPath = Get-UniquePath -Dir $destDir -Name $f.Name
        try {
            Move-Item -LiteralPath $f.FullName -Destination $destPath
            Write-Log ('MOVED   {0}  ->  {1}' -f $f.Name, $target)
            Say ('  {0,-55} ->  {1}' -f $f.Name, $target)
            $count++
        } catch {
            Write-Log ('FAILED  {0}  :  {1}' -f $f.Name, $_.Exception.Message)
        }
    }

    if (-not $DryRun) {
        try {
            Set-Content -LiteralPath $HeartPath -Encoding UTF8 -Value (
                'last run : {0}{1}moved    : {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), [Environment]::NewLine, $count)
        } catch { }
    }
    return $count
}

# the old zip version registered its own task; two sorters must never run side by side
$LegacyTasks = @('Downloads AutoSorter')
# When the old task cannot be deleted without administrator rights, switch it off instead:
# its launcher (the old run-hidden.vbs in Downloads) is replaced by one that does nothing.
function Disable-LegacyLauncher {
    param([string]$Name)
    try {
        $t = Get-ScheduledTask -TaskName $Name -ErrorAction Stop
        foreach ($a in @($t.Actions)) {
            $m = [regex]::Match([string]$a.Arguments, '"([^"]+\.vbs)"')
            if (-not $m.Success) { continue }
            $vbs = $m.Groups[1].Value
            if (-not (Test-Path -LiteralPath $vbs)) { continue }
            if ((Get-Content -LiteralPath $vbs -Raw) -notmatch 'Sort-Downloads\.ps1') { continue }
            Set-Content -LiteralPath $vbs -Value "' Retired: KFUPM Sorter is now an installed app. This old launcher does nothing." -Encoding ASCII
            Write-Log ('Switched off the older task "' + $Name + '": its launcher now does nothing.')
        }
    } catch { Write-Log ('Could not switch off the older task: ' + $_.Exception.Message) }
}

function Remove-LegacyTasks {
    foreach ($old in $LegacyTasks) {
        try {
            if (Get-ScheduledTask -TaskName $old -ErrorAction SilentlyContinue) {
                Stop-ScheduledTask -TaskName $old -ErrorAction SilentlyContinue
                Unregister-ScheduledTask -TaskName $old -Confirm:$false -ErrorAction Stop
                Write-Log ('Removed the older task "' + $old + '".')
                Write-Host ('Removed the older task "' + $old + '".')
            }
        } catch {
            $r = Invoke-Schtasks ('/Delete /F /TN "' + $old + '"')
            if ($r.Code -ne 0) {
                $why = 'Could not remove the older task "' + $old + '": ' + $_.Exception.Message.Trim() + ' | schtasks: ' + $r.Text
                Write-Host $why
                Write-Log $why
                Disable-LegacyLauncher $old
            }
        }
    }
}

function Invoke-Schtasks {
    # schtasks.exe with a hand-built argument string (PowerShell 5.1 mangles quotes inside native arguments)
    param([string]$Arguments)
    $p = Start-Process -FilePath 'schtasks.exe' -ArgumentList $Arguments -NoNewWindow -Wait -PassThru `
                       -RedirectStandardOutput (Join-Path $env:TEMP 'kfupm-schtasks-out.txt') `
                       -RedirectStandardError  (Join-Path $env:TEMP 'kfupm-schtasks-err.txt')
    $msg = ''
    foreach ($x in @('kfupm-schtasks-out.txt', 'kfupm-schtasks-err.txt')) {
        $fp = Join-Path $env:TEMP $x
        if (Test-Path -LiteralPath $fp) { $msg += ((Get-Content -LiteralPath $fp -Raw -ErrorAction SilentlyContinue) + ' ') }
    }
    return [pscustomobject]@{ Code = $p.ExitCode; Text = $msg.Trim() }
}

function Install-Task {
    Remove-LegacyTasks
    $vbs = Join-Path $ScriptDir 'run-hidden.vbs'
    if (-not (Test-Path -LiteralPath $vbs)) { throw 'run-hidden.vbs is missing from the app folder.' }
    $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

    # wscript shows no window at all (powershell -WindowStyle Hidden still flashes a console)
    $action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('"' + $vbs + '"')

    # The task belongs to the current user only. A logon trigger for "any user" needs
    # administrator rights and fails with "Access is denied", so the trigger names this user.
    # RepetitionDuration MUST be explicit - leaving it out makes some Windows builds
    # register the task but never repeat it.
    $tLogon  = New-ScheduledTaskTrigger -AtLogOn -User $user
    $tRepeat = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
                    -RepetitionInterval (New-TimeSpan -Minutes 1) `
                    -RepetitionDuration (New-TimeSpan -Days 3650)
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                    -StartWhenAvailable -MultipleInstances IgnoreNew -Hidden `
                    -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
    try {
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($tLogon, $tRepeat) `
                               -Principal $principal -Settings $settings `
                               -Description 'KFUPM Sorter: sorts new files in your Downloads folder.' -Force -ErrorAction Stop | Out-Null
        Write-Log 'Task installed - every 1 minute and at logon.'
    } catch {
        # plan B: the classic schtasks.exe, every minute, current user, no admin rights needed
        Write-Log ('Register-ScheduledTask failed (' + $_.Exception.Message.Trim() + '), trying schtasks.exe')
        $tr = 'wscript.exe \"' + $vbs + '\"'
        $r = Invoke-Schtasks ('/Create /F /TN "' + $TaskName + '" /SC MINUTE /MO 1 /TR "' + $tr + '"')
        if ($r.Code -ne 0) { throw ('Could not create the scheduled task. ' + $r.Text) }
        Write-Log 'Task installed with schtasks.exe - every 1 minute.'
    }
    try { Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop } catch { [void](Invoke-Schtasks ('/Run /TN "' + $TaskName + '"')) }
    Write-Host ''
    Write-Host ('Installed. "' + $TaskName + '" runs every minute and shows no window.')
}

function Uninstall-Task {
    Remove-LegacyTasks
    $gone = $false
    try {
        if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
            Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
            $gone = $true
        }
    } catch { }
    if (-not $gone) {
        $r = Invoke-Schtasks ('/Delete /F /TN "' + $TaskName + '"')
        $gone = ($r.Code -eq 0)
    }
    if ($gone) { Write-Host ('Removed scheduled task "' + $TaskName + '".'); Write-Log 'Task uninstalled.' }
    else { Write-Host 'Nothing to remove - the task is not installed.' }
}

function Show-Status {
    $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Write-Host ''
    if (-not $t) {
        Write-Host 'NOT INSTALLED. Run:  3 - Install (run every minute).bat'
        return
    }
    $info = Get-ScheduledTaskInfo -TaskName $TaskName
    Write-Host ('Task state       : {0}' -f $t.State)
    Write-Host ('Run mode         : {0}' -f $t.Principal.LogonType)
    Write-Host ('Last run time    : {0}' -f $info.LastRunTime)
    Write-Host ('Last result      : {0}  (0 = OK)' -f $info.LastTaskResult)
    Write-Host ('Next run time    : {0}' -f $info.NextRunTime)
    if (Test-Path -LiteralPath $HeartPath) {
        Write-Host ''
        Write-Host '--- lastrun.txt ---'
        Get-Content -LiteralPath $HeartPath | ForEach-Object { Write-Host $_ }
    }
}

if ($Install)   { Install-Task;   return }
if ($Uninstall) { Uninstall-Task; return }
if ($Status)    { Show-Status;    return }

if ($Watch) {
    Say ('Watching {0} every {1}s. Close this window to stop.' -f $Root, $IntervalSeconds)
    Write-Log ('Manual watcher started (every {0}s).' -f $IntervalSeconds)
    while ($true) {
        try { [void](Invoke-SortOnce) } catch { Write-Log ('ERROR: ' + $_.Exception.Message) }
        Start-Sleep -Seconds $IntervalSeconds
    }
}
elseif ($Preview) {
    Say ''
    Say 'PREVIEW - nothing will be moved:'
    Say ''
    $n = Invoke-SortOnce -DryRun
    Say ''
    Say ('Would move {0} file(s).' -f $n)
}
else {
    $n = Invoke-SortOnce
    Say ''
    Say ('Done. Moved {0} file(s).' -f $n)
}
