@echo off
REM ============================================================================
REM Automated Windows 10 MBR Installation Script for MacBook Air 2011
REM ============================================================================
REM Place this script on your Windows 10 installation USB drive (root directory)
REM Boot from USB, press Shift+F10, then run: D:\AutoInstall.bat (adjust drive letter)
REM ============================================================================

echo.
echo ========================================
echo  Automated Windows 10 MBR Installation
echo  for MacBook Air 2011
echo ========================================
echo.
echo WARNING: This will ERASE your internal drive!
echo.
echo Press Ctrl+C to cancel, or
pause

REM ============================================================================
REM Step 1: Partition the Disk
REM ============================================================================
echo.
echo [1/5] Creating MBR partitions...
echo.

(
echo select disk 0
echo clean
echo convert mbr
echo create partition primary size=100
echo format quick fs=ntfs label=System
echo assign letter=S
echo active
echo create partition primary
echo shrink minimum=650
echo format quick fs=ntfs label=Windows
echo assign letter=W
echo create partition primary
echo format quick fs=ntfs label=Recovery
echo assign letter=R
echo set id=27
echo list volume
echo exit
) | diskpart

if errorlevel 1 (
    echo ERROR: Disk partitioning failed!
    echo Check if you selected the correct disk.
    pause
    exit /b 1
)

echo.
echo Partitions created successfully!
echo.
pause

REM ============================================================================
REM Step 2: Find USB Drive with Install Image
REM ============================================================================
echo.
echo [2/5] Locating installation files...
echo.

set FOUND=0
set INSTALL_FILE=

REM Check for install.wim
for %%d in (C D E F G H I J K L M N O P Q) do (
    if exist %%d:\sources\install.wim (
        set USB_DRIVE=%%d:
        set INSTALL_FILE=%%d:\sources\install.wim
        set INSTALL_TYPE=WIM
        set FOUND=1
        goto :found
    )
)

REM Check for install.swm (split)
for %%d in (C D E F G H I J K L M N O P Q) do (
    if exist %%d:\sources\install.swm (
        set USB_DRIVE=%%d:
        set INSTALL_FILE=%%d:\sources\install.swm
        set INSTALL_TYPE=SWM
        set FOUND=1
        goto :found
    )
)

REM Check for install.esd
for %%d in (C D E F G H I J K L M N O P Q) do (
    if exist %%d:\sources\install.esd (
        set USB_DRIVE=%%d:
        set INSTALL_FILE=%%d:\sources\install.esd
        set INSTALL_TYPE=ESD
        set FOUND=1
        goto :found
    )
)

:found
if %FOUND%==0 (
    echo ERROR: Could not find install.wim, install.swm, or install.esd!
    echo Make sure you're running this from the Windows installation USB.
    pause
    exit /b 1
)

echo Found: %INSTALL_FILE%
echo Type: %INSTALL_TYPE%
echo.

REM ============================================================================
REM Step 3: Apply Windows Image
REM ============================================================================
echo.
echo [3/5] Installing Windows...
echo This will take 10-20 minutes. Please wait...
echo.

if "%INSTALL_TYPE%"=="WIM" (
    dism /Apply-Image /ImageFile:"%INSTALL_FILE%" /Index:1 /ApplyDir:W:\
)

if "%INSTALL_TYPE%"=="SWM" (
    dism /Apply-Image /ImageFile:"%INSTALL_FILE%" /SWMFile:%USB_DRIVE%\sources\install*.swm /Index:1 /ApplyDir:W:\
)

if "%INSTALL_TYPE%"=="ESD" (
    dism /Apply-Image /ImageFile:"%INSTALL_FILE%" /Index:1 /ApplyDir:W:\
)

if errorlevel 1 (
    echo ERROR: Failed to apply Windows image!
    pause
    exit /b 1
)

echo.
echo Windows image applied successfully!
echo.
pause

REM ============================================================================
REM Step 4: Configure Bootloader (MBR/BIOS Mode)
REM ============================================================================
echo.
echo [4/5] Configuring bootloader for MBR/BIOS mode...
echo.

bcdboot W:\Windows /s S: /f BIOS
if errorlevel 1 (
    echo ERROR: Failed to configure BCD!
    pause
    exit /b 1
)

bootsect /nt60 S: /mbr
if errorlevel 1 (
    echo ERROR: Failed to write boot sector!
    pause
    exit /b 1
)

echo.
echo Bootloader configured successfully!
echo.

REM ============================================================================
REM Step 5: Setup Recovery Partition
REM ============================================================================
echo.
echo [5/5] Setting up recovery partition...
echo.

md R:\Recovery\WindowsRE
copy W:\Windows\System32\Recovery\winre.wim R:\Recovery\WindowsRE\winre.wim

if errorlevel 1 (
    echo WARNING: Failed to copy winre.wim
    echo Recovery partition setup incomplete, but Windows should still boot.
) else (
    W:\Windows\System32\reagentc /setreimage /path R:\Recovery\WindowsRE /target W:\Windows
    echo Recovery partition configured!
)

echo.
echo ============================================
echo  Installation Complete!
echo ============================================
echo.
echo Next steps:
echo 1. Remove USB drive
echo 2. Type: wpeutil reboot
echo 3. Windows will boot and complete setup
echo 4. Install Boot Camp drivers after first boot
echo.
echo Boot Camp download link will be shown after reboot.
echo.
echo Press any key to see instructions, then reboot manually...
pause

cls
echo.
echo ============================================
echo  POST-INSTALLATION INSTRUCTIONS
echo ============================================
echo.
echo After Windows boots and completes OOBE setup:
echo.
echo 1. Download Boot Camp 5:
echo    https://support.apple.com/kb/DL1720?locale=en_US
echo.
echo    OR get the latest package:
echo    http://swcdn.apple.com/content/downloads/26/08/041-84821-A_AMCFPC3QDK/4fffs8qgdflw7pn1finqqd40gifh41mvs6/BootCampESD.pkg
echo.
echo 2. Extract with 7-Zip (if .pkg file)
echo.
echo 3. Run BootCamp\setup.exe
echo.
echo 4. Reboot after driver installation
echo.
echo 5. Enable trackpad right-click:
echo    Control Panel -^> Boot Camp -^> Trackpad -^> Secondary Click
echo.
echo 6. Fix brightness:
echo    Settings -^> Display -^> Disable auto brightness
echo.
echo ============================================
echo.
echo Ready to reboot? Type: wpeutil reboot
echo.
cmd
