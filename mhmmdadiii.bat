@echo off
:: my windows tweaks, collected over a few late nights of messing with regedit/services.msc
:: v1.4 - added HAGS reg key after reading it doesn't auto enable on older drivers
:: v1.3 - nuked the part that disabled defender, dumb idea, dont do that
:: v1.2 - fixed nagle's tweak only hitting one adapter instead of looping all of them
:: v1.1 - added restore point bc i bricked search indexing once and panicked
:: started keeping this as a script instead of doing it manually every reinstall lol
:: also a reupload, github keeps fucking banning me


:: needs admin or half this silently no-ops and you wont know why
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo run this as admin idiot
    echo right click -^> run as administrator
    pause
    exit /b 1
)

setlocal EnableDelayedExpansion
title rhinopill
color 0A

echo ============================================================
echo   rhinopill.bat
echo ============================================================
echo.
echo this does the usual stuff:
echo   - ultimate perf power plan
echo   - turns off animations/transparency junk
echo   - kills game dvr (this one actually matters, rest is a placebo)
echo   - disables telemetry tasks, not defender/firewall/updates, leave those alone
echo   - tcp/nagle tweaks
echo   - temp cleanup
echo   - some scheduler priority stuff for foreground apps
echo.
echo restore point gets made first in case it eats itself
echo.
set /p CONFIRM="run it? (y/n): "
if /i not "%CONFIRM%"=="Y" exit /b 0

:: ---------------------------------------------------------------
:: restore point
:: not 100% reliable if system protection is off by default (it is on a lot of fresh installs)
:: check with rstrui after if you're a niggerlicious like me
:: ---------------------------------------------------------------
echo.
echo [1/10] making restore point...
powershell -NoProfile -Command "Checkpoint-Computer -Description 'Pre-rhinopill' -RestorePointType 'MODIFY_SETTINGS'" >nul 2>&1
echo     DONE 

:: ---------------------------------------------------------------
:: power plan
:: ultimate perf plan is hidden by default, this is the duplicatescheme trick
:: check if this still works on 24H2, ms likes moving this stuff around
:: ---------------------------------------------------------------
echo.
echo [2/10] power plan -^> ultimate performance...
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 >nul 2>&1
for /f "tokens=4" %%i in ('powercfg /list ^| findstr /i "Ultimate"') do set ULTGUID=%%i
if defined ULTGUID (
    powercfg /setactive %ULTGUID%
    echo     ULTIMATE PERFOMANCE ON
) else (
    REM fallback for whatever windows sku doesnt expose ultimate (happens sometimes, no idea why)
    powercfg /setactive SCHEME_MIN
    echo     NO ULTIMATE SCHEME FOUND, USED HIGH PREF INSTEAD
)

REM usb selective suspend off, fixes random mouse stutter / wifi dongle drops for me
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 >nul 2>&1
powercfg /setactive SCHEME_CURRENT >nul 2>&1

REM hibernation off, dont need it on desktop, frees like 8-16gb depending on ram
powercfg -h off
echo  HIBERNATION OFF

:: ---------------------------------------------------------------
:: visual fx
:: this is the "best performance" radio button basically, just doing it via registry
:: so it doesnt fight with itself if you also change it in gui later
:: ---------------------------------------------------------------
echo.
echo [3/10] visual effects...
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f >nul
reg add "HKCU\Control Panel\Desktop" /v DragFullWindows /t REG_SZ /d 0 /f >nul
reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 0 /f >nul
reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d 0 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAnimations /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ListviewAlphaSelect /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ListviewShadow /t REG_DWORD /d 0 /f >nul
echo    DONE

:: ---------------------------------------------------------------
:: game dvr / overlay
:: this is the one that actually does something noticeable, rest of the gui stuff
:: is honestly mostly cosmetic. dvr captures in background even when you "never used it"
:: ---------------------------------------------------------------
echo.
echo [4/10] killing game dvr / xbox overlay...
reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 0 /f >nul
reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehaviorMode /t REG_DWORD /d 2 /f >nul
reg add "HKCU\System\GameConfigStore" /v GameDVR_HonorUserFSEBehaviorMode /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f >nul
echo    DVR, DONE

REM HAGS - hw accelerated gpu scheduling, needs reboot to actually kick in
REM only really matters on newer gpu drivers, older cards just ignore this key
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 2 /f >nul
echo    HAGS FLAG SET

:: ---------------------------------------------------------------
:: telemetry tasks
:: this list is from poking around task scheduler manually and turning off
:: anything that looked like ms spyware-ish stuff. probably missing some, ms
:: adds new ones every couple updates. not touching update/defender related tasks
:: ---------------------------------------------------------------
echo.
echo [5/10] disabling telemetry tasks...
set TASKS=Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser ^
Microsoft\Windows\Application Experience\ProgramDataUpdater ^
Microsoft\Windows\Autochk\Proxy ^
Microsoft\Windows\Customer Experience Improvement Program\Consolidator ^
Microsoft\Windows\Customer Experience Improvement Program\UsbCeip ^
Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector ^
Microsoft\Windows\Feedback\Siuf\DmClient ^
Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload ^
Microsoft\Windows\Maintenance\WinSAT ^
Microsoft\Windows\PI\Sqm-Tasks ^
Microsoft\Windows\Windows Error Reporting\QueueReporting

for %%T in (%TASKS%) do (
    schtasks /Change /TN "%%T" /Disable >nul 2>&1
)
echo    DONE, BUNCH OF CEIP/TELEMETRY OFF

REM diagtrack = "connected user experiences and telemetry" service, classic one to kill
REM does NOT affect windows update despite what some other "debloat" scripts claim
sc config DiagTrack start= disabled >nul 2>&1
net stop DiagTrack >nul 2>&1
echo     DIAGTRACK SERVICE DISABLED

:: ---------------------------------------------------------------
:: services
:: setting these to manual not disabled, fully reversible, dont @ me
:: ---------------------------------------------------------------
echo.
echo [6/10] non essential services -^> manual...
sc config SysMain start= demand >nul 2>&1
REM ^ sysmain (old superfetch). actually helps on hdd, can cause stutter on some nvme setups
REM   if you've got an ssd and notice stutter, this is the first thing id revert
sc config Spooler start= demand >nul 2>&1
sc config Fax start= demand >nul 2>&1
sc config WSearch start= demand >nul 2>&1
sc config bthserv start= demand >nul 2>&1
echo     DONE

:: ---------------------------------------------------------------
:: network
:: nagle's algo disable is the one that actually matters for latency
:: rest is more "shouldnt hurt" than "definitely helps"
:: ---------------------------------------------------------------
echo.
echo [7/10] network tweaks...
netsh int tcp set global autotuninglevel=normal >nul
netsh int tcp set global congestionprovider=ctcp >nul
netsh int tcp set global ecncapability=disabled >nul
netsh int tcp set heuristics disabled >nul

REM loop every network adapter interface key and kill nagle's algorithm on each
REM (used to only do this on one adapter, broke when i switched from wifi to ethernet, fixed now)
for /f "tokens=*" %%K in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" 2^>nul') do (
    reg add "%%K" /v TcpAckFrequency /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "%%K" /v TCPNoDelay /t REG_DWORD /d 1 /f >nul 2>&1
)
echo     TCP TUNED, NAGLE OFF ALL ADAPTERS

:: ---------------------------------------------------------------
:: memory
:: only worth doing if you have 16gb+, on 8gb this can actually make stuff worse
:: bc it stops windows from paging out kernel stuff when it needs the ram elsewhere
:: ---------------------------------------------------------------
echo.
echo [8/10] memory stuff...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v DisablePagingExecutive /t REG_DWORD /d 1 /f >nul
REM clearpagefileatshutdown is a thing too but it just slows shutdown down for a security
REM benefit most people dont need on a personal desktop, leaving it off/commented
:: reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v ClearPageFileAtShutdown /t REG_DWORD /d 1 /f >nul
echo     kernel stays resident in ram now
echo     (if you've got 8gb or less, maybe skip this one / revert it later)

:: ---------------------------------------------------------------
:: cleanup
:: ---------------------------------------------------------------
echo.
echo [9/10] cleaning temp junk...
del /q/f/s "%TEMP%\*" >nul 2>&1
del /q/f/s "C:\Windows\Temp\*" >nul 2>&1
del /q/f/s "C:\Windows\Prefetch\*" >nul 2>&1
echo     temp + prefetch cleared

cleanmgr /sagerun:1 >nul 2>&1
REM ^ this only works if you've run cleanmgr /sageset:1 once manually first to set up
REM   the profile, otherwise it just silently does nothing. need to remember that.

:: ---------------------------------------------------------------
:: scheduler priority stuff
:: this is the "games" multimedia profile windows uses internally, biasing it
:: towards foreground stuff. found this from some old reddit thread, seems to work
:: ---------------------------------------------------------------
echo.
echo [10/10] priority/scheduling tweaks...
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "GPU Priority" /t REG_DWORD /d 8 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Priority" /t REG_DWORD /d 6 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Scheduling Category" /t REG_SZ /d "High" /f >nul
echo     foreground stuff gets priority now

:: ---------------------------------------------------------------
echo.
echo ============================================================
echo   done. reboot needed for hags + a couple other things to stick
echo   restore point = "Pre-rhinopill" if it goes wrong, type rstrui to use it
echo ============================================================
echo.
REM maybe add an undo.bat at some point instead of relying on restore point
REM test on a fresh 24H2 install, some reg paths shift between builds
set /p REBOOT="reboot now? (y/n): "
if /i "%REBOOT%"=="Y" shutdown /r /t 5
pause
endlocal
