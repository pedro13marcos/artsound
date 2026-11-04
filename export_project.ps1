<#
.SYNOPSIS
    Exports ArtSound for itch.io (Web and Windows Desktop).
.DESCRIPTION
    Runs Godot headless export for Web and Windows Desktop, then compresses
    both outputs into ready-to-upload zip archives inside the Exports/ directory.
#>

param(
    [string]$GodotPath = "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $GodotPath)) {
    # Check if godot is in PATH
    $cmd = Get-Command "godot" -ErrorAction SilentlyContinue
    if ($cmd) {
        $GodotPath = $cmd.Source
    } else {
        Write-Error "Could not find Godot at '$GodotPath' or in PATH. Please provide -GodotPath."
        exit 1
    }
}

$projectDir = $PSScriptRoot
$exportsDir = Join-Path $projectDir "Exports"
$webDir = Join-Path $exportsDir "Web"
$winDir = Join-Path $exportsDir "Windows"

New-Item -ItemType Directory -Force -Path $webDir | Out-Null
New-Item -ItemType Directory -Force -Path $winDir | Out-Null

function Run-GodotExport([string]$preset, [string]$target) {
    Write-Host "Exporting '$preset' -> $target..."
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $GodotPath
    $pinfo.Arguments = "--headless --path `"$projectDir`" --export-release `"$preset`" `"$target`""
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()

    if ($p.ExitCode -ne 0) {
        Write-Host "Export STDOUT: $stdout"
        Write-Host "Export STDERR: $stderr"
        throw "Godot export failed for preset '$preset' with code $($p.ExitCode)"
    }
}

# 1. Export Windows Desktop
$winExe = Join-Path $winDir "ArtSound.exe"
Run-GodotExport -preset "Windows Desktop" -target $winExe

# 2. Export Web
$webIndex = Join-Path $webDir "index.html"
Run-GodotExport -preset "Web" -target $webIndex

# 3. Create zip archives for itch.io
$webZip = Join-Path $exportsDir "artsound_web_itch.zip"
$winZip = Join-Path $exportsDir "artsound_windows_itch.zip"

if (Test-Path $webZip) { Remove-Item -Force $webZip }
if (Test-Path $winZip) { Remove-Item -Force $winZip }

Write-Host "Packaging Web build -> $webZip"
Get-ChildItem -Path $webDir | Compress-Archive -DestinationPath $webZip -CompressionLevel Optimal

Write-Host "Packaging Windows build -> $winZip"
Get-ChildItem -Path $winDir | Compress-Archive -DestinationPath $winZip -CompressionLevel Optimal

Write-Host "`nAll exports completed successfully!"
Get-Item $webZip, $winZip | Select-Object Name, Length, LastWriteTime
