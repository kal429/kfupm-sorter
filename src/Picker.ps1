<#
    KFUPM Sorter - main window.
    Pick your courses, add your own filters, choose how everything else is sorted, and watch it work.
    Interface text lives in Strings.ps1 (English default, Arabic available).
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
# 1) Tell Windows we draw at the real screen DPI. Without this, on 125% / 150% displays
#    Windows paints the window small and then stretches it, which makes everything blurry.
# 2) Give the process its own taskbar identity, so the taskbar shows the KFUPM Sorter icon
#    instead of the PowerShell one. The Start-menu shortcut carries the same ID.
try {
    Add-Type -Namespace KfupmSorterNative -Name Win -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
[DllImport("shell32.dll", CharSet = CharSet.Unicode)] public static extern int SetCurrentProcessExplicitAppUserModelID(string appId);
'@
    try { [void][KfupmSorterNative.Win]::SetProcessDPIAware() } catch { }
    try { [void][KfupmSorterNative.Win]::SetCurrentProcessExplicitAppUserModelID('KFUPM.Sorter') } catch { }
} catch { }
[System.Windows.Forms.Application]::EnableVisualStyles()
# any error inside a button handler is logged and shown, instead of silently closing the window
[System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)
$script:T0 = [DateTime]::Now

$AppDir       = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $AppDir 'Catalog.ps1')
. (Join-Path $AppDir 'Strings.ps1')
$DataDir      = Join-Path $env:APPDATA 'KFUPM Sorter'
if (-not (Test-Path -LiteralPath $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }
$RulesPath    = Join-Path $DataDir 'rules.json'
$SettingsPath = Join-Path $DataDir 'settings.json'
$SessionPath  = Join-Path $DataDir 'session.json'     # unsaved window state, kept across a language switch
$UiLogPath    = Join-Path $DataDir 'ui.log'
function Write-UiLog {
    param([string]$Text)
    try {
        if ((Test-Path -LiteralPath $UiLogPath) -and (Get-Item -LiteralPath $UiLogPath).Length -gt 200KB) { Remove-Item -LiteralPath $UiLogPath -Force }
        $ms = [int]([DateTime]::Now - $script:T0).TotalMilliseconds
        Add-Content -LiteralPath $UiLogPath -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '  +' + $ms + 'ms  ' + $Text) -Encoding UTF8
    } catch { }
}
Write-UiLog ('start ' + $PSVersionTable.PSVersion + '  scale-check')
$LogPath      = Join-Path $DataDir 'sorter.log'
$HeartPath    = Join-Path $DataDir 'lastrun.txt'
$EnginePath   = Join-Path $AppDir 'KfupmSorter.ps1'
$IconPath     = Join-Path $AppDir 'app.ico'
$TaskName     = 'KFUPM Sorter'
$LegacyTask   = 'Downloads AutoSorter'      # the task the old zip version created
$Version      = '1.2.0'
$RepoUrl      = 'https://github.com/kal429/kfupm-sorter-windows'
$SiteUrl      = 'https://kal429.github.io/kfupm-sorter-windows/'

$TypeGroups = @(
    @{ name='Documents';   exts=@('.pdf','.docx','.doc','.pptx','.ppt','.xlsx','.xls','.csv','.txt','.md','.rtf','.odt'); on=$true  },
    @{ name='Images';      exts=@('.png','.jpg','.jpeg','.gif','.webp','.bmp','.heic','.svg','.tiff');                   on=$true  },
    @{ name='Videos';      exts=@('.mp4','.mkv','.avi','.mov','.webm','.wmv','.flv','.m4v');                             on=$true  },
    @{ name='Audio';       exts=@('.mp3','.wav','.flac','.m4a','.aac','.ogg','.wma');                                    on=$true  },
    @{ name='Installers';  exts=@('.exe','.msi','.msix','.appx','.iso','.cab','.apk');                                   on=$true  },
    @{ name='Archives';    exts=@('.zip','.rar','.7z','.tar','.gz','.bz2');                                              on=$true  },
    @{ name='Code';        exts=@('.py','.js','.ts','.java','.c','.cpp','.h','.cs','.json','.xml','.html','.css','.jar','.ipynb','.m','.r','.asm'); on=$false },
    @{ name='3D Printing'; exts=@('.stl','.3mf','.obj','.gcode','.step','.stp','.f3d');                                  on=$false },
    @{ name='eBooks';      exts=@('.epub','.mobi','.azw3','.djvu');                                                      on=$false }
)

# ---------------------------------------------------------------- language
$script:Lang = 'en'
if (Test-Path -LiteralPath $SettingsPath) {
    try {
        $st = Get-Content -LiteralPath $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($st.language -and $Strings.ContainsKey([string]$st.language)) { $script:Lang = [string]$st.language }
    } catch { }
}
$script:L10n = New-Object System.Collections.ArrayList
$script:Busy = $false

function T {
    param([string]$Key)
    $tbl = $Strings[$script:Lang]
    if ($tbl.ContainsKey($Key)) { return [string]$tbl[$Key] }
    if ($Strings['en'].ContainsKey($Key)) { return [string]$Strings['en'][$Key] }
    return $Key
}
function Fmt {
    param([string]$Text, [object[]]$Values)
    $s = $Text
    for ($i = 0; $i -lt $Values.Count; $i++) { $s = $s.Replace('{' + [string]$i + '}', [string]$Values[$i]) }
    return $s
}
function Reg {
    param($Control, [string]$Key, [string]$Prefix = '', [string]$Suffix = '')
    [void]$script:L10n.Add(@{ c = $Control; k = $Key; p = $Prefix; s = $Suffix })
    $Control.Text = $Prefix + (T $Key) + $Suffix
}
function Save-Settings {
    $json = [ordered]@{ language = $script:Lang } | ConvertTo-Json
    try { [System.IO.File]::WriteAllText($SettingsPath, $json, (New-Object System.Text.UTF8Encoding($false))) } catch { }
}

# ---------------------------------------------------------------- data
$catalog = Load-Catalog -Dir $AppDir
if (-not $catalog) { $catalog = [pscustomobject]@{ updated = ''; count = 0; courses = @() } }
$script:AllCourses = @($catalog.courses)
$subjectsFile = Join-Path $AppDir 'data\subjects.json'
$SubjName = @{}
if (Test-Path -LiteralPath $subjectsFile) {
    foreach ($s in (Get-Content -LiteralPath $subjectsFile -Raw -Encoding UTF8 | ConvertFrom-Json)) { $SubjName[$s.code] = $s.name }
}
$Selected = New-Object System.Collections.ArrayList
$Custom   = New-Object System.Collections.ArrayList
$script:ImportedLegacy = $false
$script:FooterKey  = ''
$script:FooterArgs = @()

# ---------------------------------------------------------------- look (KFUPM palette)
$KGreen  = [System.Drawing.Color]::FromArgb(0, 133, 64)
$KForest = [System.Drawing.Color]::FromArgb(0, 87, 63)
$KPetrol = [System.Drawing.Color]::FromArgb(0, 62, 81)
$KGold   = [System.Drawing.Color]::FromArgb(218, 201, 97)
$KGray   = [System.Drawing.Color]::FromArgb(217, 218, 228)
$KStone  = [System.Drawing.Color]::FromArgb(170, 138, 0)
$KDark   = [System.Drawing.Color]::FromArgb(55, 57, 56)
$KPale   = [System.Drawing.Color]::FromArgb(206, 234, 216)
$KBg     = [System.Drawing.Color]::FromArgb(245, 246, 248)
$White   = [System.Drawing.Color]::White
$ColMuted = [System.Drawing.Color]::FromArgb(105, 108, 112)
$ColOk    = $KGreen
$ColBad   = [System.Drawing.Color]::FromArgb(176, 32, 32)

$FontUI    = New-Object System.Drawing.Font('Segoe UI', 9.75)
$FontHead  = New-Object System.Drawing.Font('Segoe UI Semibold', 11)
$FontTitle = New-Object System.Drawing.Font('Segoe UI Semibold', 15)
$FontSmall = New-Object System.Drawing.Font('Segoe UI', 8.75)
$FontBtn   = New-Object System.Drawing.Font('Segoe UI Semibold', 9.75)

# New-Label / New-Button: when Text is a key in Strings.ps1 the control is translated
# and re-translated on every language switch; otherwise Text is shown as it is.
function New-Label {
    param($Parent, [string]$Text, [int]$X, [int]$Y, [int]$W, $Font = $null, $Color = $null)
    $l = New-Object System.Windows.Forms.Label
    $h = 22
    if ([object]::ReferenceEquals($Font, $FontTitle)) { $h = 30 }
    elseif ([object]::ReferenceEquals($Font, $FontHead)) { $h = 24 }
    $l.Left = $X; $l.Top = $Y; $l.Width = $W; $l.Height = $h; $l.AutoSize = $false
    if ($Font)  { $l.Font = $Font }
    if ($Color) { $l.ForeColor = $Color }
    if ($Strings['en'].ContainsKey($Text)) { Reg $l $Text } else { $l.Text = $Text }
    $Parent.Controls.Add($l)
    return $l
}
function New-Heading {
    param($Parent, [string]$Key, [int]$X, [int]$Y, [int]$W = 400)
    return (New-Label $Parent $Key $X $Y $W $FontHead $KForest)
}
function New-Button {
    param($Parent, [string]$Text, [int]$X, [int]$Y, [int]$W, [int]$H = 30, [switch]$Primary)
    $b = New-Object System.Windows.Forms.Button
    $b.Left = $X; $b.Top = $Y; $b.Width = $W; $b.Height = $H
    $b.FlatStyle = 'Flat'
    $b.Cursor = 'Hand'
    if ($Primary) {
        $b.BackColor = $KGreen; $b.ForeColor = $White; $b.Font = $FontBtn
        $b.FlatAppearance.BorderSize = 0
        $b.FlatAppearance.MouseOverBackColor = $KForest
    } else {
        $b.BackColor = $White; $b.ForeColor = $KPetrol
        $b.FlatAppearance.BorderSize = 1
        $b.FlatAppearance.BorderColor = $KGray
        $b.FlatAppearance.MouseOverBackColor = $KBg
    }
    if ($Strings['en'].ContainsKey($Text)) { Reg $b $Text } else { $b.Text = $Text }
    $Parent.Controls.Add($b)
    return $b
}
function Show-Msg {
    param([string]$Text, [string]$Buttons = 'OK', [string]$Icon = 'Information')
    if ($script:Lang -eq 'ar') {
        $opt = [System.Windows.Forms.MessageBoxOptions]'RightAlign, RtlReading'
        return [System.Windows.Forms.MessageBox]::Show($Text, 'KFUPM Sorter', $Buttons, $Icon, 'Button1', $opt)
    }
    return [System.Windows.Forms.MessageBox]::Show($Text, 'KFUPM Sorter', $Buttons, $Icon)
}
function Show-Warn  { param([string]$Text) [void](Show-Msg $Text 'OK' 'Warning') }
function Show-Error { param([string]$Text) [void](Show-Msg $Text 'OK' 'Error') }
function Set-Footer {
    param([string]$Key, [object[]]$Values = @())
    $script:FooterKey = $Key; $script:FooterArgs = $Values
    if ($Key -eq '') { $lblFooter.Text = '' } else { $lblFooter.Text = Fmt (T $Key) $Values }
}

# ---------------------------------------------------------------- window
$f = New-Object System.Windows.Forms.Form
$f.Text = 'KFUPM Sorter'
$f.ClientSize = New-Object System.Drawing.Size(944, 660)
$f.StartPosition = 'CenterScreen'
$f.Font = $FontUI
$f.BackColor = $KBg
if (Test-Path -LiteralPath $IconPath) { try { $f.Icon = New-Object System.Drawing.Icon($IconPath) } catch { } }

# green header with a gold rule underneath
$header = New-Object System.Windows.Forms.Panel
$header.Left = 0; $header.Top = 0; $header.Width = 944; $header.Height = 66
$header.Anchor = 'Top,Left,Right'
$header.BackColor = $KGreen
$f.Controls.Add($header)
New-Label $header 'KFUPM Sorter' 18 8 300 $FontTitle $White | Out-Null
$lblSub = New-Label $header 'app.subtitle' 20 38 440 $FontSmall $KPale
$lblSub.Height = 26
$lblCredits = New-Label $header '' 462 22 310 $FontHead $KGold
$lblCredits.TextAlign = 'MiddleRight'
$lblCredits.Anchor = 'Top,Right'

$cmbLang = New-Object System.Windows.Forms.ComboBox
$cmbLang.DropDownStyle = 'DropDownList'
$cmbLang.Left = 800; $cmbLang.Top = 21; $cmbLang.Width = 126
$cmbLang.Anchor = 'Top,Right'
$cmbLang.RightToLeft = 'No'
[void]$cmbLang.Items.Add('English')
[void]$cmbLang.Items.Add('العربية')
$header.Controls.Add($cmbLang)

$goldBar = New-Object System.Windows.Forms.Panel
$goldBar.Left = 0; $goldBar.Top = 66; $goldBar.Width = 944; $goldBar.Height = 4
$goldBar.Anchor = 'Top,Left,Right'
$goldBar.BackColor = $KGold
$f.Controls.Add($goldBar)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Left = 8; $tabs.Top = 78; $tabs.Width = 928; $tabs.Height = 530
$tabs.Anchor = 'Top,Left,Right,Bottom'
$tabs.Padding = New-Object System.Drawing.Point(14, 5)
$f.Controls.Add($tabs)

$tabCourses = New-Object System.Windows.Forms.TabPage; Reg $tabCourses 'tab.courses'
$tabCustom  = New-Object System.Windows.Forms.TabPage; Reg $tabCustom  'tab.custom'
$tabSort    = New-Object System.Windows.Forms.TabPage; Reg $tabSort    'tab.sort'
$tabStatus  = New-Object System.Windows.Forms.TabPage; Reg $tabStatus  'tab.status'
$tabAbout   = New-Object System.Windows.Forms.TabPage; Reg $tabAbout   'tab.about'
foreach ($t in @($tabCourses, $tabCustom, $tabSort, $tabStatus, $tabAbout)) {
    $t.BackColor = $White
    $tabs.TabPages.Add($t)
}

$btnSave  = New-Button $f 'btn.save'  712 616 110 32 -Primary
$btnClose = New-Button $f 'btn.close' 828 616 108 32
$btnSave.Anchor  = 'Bottom,Right'
$btnClose.Anchor = 'Bottom,Right'
$lblFooter = New-Label $f '' 12 622 680 $FontSmall $ColMuted
$lblFooter.Anchor = 'Bottom,Left'

# ================================================================ TAB 1 : courses
New-Label $tabCourses 'lbl.term' 14 16 60 | Out-Null
$txtTerm = New-Object System.Windows.Forms.TextBox
$txtTerm.Left = 76; $txtTerm.Top = 13; $txtTerm.Width = 64
$tabCourses.Controls.Add($txtTerm)

$chkTermFolder = New-Object System.Windows.Forms.CheckBox
Reg $chkTermFolder 'chk.termFolder'
$chkTermFolder.Left = 156; $chkTermFolder.Top = 14; $chkTermFolder.Width = 600
$tabCourses.Controls.Add($chkTermFolder)

New-Heading $tabCourses 'lbl.dept' 14 46 250 | Out-Null
$lstDept = New-Object System.Windows.Forms.ListBox
$lstDept.Left = 14; $lstDept.Top = 70; $lstDept.Width = 250; $lstDept.Height = 290
$lstDept.RightToLeft = 'No'
$tabCourses.Controls.Add($lstDept)

New-Heading $tabCourses 'lbl.search' 276 46 628 | Out-Null
$txtSearch = New-Object System.Windows.Forms.TextBox
$txtSearch.Left = 276; $txtSearch.Top = 70; $txtSearch.Width = 628
$tabCourses.Controls.Add($txtSearch)

$clbCourses = New-Object System.Windows.Forms.CheckedListBox
$clbCourses.Left = 276; $clbCourses.Top = 98; $clbCourses.Width = 628; $clbCourses.Height = 228
$clbCourses.CheckOnClick = $true
$clbCourses.RightToLeft = 'No'
$tabCourses.Controls.Add($clbCourses)

$btnAdd   = New-Button $tabCourses 'btn.add' 276 332 160 30 -Primary
$lblCount = New-Label $tabCourses '' 446 338 440 $FontSmall $ColMuted

New-Heading $tabCourses 'lbl.mine' 14 374 400 | Out-Null
$lstMine = New-Object System.Windows.Forms.ListBox
$lstMine.Left = 14; $lstMine.Top = 400; $lstMine.Width = 700; $lstMine.Height = 94
$lstMine.SelectionMode = 'MultiExtended'
$lstMine.RightToLeft = 'No'
$tabCourses.Controls.Add($lstMine)

$btnRemove = New-Button $tabCourses 'btn.remove' 724 400 180
$btnClear  = New-Button $tabCourses 'btn.clear'  724 436 180

# ================================================================ TAB 2 : custom filters
New-Heading $tabCustom 'cust.head' 14 14 600 | Out-Null
New-Label $tabCustom 'cust.help1'   14 42 890 | Out-Null
New-Label $tabCustom 'cust.help2'   14 64 890 | Out-Null
New-Label $tabCustom 'cust.example' 14 88 890 $FontSmall $ColMuted | Out-Null

New-Label $tabCustom 'cust.folder'   14 122 250 | Out-Null
New-Label $tabCustom 'cust.keywords' 280 122 470 | Out-Null
$txtCustFolder = New-Object System.Windows.Forms.TextBox
$txtCustFolder.Left = 14; $txtCustFolder.Top = 146; $txtCustFolder.Width = 250
$tabCustom.Controls.Add($txtCustFolder)
$txtCustKeys = New-Object System.Windows.Forms.TextBox
$txtCustKeys.Left = 280; $txtCustKeys.Top = 146; $txtCustKeys.Width = 470
$tabCustom.Controls.Add($txtCustKeys)
$btnCustAdd = New-Button $tabCustom 'cust.add' 764 143 140 30 -Primary

$chkCustWhole = New-Object System.Windows.Forms.CheckBox
Reg $chkCustWhole 'cust.whole'
$chkCustWhole.Left = 14; $chkCustWhole.Top = 178; $chkCustWhole.Width = 736; $chkCustWhole.Checked = $true
$tabCustom.Controls.Add($chkCustWhole)

New-Heading $tabCustom 'cust.list' 14 218 400 | Out-Null
$lstCustom = New-Object System.Windows.Forms.ListBox
$lstCustom.Left = 14; $lstCustom.Top = 244; $lstCustom.Width = 700; $lstCustom.Height = 240
$lstCustom.RightToLeft = 'No'
$tabCustom.Controls.Add($lstCustom)
$btnCustRemove = New-Button $tabCustom 'btn.remove' 724 244 180

# ================================================================ TAB 3 : sorting
New-Heading $tabSort 'lbl.watch' 14 16 400 | Out-Null
$txtRoot = New-Object System.Windows.Forms.TextBox
$txtRoot.Left = 14; $txtRoot.Top = 44; $txtRoot.Width = 774
$txtRoot.RightToLeft = 'No'
$txtRoot.Text = (Join-Path $env:USERPROFILE 'Downloads')
$tabSort.Controls.Add($txtRoot)
$btnBrowse = New-Button $tabSort 'btn.browse' 796 42 108 26

New-Heading $tabSort 'lbl.unmatched' 14 88 440 | Out-Null
$chkByType = New-Object System.Windows.Forms.CheckBox
Reg $chkByType 'chk.byType'
$chkByType.Left = 14; $chkByType.Top = 116; $chkByType.Width = 430; $chkByType.Checked = $true
$tabSort.Controls.Add($chkByType)

$clbTypes = New-Object System.Windows.Forms.CheckedListBox
$clbTypes.Left = 14; $clbTypes.Top = 142; $clbTypes.Width = 430; $clbTypes.Height = 200
$clbTypes.CheckOnClick = $true
foreach ($g in $TypeGroups) { [void]$clbTypes.Items.Add($g.name, [bool]$g.on) }
$tabSort.Controls.Add($clbTypes)

$chkOther = New-Object System.Windows.Forms.CheckBox
Reg $chkOther 'chk.other'
$chkOther.Left = 14; $chkOther.Top = 350; $chkOther.Width = 430
$tabSort.Controls.Add($chkOther)

$gbSafe = New-Object System.Windows.Forms.GroupBox
Reg $gbSafe 'gb.safe'
$gbSafe.ForeColor = $KForest
$gbSafe.Left = 470; $gbSafe.Top = 116; $gbSafe.Width = 434; $gbSafe.Height = 290
$tabSort.Controls.Add($gbSafe)
$y = 28
foreach ($n in 1..8) { New-Label $gbSafe ('safe.' + [string]$n) 14 $y 410 $FontSmall $KDark | Out-Null; $y += 24 }
New-Label $gbSafe 'lbl.settingsAt' 14 ($y + 6) 410 $FontSmall $ColMuted | Out-Null
$lblDataDir = New-Label $gbSafe $DataDir 14 ($y + 28) 410 $FontSmall $KGreen
$lblDataDir.RightToLeft = 'No'

# ================================================================ TAB 4 : status
New-Heading $tabStatus 'lbl.auto' 14 16 400 | Out-Null
$lblAuto = New-Label $tabStatus '' 14 44 600 $FontHead
$lblLast = New-Label $tabStatus '' 14 72 600 $FontSmall $ColMuted
$lblLast.RightToLeft = 'No'

$btnEnable  = New-Button $tabStatus 'btn.enable'  620 16 284 30 -Primary
$btnDisable = New-Button $tabStatus 'btn.disable' 620 52 284
$btnLegacy  = New-Button $tabStatus 'btn.removeOld' 620 88 284
$btnLegacy.ForeColor = $KStone
$btnLegacy.Visible = $false

New-Heading $tabStatus 'lbl.recent' 14 112 400 | Out-Null
$lstLog = New-Object System.Windows.Forms.ListBox
$lstLog.Left = 14; $lstLog.Top = 138; $lstLog.Width = 890; $lstLog.Height = 300
$lstLog.HorizontalScrollbar = $true
$lstLog.RightToLeft = 'No'
$lstLog.Font = New-Object System.Drawing.Font('Consolas', 9)
$tabStatus.Controls.Add($lstLog)

$btnSortNow  = New-Button $tabStatus 'btn.sortNow'    14  448 150 30 -Primary
$btnPreview  = New-Button $tabStatus 'btn.preview'    172 448 170
$btnOpenRoot = New-Button $tabStatus 'btn.openFolder' 350 448 130
$btnRefresh  = New-Button $tabStatus 'btn.refresh'    488 448 100

# ================================================================ TAB 5 : about
New-Label $tabAbout 'KFUPM Sorter' 14 18 400 $FontTitle $KGreen | Out-Null
$lblVersion = New-Label $tabAbout '' 16 50 300 $FontSmall $ColMuted

New-Heading $tabAbout 'about.catalog' 14 92 400 | Out-Null
$lblCatalog = New-Label $tabAbout '' 14 118 890 $FontUI
New-Label $tabAbout 'about.source' 14 142 890 $FontSmall $ColMuted | Out-Null
$btnUpdate = New-Button $tabAbout 'btn.update' 14 172 240 30 -Primary
$lblUpd = New-Label $tabAbout '' 264 178 630 $FontSmall $ColMuted
$prog = New-Object System.Windows.Forms.ProgressBar
$prog.Left = 14; $prog.Top = 212; $prog.Width = 890; $prog.Height = 14; $prog.Visible = $false
$tabAbout.Controls.Add($prog)

New-Heading $tabAbout 'about.privacy' 14 252 400 | Out-Null
New-Label $tabAbout 'privacy.1' 14 278 890 $FontUI | Out-Null
New-Label $tabAbout 'privacy.2' 14 302 890 $FontUI | Out-Null

New-Heading $tabAbout 'about.open' 14 344 400 | Out-Null
$lnkRepo = New-Object System.Windows.Forms.LinkLabel
$lnkRepo.Text = $RepoUrl; $lnkRepo.Left = 14; $lnkRepo.Top = 370; $lnkRepo.Width = 890
$lnkRepo.RightToLeft = 'No'
$lnkRepo.LinkColor = $KGreen; $lnkRepo.ActiveLinkColor = $KForest
$tabAbout.Controls.Add($lnkRepo)
$lnkSite = New-Object System.Windows.Forms.LinkLabel
$lnkSite.Text = $SiteUrl; $lnkSite.Left = 14; $lnkSite.Top = 394; $lnkSite.Width = 890
$lnkSite.RightToLeft = 'No'
$lnkSite.LinkColor = $KGreen; $lnkSite.ActiveLinkColor = $KForest
$tabAbout.Controls.Add($lnkSite)
New-Label $tabAbout 'about.disclaimer' 14 432 890 $FontSmall $ColMuted | Out-Null

# ================================================================ screen scaling
# Everything above is laid out for a 100% (96 DPI) screen. Fonts are in points, so Windows
# already draws them at the real DPI; here the positions and sizes are scaled to match,
# otherwise text is cut off and the window has an empty band on 125% / 150% screens.
$script:Dpi = 1.0
try {
    $g = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
    $script:Dpi = [double]$g.DpiX / 96.0
    $g.Dispose()
} catch { }
if ($script:Dpi -gt 1.01) {
    $f.Scale((New-Object System.Drawing.SizeF([single]$script:Dpi, [single]$script:Dpi)))
    $tabs.Padding = New-Object System.Drawing.Point([int](14 * $script:Dpi), [int](5 * $script:Dpi))
}
$f.MinimumSize = New-Object System.Drawing.Size([int](760 * $script:Dpi), [int](560 * $script:Dpi))

# ================================================================ behaviour
function Get-CourseText { param($c) return ($c.code + '   -   ' + $c.title + '   (' + [string]$c.credits + ' cr)') }
function Get-CodeFromText { param([string]$t) return ($t -split '   -   ')[0].Trim() }

function Get-TypeText {
    param($g)
    $sample = (@($g.exts | Select-Object -First 4) -join ' ')
    if ($script:Lang -eq 'en') { return ($g.name + '     ' + $sample) }
    return ((T ('type.' + $g.name)) + '   (' + $g.name + ')')
}
function Update-Types {
    $states = @()
    for ($i = 0; $i -lt $clbTypes.Items.Count; $i++) { $states += [bool]$clbTypes.GetItemChecked($i) }
    for ($i = 0; $i -lt $TypeGroups.Count; $i++) {
        $clbTypes.Items[$i] = (Get-TypeText $TypeGroups[$i])
        $clbTypes.SetItemChecked($i, $states[$i])
    }
}

function Update-Depts {
    $keep = $lstDept.SelectedIndex
    $script:Busy = $true
    $lstDept.BeginUpdate()
    $lstDept.Items.Clear()
    [void]$lstDept.Items.Add((T 'dept.all'))
    foreach ($c in @($script:AllCourses | ForEach-Object { $_.subject } | Sort-Object -Unique)) {
        $n = ''
        if ($SubjName.ContainsKey($c)) { $n = $SubjName[$c] }
        [void]$lstDept.Items.Add($c + '  -  ' + $n)
    }
    $lstDept.EndUpdate()
    if ($keep -lt 0 -or $keep -ge $lstDept.Items.Count) { $keep = 0 }
    if ($lstDept.Items.Count -gt 0) { $lstDept.SelectedIndex = $keep }
    $script:Busy = $false
}

function Update-CountLabel { $lblCount.Text = Fmt (T 'fmt.shown') @($clbCourses.Items.Count) }

function Update-Courses {
    $clbCourses.BeginUpdate()
    $clbCourses.Items.Clear()
    $dept = ''
    if ($lstDept.SelectedIndex -gt 0) { $dept = ([string]$lstDept.SelectedItem -split '\s')[0] }
    $q = $txtSearch.Text.Trim()
    $list = $script:AllCourses
    if ($dept -ne '') { $list = @($list | Where-Object { $_.subject -eq $dept }) }
    if ($q -ne '') {
        $qq = $q -replace '\s+', ''
        $list = @($list | Where-Object { ($_.code -replace '\s+', '') -like ('*' + $qq + '*') -or $_.title -like ('*' + $q + '*') })
    }
    $shown = @($list | Select-Object -First 600)
    foreach ($c in $shown) { [void]$clbCourses.Items.Add((Get-CourseText $c)) }
    $clbCourses.EndUpdate()
    Update-CountLabel
}

function Update-Mine {
    $lstMine.Items.Clear()
    $cr = 0
    foreach ($c in $Selected) { [void]$lstMine.Items.Add((Get-CourseText $c)); $cr += [int]$c.credits }
    if ($Selected.Count -gt 0) { $lblCredits.Text = Fmt (T 'credits.fmt') @($Selected.Count, $cr) }
    else { $lblCredits.Text = T 'credits.none' }
}

# ---------- custom filters
function Get-KeywordPattern {
    param([string]$Keyword, [bool]$Whole)
    $esc = [regex]::Escape($Keyword.Trim())
    $esc = $esc.Replace('\ ', '[\s_-]*')          # "base station" also matches base_station / base-station
    if ($Whole) { return ('(?<!\p{L})' + $esc + '(?!\p{L})') }
    return $esc
}
function New-CustomRule {
    param([string]$Folder, [string[]]$Keywords, [bool]$Whole)
    $pats = @()
    foreach ($k in $Keywords) { $pats += (Get-KeywordPattern $k $Whole) }
    return [ordered]@{ folder = $Folder; keywords = @($Keywords); wholeWord = $Whole; patterns = @($pats) }
}
function Get-CustomText {
    param($r)
    $tag = T 'cust.anyTag'
    if ($r.wholeWord) { $tag = T 'cust.wordTag' }
    return ([string]$r.folder + '   <-   ' + (@($r.keywords) -join ', ') + '     (' + $tag + ')')
}
function Update-Custom {
    $lstCustom.Items.Clear()
    foreach ($r in $Custom) { [void]$lstCustom.Items.Add((Get-CustomText $r)) }
    if ($Custom.Count -eq 0) { [void]$lstCustom.Items.Add((T 'cust.empty')) }
    $btnCustRemove.Enabled = ($Custom.Count -gt 0)
}
function Add-CustomFilter {
    $folder = $txtCustFolder.Text.Trim().Trim('.')
    if ($folder -eq '' -or $folder.IndexOfAny([char[]]'\/:*?"<>|') -ge 0) { Show-Warn (T 'warn.custFolder'); return $false }
    $keys = @($txtCustKeys.Text -split '[,،;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' } | Select-Object -Unique)
    if ($keys.Count -eq 0) { Show-Warn (T 'warn.custKeys'); return $false }
    $rule = New-CustomRule $folder $keys ([bool]$chkCustWhole.Checked)
    # same folder name again = edit that filter
    $at = -1
    for ($i = 0; $i -lt $Custom.Count; $i++) { if ([string]$Custom[$i].folder -eq $folder) { $at = $i } }
    if ($at -ge 0) { $Custom[$at] = $rule } else { [void]$Custom.Add($rule) }
    $txtCustFolder.Text = ''; $txtCustKeys.Text = ''; $chkCustWhole.Checked = $true
    Update-Custom
    return $true
}

function Invoke-Engine {
    param([string[]]$EngineArgs, [switch]$Capture)
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $EnginePath + '"')) + $EngineArgs
    if ($Capture) {
        $tmp = Join-Path $env:TEMP 'kfupm-sorter-output.txt'
        $err = Join-Path $env:TEMP 'kfupm-sorter-errors.txt'
        foreach ($x in @($tmp, $err)) { if (Test-Path -LiteralPath $x) { Remove-Item -LiteralPath $x -Force } }
        Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -NoNewWindow -Wait -RedirectStandardOutput $tmp -RedirectStandardError $err | Out-Null
        $lines = @()
        foreach ($x in @($tmp, $err)) { if (Test-Path -LiteralPath $x) { $lines += @(Get-Content -LiteralPath $x -Encoding UTF8) } }
        return $lines
    }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -NoNewWindow -Wait | Out-Null
    return @()
}

function Test-Task {
    param([string]$Name)
    try { return [bool](Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue) }
    catch {
        # ScheduledTasks module unavailable: ask schtasks.exe instead
        $old = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            & schtasks.exe /Query /TN $Name *> $null
            return ($LASTEXITCODE -eq 0)
        } catch { return $false } finally { $ErrorActionPreference = $old }
    }
}

function Enable-Auto {
    # installs the task (and removes the old zip version's task), then checks it really exists
    $out = @(Invoke-Engine @('-Install') -Capture)
    Write-UiLog ('install: ' + (($out | Where-Object { $_ }) -join ' / '))
    if (-not (Test-Task $TaskName)) {
        Show-Error ((T 'err.install') + [Environment]::NewLine + [Environment]::NewLine + (($out | Select-Object -Last 8) -join [Environment]::NewLine))
        return
    }
    if (Test-Task $LegacyTask) { Remove-LegacyAsAdmin }
}

# The old zip version's task was created with administrator rights, so only an
# administrator can delete it. Windows asks once (UAC); nothing else runs elevated.
function Remove-LegacyAsAdmin {
    $ans = Show-Msg (T 'ask.removeOld') 'YesNo' 'Question'
    if ([string]$ans -ne 'Yes') { return }
    try {
        Start-Process -FilePath 'schtasks.exe' -ArgumentList ('/Delete /F /TN "' + $LegacyTask + '"') -Verb RunAs -WindowStyle Hidden -Wait
        Write-UiLog 'old task removed with administrator permission'
    } catch {
        Write-UiLog ('old task removal cancelled: ' + $_.Exception.Message)
    }
}

function Update-Status {
    $script:LegacyExists = Test-Task $LegacyTask
    $btnLegacy.Visible = $script:LegacyExists
    if ($script:FooterKey -eq 'foot.oldTask' -and -not $script:LegacyExists) { Set-Footer '' }
    if (Test-Task $TaskName) {
        $script:TaskState = 'on'
        $lblAuto.Text = T 'auto.on'
        $lblAuto.ForeColor = $ColOk
    } elseif ($script:LegacyExists) {
        $script:TaskState = 'legacy'
        $lblAuto.Text = T 'auto.legacy'
        $lblAuto.ForeColor = $KStone
    } else {
        $script:TaskState = 'off'
        $lblAuto.Text = T 'auto.off'
        $lblAuto.ForeColor = $ColBad
    }
    # only the button that changes something is active
    $btnEnable.Enabled  = ($script:TaskState -ne 'on')
    $btnDisable.Enabled = ($script:TaskState -eq 'on')
    if ($script:TaskState -eq 'on') { $btnEnable.BackColor = $KGray; $btnEnable.ForeColor = $ColMuted }
    else { $btnEnable.BackColor = $KGreen; $btnEnable.ForeColor = $White }
    if (Test-Path -LiteralPath $HeartPath) {
        $lblLast.Text = (Get-Content -LiteralPath $HeartPath -Encoding UTF8) -join '   |   '
    } else {
        $lblLast.Text = T 'last.none'
    }
    $lstLog.BeginUpdate()
    $lstLog.Items.Clear()
    if (Test-Path -LiteralPath $LogPath) {
        $lines = @(Get-Content -LiteralPath $LogPath -Encoding UTF8 | Where-Object { $_ -match 'MOVED|FAILED' } | Select-Object -Last 200)
        [array]::Reverse($lines)
        foreach ($l in $lines) { [void]$lstLog.Items.Add($l) }
    }
    if ($lstLog.Items.Count -eq 0) { [void]$lstLog.Items.Add((T 'log.empty')) }
    $lstLog.EndUpdate()
}

function Update-CatalogLabel {
    $when = T 'catalog.bundled'
    if ($catalog.updated) { $when = Fmt (T 'catalog.updated') @([string]$catalog.updated) }
    $depts = @($script:AllCourses | ForEach-Object { $_.subject } | Sort-Object -Unique).Count
    $lblCatalog.Text = Fmt (T 'catalog.fmt') @($script:AllCourses.Count, $depts, $when)
}

# Arabic reads right to left, so the whole layout is mirrored: every control moves to the
# mirror position inside its parent and right-aligns its text. The form itself is never
# switched to RightToLeft, because that recreates the window and ends the program.
$script:Mirrored = $false
$KeepLtr = @($cmbLang, $lstDept, $clbCourses, $lstMine, $lstCustom, $txtRoot, $lstLog, $lblDataDir, $lblLast, $lnkRepo, $lnkSite)
function Switch-Anchor {
    param($Control)
    $parts = @(([string]$Control.Anchor) -split ',\s*' | Where-Object { $_ -ne '' })
    $hasL = $parts -contains 'Left'; $hasR = $parts -contains 'Right'
    if ($hasL -eq $hasR) { return }
    $parts = @($parts | ForEach-Object { if ($_ -eq 'Left') { 'Right' } elseif ($_ -eq 'Right') { 'Left' } else { $_ } })
    $Control.Anchor = ($parts -join ', ')
}
function Set-TreeDirection {
    param($Parent, [bool]$Rtl, [bool]$Flip)
    $w = [int]$Parent.ClientSize.Width
    foreach ($c in @($Parent.Controls)) {
        $isPage = $c -is [System.Windows.Forms.TabPage]
        if ($Flip -and -not $isPage) {
            $c.Left = $w - $c.Left - $c.Width
            Switch-Anchor $c
        }
        $keep = $false
        foreach ($k in $KeepLtr) { if ([object]::ReferenceEquals($k, $c)) { $keep = $true } }
        if (-not $keep) { if ($Rtl) { $c.RightToLeft = 'Yes' } else { $c.RightToLeft = 'No' } }
        if ($c -is [System.Windows.Forms.TabControl]) { $c.RightToLeftLayout = $Rtl }
        if ($c.Controls.Count -gt 0) { Set-TreeDirection $c $Rtl $Flip }
    }
}
function Set-Direction {
    param([bool]$Rtl)
    $flip = ($Rtl -ne $script:Mirrored)
    $f.SuspendLayout()
    Set-TreeDirection $f $Rtl $flip
    $f.ResumeLayout()
    $script:Mirrored = $Rtl
}

function Set-Language {
    param([string]$Lang, [switch]$NoSave)
    if (-not $Strings.ContainsKey($Lang)) { $Lang = 'en' }
    $script:Lang = $Lang
    $f.SuspendLayout()
    foreach ($e in $script:L10n) { $e.c.Text = $e.p + (T $e.k) + $e.s }
    $lblVersion.Text = Fmt (T 'about.version') @($Version)
    Update-Types
    if ($lstDept.Items.Count -gt 0) { Update-Depts }
    Update-CountLabel
    Update-Mine
    Update-Custom
    Update-CatalogLabel
    Update-Status
    $lblUpd.Text = ''
    if ($script:FooterKey -ne '') { Set-Footer $script:FooterKey $script:FooterArgs }
    $rtl = ($Lang -eq 'ar')
    if ($f.Visible) { Set-Direction $rtl }
    $script:Busy = $true
    if ($rtl) { $cmbLang.SelectedIndex = 1 } else { $cmbLang.SelectedIndex = 0 }
    $script:Busy = $false
    $f.ResumeLayout()
    if (-not $NoSave) { Save-Settings }
}

function Save-Rules {
    $root = $txtRoot.Text.Trim()
    if (-not (Test-Path -LiteralPath $root)) { Show-Warn (T 'warn.folder'); return $false }
    if ($Selected.Count -eq 0 -and $Custom.Count -eq 0 -and -not $chkByType.Checked) { Show-Warn (T 'warn.nothing'); return $false }
    if ($chkTermFolder.Checked -and $txtTerm.Text.Trim() -eq '') { Show-Warn (T 'warn.term'); return $false }
    $json = (Get-RulesObject) | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($RulesPath, $json, (New-Object System.Text.UTF8Encoding($false)))
    return $true
}

function Get-RulesObject {
    param([switch]$AllTypes)     # AllTypes: keep the ticked type groups even when sorting by type is off
    $root = $txtRoot.Text.Trim()
    $term = $txtTerm.Text.Trim()
    $courseRules = @()
    foreach ($c in $Selected) {
        $m = [regex]::Match([string]$c.code, '^([A-Za-z]+)\s*(\d+)$')
        $pat = [regex]::Escape([string]$c.code)
        if ($m.Success) { $pat = $m.Groups[1].Value + '[\s_-]*' + $m.Groups[2].Value + '(?!\d)' }
        $folder = [string]$c.code
        if ($chkTermFolder.Checked) { $folder = $term + '\' + [string]$c.code }
        $courseRules += [ordered]@{ folder = $folder; patterns = @($pat); title = [string]$c.title; credits = [int]$c.credits }
    }
    $customRules = @()
    foreach ($r in $Custom) { $customRules += $r }
    $typeRules = @()
    if ($chkByType.Checked -or $AllTypes) {
        foreach ($i in $clbTypes.CheckedIndices) {
            $g = $TypeGroups[[int]$i]
            $typeRules += [ordered]@{ folder = $g.name; extensions = @($g.exts) }
        }
    }
    $other = $null
    if ($chkOther.Checked) { $other = 'Other' }
    $rules = [ordered]@{
        watchFolder               = $root
        term                      = $term
        termFolder                = [bool]$chkTermFolder.Checked
        minAgeSeconds             = 20
        sortByTypeIfNoCourseMatch = [bool]$chkByType.Checked
        otherFolder               = $other
        skipExtensions            = @('.crdownload', '.part', '.partial', '.tmp', '.download', '.opdownload', '.!ut', '.lock')
        ignoreNames               = @('desktop.ini', 'sorter.log', 'lastrun.txt')
        customRules               = @($customRules)
        courseRules               = @($courseRules)
        typeRules                 = @($typeRules)
    }
    return $rules
}

# Switching language restarts the window: the unsaved state is parked in session.json,
# the new window picks it up, and nothing you ticked is lost.
function Restart-InLanguage {
    param([string]$Lang)
    try {
        $state = Get-RulesObject -AllTypes
        $state['selectedTab'] = $tabs.SelectedIndex
        $state['footerKey']   = $script:FooterKey
        $state['footerArgs']  = @($script:FooterArgs | ForEach-Object { [string]$_ })
        [System.IO.File]::WriteAllText($SessionPath, ($state | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false)))
    } catch { Write-UiLog ('session save failed: ' + $_.Exception.Message) }
    $script:Lang = $Lang
    Save-Settings
    Write-UiLog ('restart in ' + $Lang)
    Start-Process -FilePath 'wscript.exe' -ArgumentList ('"' + (Join-Path $AppDir 'launch-ui.vbs') + '"')
    $script:Restarting = $true
    $f.Close()
}

function Import-Rules {
    param([string]$Path = '')
    $src = $RulesPath
    if ($Path -ne '') { $src = $Path }
    elseif (-not (Test-Path -LiteralPath $src)) {
        # first run after upgrading from the zip version: pick up the old choices
        $legacy = Join-Path $env:USERPROFILE 'Downloads\KFUPM Sorter\rules.json'
        if (-not (Test-Path -LiteralPath $legacy)) { return }
        $src = $legacy
        $script:ImportedLegacy = $true
    }
    $old = Get-Content -LiteralPath $src -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($old.watchFolder) { $txtRoot.Text = [string]$old.watchFolder }
    if ($old.term)        { $txtTerm.Text = [string]$old.term }
    $termOn = [bool]$old.termFolder
    foreach ($cr in @($old.courseRules)) {
        if (-not $cr) { continue }
        $code = Split-Path -Leaf ([string]$cr.folder)
        if ($old.term -and ([string]$cr.folder).StartsWith([string]$old.term + '\')) { $termOn = $true }
        $c = $script:AllCourses | Where-Object { $_.code -eq $code } | Select-Object -First 1
        if (-not $c) { $c = [pscustomobject]@{ code = $code; title = [string]$cr.title; credits = [int]$cr.credits; subject = ($code -split '\s')[0] } }
        if (-not ($Selected | Where-Object { $_.code -eq $c.code })) { [void]$Selected.Add($c) }
    }
    foreach ($cu in @($old.customRules)) {
        if (-not $cu -or -not $cu.folder) { continue }
        [void]$Custom.Add((New-CustomRule ([string]$cu.folder) @($cu.keywords | ForEach-Object { [string]$_ }) ([bool]$cu.wholeWord)))
    }
    $chkTermFolder.Checked = $termOn
    $chkByType.Checked = [bool]$old.sortByTypeIfNoCourseMatch
    $chkOther.Checked  = [bool]$old.otherFolder
    $saved = @($old.typeRules | ForEach-Object { [string]$_.folder })
    for ($i = 0; $i -lt $TypeGroups.Count; $i++) {
        $clbTypes.SetItemChecked($i, ($saved -contains $TypeGroups[$i].name))
    }
}

# ---------- events
$lstDept.Add_SelectedIndexChanged({ if (-not $script:Busy) { Update-Courses } })
$txtSearch.Add_TextChanged({ Update-Courses })
$chkByType.Add_CheckedChanged({ $clbTypes.Enabled = $chkByType.Checked; $chkOther.Enabled = $chkByType.Checked })
$cmbLang.Add_SelectedIndexChanged({
    if ($script:Busy) { return }
    $want = 'en'
    if ($cmbLang.SelectedIndex -eq 1) { $want = 'ar' }
    if ($want -ne $script:Lang) { Restart-InLanguage $want }
})

$btnAdd.Add_Click({
    foreach ($item in @($clbCourses.CheckedItems)) {
        $code = Get-CodeFromText ([string]$item)
        $c = $script:AllCourses | Where-Object { $_.code -eq $code } | Select-Object -First 1
        if ($c -and -not ($Selected | Where-Object { $_.code -eq $c.code })) { [void]$Selected.Add($c) }
    }
    for ($i = 0; $i -lt $clbCourses.Items.Count; $i++) { $clbCourses.SetItemChecked($i, $false) }
    Update-Mine
})
$btnRemove.Add_Click({
    foreach ($g in @($lstMine.SelectedItems)) {
        $code = Get-CodeFromText ([string]$g)
        $hit = $Selected | Where-Object { $_.code -eq $code } | Select-Object -First 1
        if ($hit) { $Selected.Remove($hit) }
    }
    Update-Mine
})
$btnClear.Add_Click({ $Selected.Clear(); Update-Mine })

$btnCustAdd.Add_Click({ [void](Add-CustomFilter) })
$txtCustKeys.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq 'Enter') { [void](Add-CustomFilter); $e.SuppressKeyPress = $true } })
$btnCustRemove.Add_Click({
    $i = $lstCustom.SelectedIndex
    if ($i -ge 0 -and $i -lt $Custom.Count) { $Custom.RemoveAt($i); Update-Custom }
})
$lstCustom.Add_SelectedIndexChanged({
    # pick a filter to edit it: its values go back into the boxes, Add saves over it
    $i = $lstCustom.SelectedIndex
    if ($i -ge 0 -and $i -lt $Custom.Count) {
        $r = $Custom[$i]
        $txtCustFolder.Text = [string]$r.folder
        $txtCustKeys.Text   = (@($r.keywords) -join ', ')
        $chkCustWhole.Checked = [bool]$r.wholeWord
    }
})

$btnBrowse.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = T 'browse.desc'
    $d.SelectedPath = $txtRoot.Text
    if ($d.ShowDialog() -eq 'OK') { $txtRoot.Text = $d.SelectedPath }
})

$btnSave.Add_Click({
    try {
        # a filter typed but not yet added is almost certainly meant to be saved too
        if ($txtCustFolder.Text.Trim() -ne '' -and $txtCustKeys.Text.Trim() -ne '') { if (-not (Add-CustomFilter)) { return } }
        if (-not (Save-Rules)) { return }
        if (-not (Test-Task $TaskName)) {
            $ans = Show-Msg (T 'ask.enable') 'YesNo' 'Question'
            if ([string]$ans -eq 'Yes') { $f.Cursor = 'WaitCursor'; Enable-Auto; $f.Cursor = 'Default' }
        }
        Set-Footer 'foot.saved' @((Get-Date -Format 'HH:mm:ss'))
        Update-Status
    } catch { Show-Error ((T 'err.save') + $_.Exception.Message) }
})
$btnClose.Add_Click({ $f.Close() })

$btnEnable.Add_Click({
    try {
        if (-not (Test-Path -LiteralPath $RulesPath)) { if (-not (Save-Rules)) { return } }
        $f.Cursor = 'WaitCursor'
        Enable-Auto
        Update-Status
    } catch { Show-Error $_.Exception.Message } finally { $f.Cursor = 'Default' }
})
$btnLegacy.Add_Click({
    try { Remove-LegacyAsAdmin; Update-Status } catch { Show-Error $_.Exception.Message }
})
$btnDisable.Add_Click({
    try { $f.Cursor = 'WaitCursor'; Invoke-Engine @('-Uninstall') | Out-Null; Update-Status }
    catch { Show-Error $_.Exception.Message } finally { $f.Cursor = 'Default' }
})
$btnSortNow.Add_Click({
    try {
        if (-not (Save-Rules)) { return }
        $f.Cursor = 'WaitCursor'
        Invoke-Engine @('-Quiet') | Out-Null
        Update-Status
        Set-Footer 'foot.sorted' @((Get-Date -Format 'HH:mm:ss'))
    } catch { Show-Error $_.Exception.Message } finally { $f.Cursor = 'Default' }
})
$btnPreview.Add_Click({
    try {
        if (-not (Save-Rules)) { return }
        $f.Cursor = 'WaitCursor'
        $out = @(Invoke-Engine @('-Preview') -Capture)
        $f.Cursor = 'Default'
        $lstLog.BeginUpdate(); $lstLog.Items.Clear()
        [void]$lstLog.Items.Add((T 'preview.head'))
        foreach ($l in $out) { if ([string]$l -ne '' -and -not ([string]$l).StartsWith('PREVIEW')) { [void]$lstLog.Items.Add([string]$l) } }
        $lstLog.EndUpdate()
    } catch { Show-Error $_.Exception.Message } finally { $f.Cursor = 'Default' }
})
$btnOpenRoot.Add_Click({ if (Test-Path -LiteralPath $txtRoot.Text) { Start-Process explorer.exe -ArgumentList ('"' + $txtRoot.Text + '"') } })
$btnRefresh.Add_Click({ Update-Status })
$lnkRepo.Add_LinkClicked({ Start-Process $RepoUrl })
$lnkSite.Add_LinkClicked({ Start-Process $SiteUrl })
$tabs.Add_SelectedIndexChanged({ if ($tabs.SelectedTab -eq $tabStatus) { Update-Status } })

$btnUpdate.Add_Click({
    $btnUpdate.Enabled = $false; $btnSave.Enabled = $false
    $prog.Visible = $true; $prog.Value = 0
    $lblUpd.Text = T 'upd.connecting'
    $f.Refresh()
    try {
        $cb = {
            param($i, $total, $code, $found)
            $prog.Maximum = $total
            $prog.Value = [Math]::Min($i, $total)
            $lblUpd.Text = Fmt (T 'upd.progress') @($i, $total, $code, $found)
            [System.Windows.Forms.Application]::DoEvents()
        }
        $r = Update-Catalog -Dir $AppDir -OnProgress $cb
        $script:catalog = Load-Catalog -Dir $AppDir
        $script:AllCourses = @($script:catalog.courses)
        Update-Depts; Update-Courses; Update-CatalogLabel
        $lblUpd.Text = Fmt (T 'upd.done') @($r.count)
    } catch {
        $lblUpd.Text = T 'upd.failed'
        Show-Warn ((T 'err.update') + $_.Exception.Message)
    } finally {
        $prog.Visible = $false; $btnUpdate.Enabled = $true; $btnSave.Enabled = $true
    }
})

# ---------- start
$session = $null
if (Test-Path -LiteralPath $SessionPath) {
    try { $session = Get-Content -LiteralPath $SessionPath -Raw -Encoding UTF8 | ConvertFrom-Json; Import-Rules -Path $SessionPath }
    catch { Write-UiLog ('session load failed: ' + $_.Exception.Message) }
    try { Remove-Item -LiteralPath $SessionPath -Force } catch { }
} else {
    try { Import-Rules } catch { Write-UiLog ('rules load failed: ' + $_.Exception.Message) }
}
Update-Depts
Update-Courses
$clbTypes.Enabled = $chkByType.Checked
$chkOther.Enabled = $chkByType.Checked
Write-UiLog 'lists filled'
if ($session) {
    if ($session.footerKey) { Set-Footer ([string]$session.footerKey) @($session.footerArgs | ForEach-Object { [string]$_ }) }
    try { $tabs.SelectedIndex = [int]$session.selectedTab } catch { }
}
elseif ($script:ImportedLegacy) { Set-Footer 'foot.legacy' }
elseif (-not (Test-Path -LiteralPath $RulesPath)) { Set-Footer 'foot.first' }
Set-Language $script:Lang -NoSave
if ($script:FooterKey -eq '' -and $script:TaskState -eq 'legacy') { Set-Footer 'foot.oldTask' }
Write-UiLog 'ready'

[System.Windows.Forms.Application]::add_ThreadException({
    param($s, $e)
    Write-UiLog ('ERROR ' + $e.Exception.ToString())
    try { Show-Error ($e.Exception.Message) } catch { }
})

$f.Add_Shown({ if ($script:Lang -eq 'ar') { Set-Direction $true }; Write-UiLog 'shown' })
try { [System.Windows.Forms.Application]::Run($f) }
catch { Write-UiLog ('FATAL ' + $_.Exception.ToString()) }
