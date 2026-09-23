<#
    Catalog.ps1 - downloads the KFUPM undergraduate course catalog
    from the official bulletin and saves it as courses.json.

    Source: https://bulletin.kfupm.edu.sa/course-details?subject_code=XX&level=Undergraduate
    Public pages, no login. Run it once, and again whenever the catalog changes.
#>
# البرنامج يُثبَّت للقراءة فقط، فالكتالوج المحدّث يُكتب في مجلد بيانات المستخدم
function Get-AppDataDir {
    $d = Join-Path $env:APPDATA 'KFUPM Sorter'
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    return $d
}
function Get-CatalogPath { param([string]$Dir) Join-Path (Get-AppDataDir) 'courses.json' }

function Parse-CoursesFromHtml {
    param([string]$Html, [string]$Subject)
    # flatten the markup to plain text, then read the printed course lines
    $t = [regex]::Replace($Html, '(?is)<script.*?</script>', ' ')
    $t = [regex]::Replace($t,   '(?is)<style.*?</style>',  ' ')
    $t = [regex]::Replace($t,   '(?s)<[^>]+>', ' ')
    $t = [System.Net.WebUtility]::HtmlDecode($t)
    $t = [regex]::Replace($t, '\s+', ' ')

    $out = New-Object System.Collections.ArrayList
    # pattern printed by the bulletin:  COE 202 - Digital Logic Design 3-0-3
    $rx = [regex]'([A-Za-z]{2,5})\s+(\d{3})\s*[-–]\s*(.{2,95}?)\s+(\d+)\s*-\s*(\d+)\s*-\s*(\d+)'
    foreach ($m in $rx.Matches($t)) {
        $code = $m.Groups[1].Value.ToUpper()
        if ($code -ne $Subject.ToUpper()) { continue }   # ignore stray matches
        $num    = $m.Groups[2].Value
        $title  = $m.Groups[3].Value.Trim(' ', '-', [char]0x2013)
        $credit = [int]$m.Groups[6].Value
        $null = $out.Add([ordered]@{
            code    = ('{0} {1}' -f $code, $num)
            title   = $title
            credits = $credit
            subject = $code
        })
    }
    # de-duplicate by code
    $seen = @{}
    $uniq = New-Object System.Collections.ArrayList
    foreach ($c in $out) {
        if (-not $seen.ContainsKey($c.code)) { $seen[$c.code] = $true; $null = $uniq.Add($c) }
    }
    return $uniq
}

function Update-Catalog {
    param(
        [string]$Dir,
        [scriptblock]$OnProgress = $null   # called with (index, total, subjectCode, foundCount)
    )
    $subjectsPath = Join-Path $Dir 'data\subjects.json'
    if (-not (Test-Path -LiteralPath $subjectsPath)) { $subjectsPath = Join-Path $Dir 'subjects.json' }
    if (-not (Test-Path -LiteralPath $subjectsPath)) { throw 'subjects.json is missing.' }
    $subjects = Get-Content -LiteralPath $subjectsPath -Raw -Encoding UTF8 | ConvertFrom-Json

    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

    $all     = New-Object System.Collections.ArrayList
    $failed  = New-Object System.Collections.ArrayList
    $i = 0
    foreach ($s in $subjects) {
        $i++
        $found = 0
        $url = 'https://bulletin.kfupm.edu.sa/course-details?subject_code={0}&level=Undergraduate' -f $s.code
        try {
            $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 25
            $courses = Parse-CoursesFromHtml -Html $resp.Content -Subject $s.code
            foreach ($c in $courses) { $null = $all.Add($c) }
            $found = $courses.Count
        } catch {
            $null = $failed.Add($s.code)
        }
        if ($OnProgress) { & $OnProgress $i $subjects.Count $s.code $found }
    }

    if ($all.Count -eq 0) { throw 'No courses could be read from the bulletin. Check your internet connection.' }

    $payload = [ordered]@{
        updated = (Get-Date -Format 'yyyy-MM-dd HH:mm')
        source  = 'bulletin.kfupm.edu.sa'
        count   = $all.Count
        courses = @($all)
    }
    $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Get-CatalogPath $Dir) -Encoding UTF8
    return [ordered]@{ count = $all.Count; failed = @($failed) }
}

function Load-Catalog {
    param([string]$Dir)
    $p = Get-CatalogPath $Dir
    if (Test-Path -LiteralPath $p) {
        return (Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json)
    }
    # fall back to the catalog shipped with the app so it works offline on day one
    foreach ($seed in @((Join-Path $Dir 'data\courses.json'), (Join-Path $Dir 'courses.json'))) {
        if (Test-Path -LiteralPath $seed) {
            return (Get-Content -LiteralPath $seed -Raw -Encoding UTF8 | ConvertFrom-Json)
        }
    }
    return $null
}
