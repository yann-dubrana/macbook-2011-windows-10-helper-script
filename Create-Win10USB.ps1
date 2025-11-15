#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Creates a FAT32 bootable USB for Windows 10 installation on 2011 MacBook Air (MBR mode)
.DESCRIPTION
    Downloads Windows 10 ISO, formats USB as FAT32, and prepares for manual MBR installation
.NOTES
    - Requires Administrator privileges
    - USB drive will be completely erased
    - Install.wim over 4GB will be split automatically
#>

# Configuration
$ISOPath = "$env:USERPROFILE\Downloads\Windows10.iso"
$TempExtractPath = "$env:TEMP\Win10Extract"
$SplitTempPath = "$env:TEMP\WimSplit"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Windows 10 MBR USB Creator for Mac 2011" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check for ISO file
Write-Host "[1/7] Checking for Windows 10 ISO..." -ForegroundColor Yellow
if (-not (Test-Path $ISOPath)) {
    Write-Host ""
    Write-Host "ERROR: Windows 10 ISO not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please download Windows 10 ISO manually:" -ForegroundColor Yellow
    Write-Host "1. Visit: https://www.microsoft.com/software-download/windows10" -ForegroundColor Cyan
    Write-Host "2. Click 'Download tool now' or 'Download ISO'" -ForegroundColor Cyan
    Write-Host "3. Save the ISO to: $ISOPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Or use the Media Creation Tool to create the ISO." -ForegroundColor Gray
    Write-Host ""
    
    $openBrowser = Read-Host "Open download page in browser? (y/n)"
    if ($openBrowser -eq 'y') {
        Start-Process "https://www.microsoft.com/software-download/windows10"
    }
    exit 1
}

Write-Host "Found ISO: $ISOPath" -ForegroundColor Green

# Check for wimlib
Write-Host ""
Write-Host "[2/7] Checking for wimlib-imagex..." -ForegroundColor Yellow
$wimlibPath = "C:\Program Files\wimlib\wimlib-imagex.exe"
if (-not (Test-Path $wimlibPath)) {
    Write-Host "ERROR: wimlib not found!" -ForegroundColor Red
    Write-Host "Download from: https://wimlib.net/downloads/" -ForegroundColor Red
    Write-Host "Install to: C:\Program Files\wimlib\" -ForegroundColor Red
    exit 1
}
Write-Host "Found wimlib: $wimlibPath" -ForegroundColor Green

# List available USB drives
Write-Host ""
Write-Host "[3/7] Detecting USB drives..." -ForegroundColor Yellow
$usbDrives = Get-Disk | Where-Object { $_.BusType -eq 'USB' }

if ($usbDrives.Count -eq 0) {
    Write-Host "ERROR: No USB drives detected!" -ForegroundColor Red
    exit 1
}

Write-Host "Available USB drives:" -ForegroundColor Green
$usbDrives | Format-Table Number, FriendlyName, @{Label="Size(GB)";Expression={[math]::Round($_.Size/1GB,2)}}

$diskNumber = Read-Host "Enter disk number to use (WARNING: ALL DATA WILL BE ERASED)"
$selectedDisk = Get-Disk -Number $diskNumber

if ($selectedDisk.BusType -ne 'USB') {
    Write-Host "ERROR: Selected disk is not a USB drive!" -ForegroundColor Red
    exit 1
}

# Confirm
Write-Host ""
Write-Host "WARNING: Disk $diskNumber ($($selectedDisk.FriendlyName)) will be COMPLETELY ERASED!" -ForegroundColor Red
$confirm = Read-Host "Type 'YES' to continue"
if ($confirm -ne 'YES') {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit 0
}

# Download Windows 10 ISO
Write-Host ""
Write-Host "[4/7] Mounting Windows 10 ISO..." -ForegroundColor Yellow

# Set disk offline first
Write-Host "Taking disk offline..." -ForegroundColor Cyan
Set-Disk -Number $diskNumber -IsOffline $true

# Bring back online
Write-Host "Bringing disk online..." -ForegroundColor Cyan
Set-Disk -Number $diskNumber -IsOffline $false

# Clean disk completely using diskpart for guaranteed MBR conversion
Write-Host "Converting to MBR using diskpart..." -ForegroundColor Cyan
$diskpartScript = @"
select disk $diskNumber
clean
convert mbr
create partition primary
format fs=fat32 quick label="WIN10USB"
assign
active
exit
"@

$diskpartScript | diskpart | Out-Host

# Wait for format to complete
Write-Host "Waiting for disk operations to complete..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

# Get the drive letter
$partition = Get-Partition -DiskNumber $diskNumber | Where-Object { $_.Type -ne 'Reserved' }
$driveLetter = $partition.DriveLetter

if ([string]::IsNullOrEmpty($driveLetter)) {
    Write-Host "ERROR: No drive letter assigned!" -ForegroundColor Red
    Write-Host "Please manually check Disk Management" -ForegroundColor Yellow
    exit 1
}

Write-Host "USB formatted as ${driveLetter}: (FAT32)" -ForegroundColor Green

# Mount ISO
Write-Host ""
Write-Host "[5/7] Mounting ISO..." -ForegroundColor Yellow
$mountResult = Mount-DiskImage -ImagePath $ISOPath -PassThru
$isoVolume = Get-Volume | Where-Object { $_.DriveLetter -eq ($mountResult | Get-Volume).DriveLetter }
$isoDrive = "$($isoVolume.DriveLetter):"

Write-Host "ISO mounted at $isoDrive" -ForegroundColor Green

# Copy files
Write-Host ""
Write-Host "[6/7] Copying Windows files to USB..." -ForegroundColor Yellow

# Wait for drive letter to be assigned
Start-Sleep -Seconds 2

# Verify drive letter exists
if ([string]::IsNullOrEmpty($driveLetter)) {
    Write-Host "ERROR: No drive letter assigned to USB!" -ForegroundColor Red
    Write-Host "Attempting to assign drive letter manually..." -ForegroundColor Yellow
    $partition = Get-Partition -DiskNumber $diskNumber | Where-Object { $_.Type -eq 'Basic' }
    $driveLetter = (Add-PartitionAccessPath -InputObject $partition -AssignDriveLetter -PassThru | Get-Partition).DriveLetter
    if ([string]::IsNullOrEmpty($driveLetter)) {
        Write-Host "ERROR: Failed to assign drive letter!" -ForegroundColor Red
        Dismount-DiskImage -ImagePath $ISOPath
        exit 1
    }
}

Write-Host "USB drive letter: ${driveLetter}:" -ForegroundColor Green

# Check install.wim size
$installWim = "$isoDrive\sources\install.wim"
$installEsd = "$isoDrive\sources\install.esd"

if (Test-Path $installWim) {
    $wimSize = (Get-Item $installWim).Length / 1GB
    Write-Host "Found install.wim ($([math]::Round($wimSize,2)) GB)" -ForegroundColor Cyan
    
    # Copy everything except install.wim first
    Write-Host "Copying files (excluding install.wim)..." -ForegroundColor Cyan
    Get-ChildItem -Path $isoDrive -Recurse | Where-Object { $_.FullName -notlike "*\sources\install.wim" } | ForEach-Object {
        $dest = $_.FullName.Replace($isoDrive, "${driveLetter}:")
        if ($_.PSIsContainer) {
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
        } else {
            Copy-Item $_.FullName -Destination $dest -Force
        }
    }
    
    # Handle install.wim
    if ($wimSize -gt 4) {
        Write-Host "install.wim is larger than 4GB, splitting..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $SplitTempPath -Force | Out-Null
        
        & $wimlibPath split $installWim "$SplitTempPath\install.swm" 3000
        
        Write-Host "Copying split files to USB..." -ForegroundColor Cyan
        Copy-Item "$SplitTempPath\*" -Destination "${driveLetter}:\sources\" -Force
        
        Remove-Item $SplitTempPath -Recurse -Force
    } else {
        Write-Host "Copying install.wim..." -ForegroundColor Cyan
        Copy-Item $installWim -Destination "${driveLetter}:\sources\" -Force
    }
} elseif (Test-Path $installEsd) {
    Write-Host "Found install.esd (copying all files)..." -ForegroundColor Cyan
    
    # Ensure destination exists
    if (-not (Test-Path "${driveLetter}:\")) {
        Write-Host "ERROR: USB drive ${driveLetter}: not accessible!" -ForegroundColor Red
        Dismount-DiskImage -ImagePath $ISOPath
        exit 1
    }
    
    # Copy files with progress
    $files = Get-ChildItem -Path "${isoDrive}\" -Recurse -File
    $fileCount = $files.Count
    $current = 0
    
    foreach ($file in $files) {
        $current++
        $relativePath = $file.FullName.Replace("${isoDrive}\", "")
        $destPath = "${driveLetter}:\${relativePath}"
        $destDir = Split-Path -Parent $destPath
        
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        
        Copy-Item -Path $file.FullName -Destination $destPath -Force
        
        if ($current % 100 -eq 0) {
            Write-Progress -Activity "Copying files" -Status "$current of $fileCount" -PercentComplete (($current / $fileCount) * 100)
        }
    }
    Write-Progress -Activity "Copying files" -Completed
} else {
    Write-Host "ERROR: No install.wim or install.esd found!" -ForegroundColor Red
    Dismount-DiskImage -ImagePath $ISOPath
    exit 1
}

Write-Host "Files copied successfully!" -ForegroundColor Green

# Dismount ISO
Dismount-DiskImage -ImagePath $ISOPath | Out-Null

# Done
Write-Host ""
Write-Host "[7/7] USB Creation Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "NEXT STEPS ON YOUR MACBOOK AIR:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Insert USB into Mac and hold Option key during boot" -ForegroundColor White
Write-Host "2. Select 'EFI Boot' or 'Windows' option" -ForegroundColor White
Write-Host "3. When Windows Setup appears:" -ForegroundColor White
Write-Host "   - Press Shift+F10 (opens Command Prompt)" -ForegroundColor Yellow
Write-Host "   - DO NOT click 'Install now' - it won't work!" -ForegroundColor Red
Write-Host ""
Write-Host "4. Follow the manual MBR installation process" -ForegroundColor White
Write-Host "   (See instructions in the Mac installation guide)" -ForegroundColor Gray
Write-Host ""
Write-Host "USB Drive: ${driveLetter}: is ready!" -ForegroundColor Green
Write-Host ""
