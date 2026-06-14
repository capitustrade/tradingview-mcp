@echo off
REM Launch TradingView Desktop on Windows with Chrome DevTools Protocol enabled
REM Fixed for Windows Store (MSIX) install
REM Usage: scripts\launch_tv_debug.bat [port]

set PORT=%1
if "%PORT%"=="" set PORT=9222

REM Kill existing TradingView instances
taskkill /F /IM TradingView.exe >nul 2>&1
timeout /t 2 /nobreak >nul

REM Auto-detect TradingView install location
set "TV_EXE="

REM Check common direct install locations first
if exist "%LOCALAPPDATA%\TradingView\TradingView.exe" set "TV_EXE=%LOCALAPPDATA%\TradingView\TradingView.exe"
if exist "%PROGRAMFILES%\TradingView\TradingView.exe" set "TV_EXE=%PROGRAMFILES%\TradingView\TradingView.exe"
if exist "%PROGRAMFILES(x86)%\TradingView\TradingView.exe" set "TV_EXE=%PROGRAMFILES(x86)%\TradingView\TradingView.exe"

REM Check known MSIX / Windows Store path (hardcoded for csana)
if "%TV_EXE%"=="" (
    if exist "C:\Program Files\WindowsApps\TradingView.Desktop_3.0.0.7652_x64__n534cwy3pjxzj\TradingView.exe" (
        set "TV_EXE=C:\Program Files\WindowsApps\TradingView.Desktop_3.0.0.7652_x64__n534cwy3pjxzj\TradingView.exe"
    )
)

REM Try PowerShell to find MSIX install dynamically (fallback)
if "%TV_EXE%"=="" (
    for /f "tokens=*" %%i in ('powershell -NoProfile -Command "(Get-AppxPackage | Where-Object { $_.Name -like '*TradingView*' }).InstallLocation + '\TradingView.exe'" 2^>nul') do (
        if exist "%%i" set "TV_EXE=%%i"
    )
)

if "%TV_EXE%"=="" (
    echo Error: TradingView not found.
    echo Checked: %%LOCALAPPDATA%%\TradingView, %%PROGRAMFILES%%\TradingView, WindowsApps
    echo.
    echo If installed elsewhere, run manually:
    echo   "C:\path\to\TradingView.exe" --remote-debugging-port=%PORT%
    exit /b 1
)

echo Found TradingView at: %TV_EXE%
echo Starting with --remote-debugging-port=%PORT%...
start "" "%TV_EXE%" --remote-debugging-port=%PORT%

echo Waiting for TradingView to start...
timeout /t 5 /nobreak >nul

REM Check if MSIX is ignoring the debug flag (common issue)
:check
curl -s http://localhost:%PORT%/json/version >nul 2>&1
if %errorlevel% neq 0 (
    echo Still waiting for CDP on port %PORT%...
    timeout /t 2 /nobreak >nul

    REM After 30s give up and warn about MSIX limitation
    set /a WAIT+=2
    if %WAIT% geq 30 (
        echo.
        echo WARNING: Could not connect to CDP after 30 seconds.
        echo This is likely because the Windows Store ^(MSIX^) version of TradingView
        echo ignores the --remote-debugging-port flag due to sandboxing.
        echo.
        echo SOLUTION: Use the Chrome web version instead:
        echo   "C:\Program Files\Google\Chrome\Application\chrome.exe" --remote-debugging-port=%PORT% --user-data-dir="%TEMP%\tv-debug" "https://www.tradingview.com/chart/"
        echo.
        exit /b 1
    )
    goto check
)

echo.
echo CDP ready at http://localhost:%PORT%
curl -s http://localhost:%PORT%/json/version
echo.
echo TradingView is ready! You can now use Claude Desktop with the TradingView MCP.
