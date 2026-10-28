param(
    [string]$MaaDir = '',
    [switch]$Launch,
    [switch]$Remove,
    [switch]$AllowRunning,
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
if ([string]::IsNullOrWhiteSpace($MaaDir)) {
    foreach ($candidate in @($PSScriptRoot, (Split-Path -Parent $PSScriptRoot))) {
        if (Test-Path -LiteralPath (Join-Path $candidate 'MAA.exe')) {
            $MaaDir = $candidate
            break
        }
    }
    if ([string]::IsNullOrWhiteSpace($MaaDir)) {
        throw 'Put this patch folder inside your MAA installation folder, next to MAA.exe; or pass -MaaDir with the installation path.'
    }
}
$utf8 = New-Object System.Text.UTF8Encoding($false)
function File-Hash([string]$path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($path))) }
    finally { $sha.Dispose() }
}
$MaaDir = [IO.Path]::GetFullPath($MaaDir).TrimEnd('\')
$exe = Join-Path $MaaDir 'MAA.exe'
if (!(Test-Path -LiteralPath $exe)) { throw "Cannot find MAA.exe in: $MaaDir" }
$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') | ConvertFrom-Json
$cache = Join-Path $MaaDir 'cache\resource'
$target = Join-Path $cache 'tasks\LocalYueMan20261028_custom.json'
$templateDir = Join-Path $cache 'template\LocalYueMan20261028'
$running = @(Get-Process -Name MAA -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe })
if ($running.Count -gt 0 -and !$AllowRunning -and !$CheckOnly) {
    throw 'Please exit MAA completely, then run this tool again. No files were changed.'
}
if ($Remove) {
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target }
    foreach ($item in $manifest.entries) {
        $file = Join-Path $templateDir ($item.name + '.png')
        if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file }
    }
    Write-Host 'Moon theme patch removed. Official resources and your settings were kept.'
    exit 0
}
# Read current official resources at every application. Never freeze an old official next list.
$tasks = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
# MAA permits field names that differ only by case. Windows PowerShell's
# ConvertFrom-Json rejects those; the framework JSON reader preserves them.
Add-Type -AssemblyName System.Web.Extensions
$reader = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$reader.MaxJsonLength = [int]::MaxValue
$reader.RecursionLimit = 2048
function Read-TaskLayer([string]$dir, [bool]$isCache) {
    if (!(Test-Path -LiteralPath $dir)) { return }
    $layerNames = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($file in Get-ChildItem -LiteralPath $dir -Recurse -File -Filter '*.json') {
        if ($file.FullName -eq $target) { continue }
        $data = $reader.DeserializeObject([IO.File]::ReadAllText($file.FullName))
        foreach ($p in $data.GetEnumerator()) {
            if (!$layerNames.Add($p.Key)) { throw "Duplicate task in current resources: $($p.Key)" }
            if ($tasks.ContainsKey($p.Key)) {
                foreach ($field in $p.Value.GetEnumerator()) {
                    $tasks[$p.Key][$field.Key] = $field.Value
                }
            } else { $tasks.Add($p.Key, $p.Value) }
            if ($isCache -and @($manifest.entries.entry) -contains $p.Key) {
                throw "Official cache now defines $($p.Key). Compatibility review required; patch was not overwritten."
            }
        }
    }
}
Read-TaskLayer (Join-Path $MaaDir 'resource\tasks') $false
Read-TaskLayer (Join-Path $cache 'tasks') $true
$patch = [ordered]@{}
foreach ($item in $manifest.entries) {
    if (!$tasks.ContainsKey($item.entry) -or !$tasks.ContainsKey($item.base)) {
        throw "MAA resource layout changed; missing $($item.entry) or $($item.base). No files were changed."
    }
    if ($tasks.ContainsKey($item.task)) { throw "Task name conflict: $($item.task)" }
    $next = @($tasks[$item.entry]['next'] | Where-Object { $_ -ne $item.task })
    $patch[$item.entry] = [ordered]@{ next = @($item.task) + $next }
    $patch[$item.task] = [ordered]@{
        Doc = 'Local month-full / YueMan theme support. Managed by the external patch kit.'
        baseTask = $item.base
        algorithm = 'MatchTemplate'
        action = 'ClickRect'
        template = $item.template
        templThreshold = $item.threshold
        maskRange = @(0, 255)
        roi = @($item.roi)
        specificRect = @($item.click)
        postDelay = $item.postDelay
    }
}
$json = $patch | ConvertTo-Json -Depth 20
# All reads, collision checks, and template existence checks finish before any writes.
foreach ($item in $manifest.entries) {
    if (!(Test-Path -LiteralPath (Join-Path $PSScriptRoot ('templates\' + $item.name + '.png')))) {
        throw "Missing bundled template: $($item.name)"
    }
}
if ($CheckOnly) {
    $ok = Test-Path -LiteralPath $target
    if ($ok) {
        $existing = Get-Content -Raw -Encoding UTF8 -LiteralPath $target | ConvertFrom-Json
        foreach ($name in $patch.Keys) {
            $prop = $existing.PSObject.Properties[$name]
            if ($null -eq $prop -or (($prop.Value | ConvertTo-Json -Depth 20 -Compress) -ne ($patch[$name] | ConvertTo-Json -Depth 20 -Compress))) { $ok = $false }
        }
        if (@($existing.PSObject.Properties).Count -ne $patch.Count) { $ok = $false }
    }
    foreach ($item in $manifest.entries) {
        $dest = Join-Path $templateDir ($item.name + '.png')
        $src = Join-Path $PSScriptRoot ('templates\' + $item.name + '.png')
        if (!(Test-Path -LiteralPath $dest)) { $ok = $false }
        elseif ((File-Hash $dest) -ne (File-Hash $src)) { $ok = $false }
    }
    if (!$ok) { throw 'Patch is missing or differs from current resources. Run the restore tool after exiting MAA.' }
    Write-Host 'PASS: all 18 task definitions and 9 templates are installed and current.'
    exit 0
}
[IO.Directory]::CreateDirectory((Split-Path -Parent $target)) | Out-Null
[IO.Directory]::CreateDirectory($templateDir) | Out-Null
foreach ($item in $manifest.entries) {
    $src = Join-Path $PSScriptRoot ('templates\' + $item.name + '.png')
    $dest = Join-Path $templateDir ($item.name + '.png')
    if (!(Test-Path -LiteralPath $dest) -or (File-Hash $dest) -ne (File-Hash $src)) {
        Copy-Item -LiteralPath $src -Destination $dest -Force
    }
}
if (!(Test-Path -LiteralPath $target) -or [IO.File]::ReadAllText($target) -ne $json) {
    $backup = Join-Path $PSScriptRoot 'backups'
    [IO.Directory]::CreateDirectory($backup) | Out-Null
    if (Test-Path -LiteralPath $target) {
        Copy-Item -LiteralPath $target -Destination (Join-Path $backup ((Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-patch.json'))
    }
    $temp = $target + '.tmp'
    [IO.File]::WriteAllText($temp, $json, $utf8)
    Move-Item -LiteralPath $temp -Destination $target -Force
}
Write-Host 'Moon theme patch is ready. No official resource files or task settings were edited.'
if ($Launch) { Start-Process -FilePath $exe -WorkingDirectory $MaaDir }
