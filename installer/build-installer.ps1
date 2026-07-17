#Requires -Version 5.1
<#
.SYNOPSIS
    Builds the Confluence Broken Link Checker MSI installer.
.DESCRIPTION
    Locates WiX Toolset v3 (or downloads portable binaries automatically),
    then compiles BrokenLinkChecker.wxs into BrokenLinkChecker.msi.
    No admin rights or system-wide WiX installation required.
#>

$ErrorActionPreference = "Stop"
$PSScriptRoot_ = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Confluence Broken Link Checker - MSI Builder  " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Locate WiX Toolset binaries ────────────────────────────────────────────
function Find-WiX {
    # a) WIX environment variable (set by system-wide installer)
    if ($env:WIX) {
        $p = Join-Path $env:WIX "bin\candle.exe"
        if (Test-Path $p) { return (Split-Path $p) }
    }
    # b) Common install paths
    $candidates = @(
        "C:\Program Files (x86)\WiX Toolset v3.14\bin",
        "C:\Program Files (x86)\WiX Toolset v3.11\bin",
        "C:\Program Files\WiX Toolset v3.14\bin",
        "C:\Program Files\WiX Toolset v3.11\bin"
    )
    foreach ($c in $candidates) {
        if (Test-Path "$c\candle.exe") { return $c }
    }
    # c) PATH
    $found = Get-Command candle.exe -ErrorAction SilentlyContinue
    if ($found) { return Split-Path $found.Source }
    # d) Local portable copy (downloaded below)
    $local = Join-Path $PSScriptRoot_ "wix-bin\candle.exe"
    if (Test-Path $local) { return (Split-Path $local) }
    return $null
}

$wixBin = Find-WiX

if (-not $wixBin) {
    Write-Host "[!] WiX Toolset v3 not found. Downloading portable binaries..." -ForegroundColor Yellow
    Write-Host "    (No admin rights required)" -ForegroundColor Gray

    $zipUrl   = "https://github.com/wixtoolset/wix3/releases/download/wix3141rtm/wix314-binaries.zip"
    $zipPath  = Join-Path $env:TEMP "wix314-binaries.zip"
    $wixLocal = Join-Path $PSScriptRoot_ "wix-bin"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Host "    Downloading $zipUrl ..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
        Write-Host "    Extracting..." -ForegroundColor Gray
        Expand-Archive -Path $zipPath -DestinationPath $wixLocal -Force
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        $wixBin = $wixLocal
        Write-Host "[OK] WiX portable binaries saved to: $wixLocal" -ForegroundColor Green
    } catch {
        Write-Host ""
        Write-Host "[ERROR] Could not download WiX: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Please install WiX Toolset manually then re-run this script:" -ForegroundColor Yellow
        Write-Host "    winget install WiXToolset.WiXToolset   (run as Administrator)" -ForegroundColor White
        Write-Host "    https://github.com/wixtoolset/wix3/releases" -ForegroundColor White
        Write-Host ""
        Read-Host "Press Enter to exit"
        exit 1
    }
} else {
    Write-Host "[OK] WiX found: $wixBin" -ForegroundColor Green
}

$candle = Join-Path $wixBin "candle.exe"
$light  = Join-Path $wixBin "light.exe"

# ── 2. Validate source files exist ────────────────────────────────────────────
$wxs  = Join-Path $PSScriptRoot_ "BrokenLinkChecker.wxs"
$ps1  = Join-Path (Split-Path $PSScriptRoot_) "BrokenLinkChecker.ps1"
$bat  = Join-Path (Split-Path $PSScriptRoot_) "BrokenLinkChecker.bat"
$lic  = Join-Path $PSScriptRoot_ "License.rtf"
$msi  = Join-Path (Split-Path $PSScriptRoot_) "BrokenLinkChecker.msi"
$wixobj = Join-Path $PSScriptRoot_ "BrokenLinkChecker.wixobj"

foreach ($f in @($wxs, $ps1, $bat, $lic)) {
    if (-not (Test-Path $f)) {
        Write-Host "[ERROR] Required file not found: $f" -ForegroundColor Red
        Read-Host "Press Enter to exit"; exit 1
    }
}

# ── 3. Compile (.wxs → .wixobj) ───────────────────────────────────────────────
Write-Host ""
Write-Host "Compiling $wxs ..." -ForegroundColor Cyan
& $candle $wxs -o $wixobj
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Compilation failed (candle.exe exit $LASTEXITCODE)." -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}

# ── 4. Link (.wixobj → .msi) ──────────────────────────────────────────────────
Write-Host "Linking -> $msi ..." -ForegroundColor Cyan

# Locate WixUIExtension.dll (in the same bin folder)
$uiExt = Join-Path $wixBin "WixUIExtension.dll"
if (-not (Test-Path $uiExt)) {
    Write-Host "[ERROR] WixUIExtension.dll not found in $wixBin" -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}

& $light $wixobj -ext $uiExt -o $msi
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Linking failed (light.exe exit $LASTEXITCODE)." -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}

# Cleanup intermediates
Remove-Item $wixobj -Force -ErrorAction SilentlyContinue
$wixpdb = [IO.Path]::ChangeExtension($msi, ".wixpdb")
Remove-Item $wixpdb -Force -ErrorAction SilentlyContinue

# ── 5. Done ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  SUCCESS!" -ForegroundColor Green
Write-Host "  MSI: $msi" -ForegroundColor Green
Write-Host ""
Write-Host "  Double-click the MSI to install." -ForegroundColor White
Write-Host "  Installs to: %ProgramFiles%\Hyland\BrokenLinkChecker" -ForegroundColor White
Write-Host "  Creates: Start Menu shortcut + Desktop shortcut" -ForegroundColor White
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to exit"
