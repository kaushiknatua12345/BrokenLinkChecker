@echo off
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-installer.ps1"

echo.
echo ================================================
echo  Confluence Broken Link Checker - MSI Builder
echo ================================================
echo.

:: ─── Locate WiX v3 ───────────────────────────────────────────────────────────
set "WIX_BIN="

:: 1. Check WIX environment variable (set by official installer)
if defined WIX (
    if exist "%WIX%\bin\candle.exe" (
        set "WIX_BIN=%WIX%\bin"
        goto :wix_found
    )
)

:: 2. Common install paths
for %%P in (
    "C:\Program Files (x86)\WiX Toolset v3.14\bin"
    "C:\Program Files (x86)\WiX Toolset v3.11\bin"
    "C:\Program Files (x86)\WiX Toolset v3.10\bin"
    "C:\Program Files\WiX Toolset v3.14\bin"
    "C:\Program Files\WiX Toolset v3.11\bin"
) do (
    if exist "%%~P\candle.exe" (
        set "WIX_BIN=%%~P"
        goto :wix_found
    )
)

:: 3. PATH
where candle.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    set "WIX_BIN="
    goto :wix_found_path
)

:: ─── WiX not found — download portable binaries (no admin required) ─────────
echo [!] WiX Toolset v3 not found.  Downloading portable binaries...
echo     (No installation or admin rights required.)
echo.

set "WIX_ZIP=%TEMP%\wix314-binaries.zip"
set "WIX_LOCAL=%~dp0wix-bin"
set "WIX_URL=https://github.com/wixtoolset/wix3/releases/download/wix3141rtm/wix314-binaries.zip"

if exist "%WIX_LOCAL%\candle.exe" (
    echo [OK] Using cached portable WiX in: %WIX_LOCAL%
    set "WIX_BIN=%WIX_LOCAL%"
    goto :wix_found
)

:: Download via PowerShell (available on all Windows 10+ systems)
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol='Tls12'; Invoke-WebRequest -Uri '%WIX_URL%' -OutFile '%WIX_ZIP%'"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Download failed. Check your internet connection.
    echo.
    echo Alternatively, install WiX Toolset manually:
    echo   winget install WiXToolset.WiXToolset   (run as Administrator)
    echo   https://github.com/wixtoolset/wix3/releases
    echo.
    pause
    exit /b 1
)

:: Extract the zip
echo Extracting...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Path '%WIX_ZIP%' -DestinationPath '%WIX_LOCAL%' -Force"
del /q "%WIX_ZIP%" 2>nul

if not exist "%WIX_LOCAL%\candle.exe" (
    echo [ERROR] Extraction failed.
    pause
    exit /b 1
)

echo [OK] WiX portable binaries ready in: %WIX_LOCAL%
set "WIX_BIN=%WIX_LOCAL%"

:wix_found
echo [OK] WiX Toolset found: %WIX_BIN%
set "CANDLE=%WIX_BIN%\candle.exe"
set "LIGHT=%WIX_BIN%\light.exe"
goto :build

:wix_found_path
echo [OK] WiX Toolset found in PATH
set "CANDLE=candle.exe"
set "LIGHT=light.exe"

:: ─── Build ───────────────────────────────────────────────────────────────────
:build
echo.
echo Compiling BrokenLinkChecker.wxs ...
"%CANDLE%" BrokenLinkChecker.wxs -o BrokenLinkChecker.wixobj
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Compilation failed. Check the output above.
    pause
    exit /b 1
)

echo.
echo Linking ...
"%LIGHT%" BrokenLinkChecker.wixobj ^
    -ext WixUIExtension ^
    -o "..\BrokenLinkChecker.msi"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Linking failed. Check the output above.
    pause
    exit /b 1
)

:: Cleanup intermediate files
del /q BrokenLinkChecker.wixobj 2>nul
del /q BrokenLinkChecker.wixpdb 2>nul

echo.
echo ================================================
echo  SUCCESS!
echo  Output: BrokenLinkChecker.msi
echo.
echo  Install by double-clicking the MSI file.
echo  Installs to: %%ProgramFiles%%\Hyland\BrokenLinkChecker
echo  Creates:     Start Menu shortcut + Desktop shortcut
echo ================================================
echo.
pause
