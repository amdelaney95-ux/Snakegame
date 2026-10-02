param(
    [string]$ProjectPath = (Split-Path -Parent $PSScriptRoot),
    [string]$GodotExecutable = 'C:\Users\adeu\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath (Join-Path $ProjectPath 'project.godot'))) {
    $ProjectPath = Join-Path $PSScriptRoot '..\project'
}
if (-not (Test-Path -LiteralPath (Join-Path $ProjectPath 'project.godot'))) {
    throw 'Project not found. Supply -ProjectPath pointing to the game folder.'
}
if (-not (Test-Path -LiteralPath $GodotExecutable -PathType Leaf)) {
    throw 'Godot not found. Supply -GodotExecutable pointing to the console executable.'
}

$testProfile = Join-Path ([System.IO.Path]::GetTempPath()) ('Snake-Stages-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testProfile | Out-Null
$previousAppData = $env:APPDATA
$suites = @(
    @{ Name = 'test_rules'; Marker = 'RULE CHECKS: \d+ passed, 0 failed' },
    @{ Name = 'test_campaign'; Marker = 'CAMPAIGN PASS: 10 stages, 95 food' },
    @{ Name = 'test_endless'; Marker = 'ENDLESS CHECKS: \d+ passed, 0 failed' },
    @{ Name = 'test_adventure'; Marker = 'ADVENTURE CHECKS: \d+ passed, 0 failed' },
    @{ Name = 'test_phone'; Marker = 'PHONE CHECKS: \d+ passed, 0 failed' }
)

try {
    $env:APPDATA = $testProfile
    Write-Host "Isolated test profile and logs: $testProfile"
    foreach ($suite in $suites) {
        $testScript = 'res://tests/' + $suite.Name + '.gd'
        $logPath = Join-Path $testProfile ($suite.Name + '.log')
        & $GodotExecutable --headless --path $ProjectPath --script $testScript *> $logPath
        $testExit = $LASTEXITCODE
        $testOutput = Get-Content -LiteralPath $logPath -Raw
        Write-Host $testOutput
        if ($testExit -ne 0 -or $testOutput -notmatch $suite.Marker -or $testOutput -match 'SCRIPT ERROR:|Parse Error:') {
            throw "Suite $($suite.Name) failed. Inspect $logPath"
        }
    }
    Write-Host 'All five suites passed. Player saves were isolated from these tests.'
}
finally {
    $env:APPDATA = $previousAppData
}



