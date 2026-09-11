@echo off
setlocal EnableDelayedExpansion

if /i "%~1"=="/ROUTEFIX" goto ROUTEFIX

:MENU
cls
echo ========================================
echo  Network Reset Tool
echo ========================================
echo.
echo  [1] Quick reset: disable system proxy + flush DNS   (no admin)
echo  [2] Clean VPN/Proxy leftover routes                 (admin required)
echo  [3] Exit
echo.
choice /c 123 /n /m "Select [1/2/3]: "
if errorlevel 3 goto END
if errorlevel 2 goto ELEVATE
goto QUICK

:QUICK
cls
echo ========================================
echo Network Reset Script (Quick Mode)
echo ========================================
echo.

echo [1/4] Checking current proxy settings...
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer
echo.

echo [2/4] Disabling system proxy...
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f
echo System proxy disabled.
echo.

echo [3/4] Flushing DNS cache...
ipconfig /flushdns
echo DNS cache flushed.
echo.

echo [4/4] Verifying proxy is disabled...
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable
echo.

echo ========================================
echo Network reset completed!
echo ========================================
echo.

echo Current IP Configuration:
ipconfig
echo.

echo Testing network connection (pinging baidu.com)...
ping -n 4 www.baidu.com
echo.

choice /c 12 /n /m "Back to menu [1] or exit [2]: "
if errorlevel 2 goto END
goto MENU

:ELEVATE
echo Requesting administrator privileges (confirm the UAC prompt)...
powershell -NoProfile -Command "try { Start-Process -FilePath '%~f0' -ArgumentList '/ROUTEFIX' -Verb RunAs } catch { exit 1 }"
if errorlevel 1 (
    echo.
    echo UAC prompt was cancelled or failed. Route cleanup was NOT run.
    timeout /t 4 >nul
)
goto END

:ROUTEFIX
cls
net session >nul 2>&1
if errorlevel 1 (
    echo ERROR: Administrator privileges are required for route cleanup.
    pause
    goto END
)
echo ========================================
echo  VPN/Proxy Leftover Route Cleanup
echo ========================================
echo.
echo Removes IPv4 routes still bound to a missing or dead network
echo adapter (typical leftovers of Clash TUN / WireGuard / VPN after
echo an abnormal exit), so traffic falls back to the physical NIC.
echo Routes on healthy UP adapters are always kept.
echo.

echo [1/4] Network adapters and their status:
powershell -NoProfile -Command "Get-NetAdapter -IncludeHidden | Sort-Object ifIndex | Format-Table ifIndex, Status, Name -AutoSize | Out-String -Width 200"
echo.

echo [2/4] Current IPv4 route table:
route print -4
echo.

echo [3/4] Scanning and removing orphaned routes...
echo.
powershell -NoProfile -Command ^
    "$ErrorActionPreference='SilentlyContinue';" ^
    "$live=@{};" ^
    "Get-NetAdapter -IncludeHidden | ForEach-Object { $live[$_.ifIndex] = [string]$_.Status };" ^
    "$dead = @('Disconnected','Not Present','Disabled','Broken');" ^
    "$orphans = @(Get-NetRoute -AddressFamily IPv4 | Where-Object { $_.Protocol -ne 'Local' -and $_.InterfaceIndex -ne 1 } | Where-Object { $st = $live[$_.InterfaceIndex]; ($null -eq $st) -or ($dead -contains $st) });" ^
    "if ($orphans.Count -eq 0) { Write-Host 'No orphaned routes found. Route table looks clean.' }" ^
    "else {" ^
    "  $orphans | ForEach-Object {" ^
    "    Write-Host ('ORPHAN ROUTE: {0}   next-hop: {1}   ifIndex: {2}   adapter: {3}' -f $_.DestinationPrefix, $_.NextHop, $_.InterfaceIndex, $live[$_.InterfaceIndex]);" ^
    "    Remove-NetRoute -DestinationPrefix $_.DestinationPrefix -InterfaceIndex $_.InterfaceIndex -Confirm:$false -ErrorAction SilentlyContinue" ^
    "  };" ^
    "  Write-Host ('Removed {0} orphaned route(s).' -f $orphans.Count)" ^
    "}"
echo.

echo [4/4] Verifying after cleanup...
ipconfig /flushdns
echo.
route print -4
echo.

echo Testing network connection (pinging baidu.com)...
ping -n 4 www.baidu.com
echo.

echo Done. Press any key to close...
pause >nul
goto END

:END
endlocal
exit /b 0
