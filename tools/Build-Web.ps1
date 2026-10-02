param(
    [string]$ProjectPath = (Split-Path -Parent $PSScriptRoot),
    [string]$GodotExecutable = 'godot',
    [string]$NodeExecutable = 'node'
)
$ErrorActionPreference = 'Stop'
$buildPath = Join-Path $ProjectPath '.build'
$outputPath = Join-Path $buildPath 'web'
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
New-Item -ItemType File -Force -Path (Join-Path $buildPath '.gdignore') | Out-Null
& $NodeExecutable (Join-Path $PSScriptRoot 'fetch-web-templates.cjs') $buildPath
if ($LASTEXITCODE -ne 0) { throw 'Web template download failed.' }
$previousAppData = $env:APPDATA
$buildProfile = Join-Path ([IO.Path]::GetTempPath()) ('Snake-Stages-export-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $buildProfile | Out-Null
try {
    $env:APPDATA = $buildProfile
    $importLog = Join-Path $buildPath 'import.log'
    & $GodotExecutable --headless --path $ProjectPath --editor --import --quit *> $importLog
    if ($LASTEXITCODE -ne 0 -or (Get-Content -LiteralPath $importLog -Raw) -match 'SCRIPT ERROR:|Parse Error:') { throw "Import failed: $importLog" }
    $exportLog = Join-Path $buildPath 'export.log'
    & $GodotExecutable --headless --path $ProjectPath --export-release Web (Join-Path $outputPath 'index.html') *> $exportLog
    if ($LASTEXITCODE -ne 0 -or (Get-Content -LiteralPath $exportLog -Raw) -match 'SCRIPT ERROR:|Parse Error:|Export failed') { throw "Web export failed: $exportLog" }
    & $NodeExecutable (Join-Path $PSScriptRoot 'finish-web.cjs') $outputPath
    if ($LASTEXITCODE -ne 0) { throw 'PWA packaging failed.' }
    Write-Host "PWA files ready: $outputPath"
} finally {
    $env:APPDATA = $previousAppData
}

