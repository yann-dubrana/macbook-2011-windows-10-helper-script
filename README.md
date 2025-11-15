# Windows 10 MBR Installation for MacBook Air 2011

**Install Windows 10 on 2011 MacBook Air (and other older Macs) without macOS using MBR/BIOS mode**

This repository provides automated scripts to create a bootable USB and install Windows 10 in MBR (legacy BIOS) mode on older Mac hardware that has issues with UEFI boot. This method is particularly useful when:

- Your Mac's internal drive has been replaced
- You don't want to install macOS first
- UEFI boot causes hangs during Windows installation
- You need proper audio support (Cirrus Logic driver requires MBR mode)

## 🎯 Tested Hardware

- **Primary Target:** MacBook Air 4,2 (Mid 2011)
- **Should work on:** iMac Mid 2011, MacBook Air 2010-2012, other pre-2013 Macs

## 📋 Requirements

### On Windows PC (for USB preparation):
- Windows 10/11 with PowerShell
- USB flash drive (8GB minimum)
- [wimlib](https://wimlib.net/downloads/) installed to `C:\Program Files\wimlib\`
- Administrator privileges

### On Target Mac:
- MacBook Air 2011 (or compatible model)
- Working internal drive (or replaced drive)

## 🚀 Quick Start

### Step 1: Download Windows 10 ISO

**Manual Download (Recommended):**
1. Visit [Microsoft's Windows 10 Download Page](https://www.microsoft.com/software-download/windows10)
2. Download the ISO file or use Media Creation Tool
3. Save as `Windows10.iso` to your `Downloads` folder

**Alternative:** Download directly from [Microsoft's official site](https://www.microsoft.com/en-us/software-download/windows10ISO)

### Step 2: Prepare Bootable USB (Windows PC)

1. Install [wimlib](https://wimlib.net/downloads/) to `C:\Program Files\wimlib\`

2. Download both scripts:
   - `Create-Win10USB.ps1` - Creates bootable USB
   - `AutoInstall.bat` - Automates installation on Mac

3. Run PowerShell as **Administrator**

4. Execute the USB preparation script:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process
   .\Create-Win10USB.ps1
   ```

5. Follow the prompts:
   - Select your USB drive number (⚠️ all data will be erased!)
   - Wait for formatting and file copying (10-30 minutes)

6. Copy `AutoInstall.bat` to the **root of your USB drive**

### Step 3: Install Windows on Mac

1. **Insert USB** into MacBook Air

2. **Boot from USB:**
   - Turn on Mac and immediately hold **Option (⌥)** key
   - Select **"Windows"** or **"EFI Boot"** from boot menu
   - Wait for Windows Setup to load

3. **Run Automated Installation:**
   - When Windows Setup appears, press **Shift + F10** (opens Command Prompt)
   - ⚠️ **DO NOT click "Install now"** - it will fail!
   - Find your USB drive letter:
     ```cmd
     dir D:\
     dir E:\
     ```
   - Run the installation script:
     ```cmd
     D:\AutoInstall.bat
     ```
     (Replace `D:` with your actual USB drive letter)

4. **Follow the script prompts:**
   - Confirm disk erasure
   - Wait for partitioning (1-2 minutes)
   - Wait for Windows installation (10-20 minutes)
   - Script will show post-installation instructions

5. **Reboot:**
   ```cmd
   wpeutil reboot
   ```
   Remove USB drive during reboot

6. **Complete Windows Setup (OOBE):**
   - Select language, region, keyboard
   - Connect to WiFi (if available)
   - Create user account
   - ⚠️ **Screen will go black briefly** - this is normal (GPU driver installation)

### Step 4: Install Boot Camp Drivers

**Boot Camp drivers are ESSENTIAL for:**
- Trackpad right-click
- Audio (Cirrus Logic)
- Brightness controls
- Keyboard special keys

**Option A: Boot Camp 5 (Easiest)**
1. Download [Boot Camp 5 from Apple](https://support.apple.com/kb/DL1720?locale=en_US) (~800MB)
2. Extract the downloaded file
3. Run `BootCamp\setup.exe`
4. Reboot after installation

**Option B: Latest Compatible Package**
1. Download the correct package for MacBookAir4,2:
   - [Primary Package](http://swcdn.apple.com/content/downloads/26/08/041-84821-A_AMCFPC3QDK/4fffs8qgdflw7pn1finqqd40gifh41mvs6/BootCampESD.pkg)
   - [Alternative Package](http://swcdn.apple.com/content/downloads/29/62/041-84859-A_GGUOSJMIGN/sb1apxcjpp358ze2df6bzhwd49m2cqyzy5/BootCampESD.pkg)

2. Extract with [7-Zip](https://www.7-zip.org/):
   - Right-click → 7-Zip → Extract
   - Extract `Payload~` again
   - Extract `WindowsSupport.dmg` again

3. Look for the package containing only:
   - `$WinPEDriver$`
   - `BootCamp`
   - `AutoUnattend.xml`

4. Copy all files to Desktop (maintaining directory structure)

5. Run `BootCamp\setup.exe`

6. Reboot after installation

### Step 5: Configuration

**Enable Trackpad Right-Click:**
1. Open **Control Panel**
2. Search for **"Boot Camp"**
3. Go to **Trackpad** tab
4. Enable **"Secondary Click"**
5. Adjust tracking speed and other preferences

**Fix Brightness Controls:**
1. Open **Settings** → **Display**
2. Disable **"Change brightness automatically when lighting changes"**

**Adjust Scroll Speed:**
- **Settings** → **Mouse** → "Choose how many lines to scroll each time"

**Reverse Scroll Direction (Natural Scrolling):**
1. Open **Registry Editor** (`regedit`)
2. Navigate to: `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\HID`
3. Search for `FlipFlopWheel` entries
4. Change value from `0` to `1`
5. Reboot

**Remap Keys (Optional):**
- Use [SharpKeys](https://github.com/randyrants/sharpkeys) to remap keys (e.g., ISO key to Left Shift)

## 🛠️ Technical Details

### Why MBR and Not UEFI?

On MacBook Air 2011 and similar models:
- **UEFI boot causes Windows to hang** at the bootloader stage (cyan Windows logo with no progress bar)
- **Cirrus Logic audio drivers are not UEFI-compatible** - sound won't work in UEFI mode
- MBR/BIOS mode is the only way to get full hardware support

### How It Works

1. **USB Preparation:**
   - Formats USB as FAT32 (Mac can boot from this)
   - Splits `install.wim` if > 4GB (FAT32 limitation)
   - Mac boots USB in UEFI mode (can't be avoided)

2. **Manual Installation:**
   - Boot USB in UEFI mode
   - Don't click "Install now" (would try UEFI installation)
   - Use Command Prompt to manually:
     - Create MBR partition table
     - Create System/Windows/Recovery partitions
     - Apply Windows image with DISM
     - Install bootloader in BIOS mode (`/f BIOS`)

3. **Boot Process:**
   - Mac firmware boots in UEFI mode initially
   - Hands off to MBR bootloader on internal drive
   - Windows boots in legacy BIOS mode
   - All drivers work correctly

## 📁 Script Descriptions

### `Create-Win10USB.ps1`
PowerShell script that runs on Windows PC to:
- Check for Windows 10 ISO
- Detect and format USB drive as FAT32 with MBR
- Mount ISO and copy all files
- Automatically split `install.wim` if larger than 4GB
- Add `AutoInstall.bat` to USB root

**Parameters:** None (interactive prompts)

### `AutoInstall.bat`
Batch script that runs in Windows PE (on the Mac) to:
- Convert disk to MBR partition scheme
- Create System (100MB), Windows (main), and Recovery (650MB) partitions
- Detect install.wim/install.swm/install.esd automatically
- Apply Windows image using DISM
- Configure bootloader for BIOS mode
- Setup recovery partition
- Display post-installation instructions

**Usage:** Run from USB drive after booting: `D:\AutoInstall.bat`

## 🐛 Troubleshooting

### USB Won't Boot
**Symptom:** Mac doesn't show USB in Option boot menu

**Solutions:**
- Ensure USB is formatted as FAT32 (not NTFS)
- Try different USB port
- Verify USB has been properly ejected/synced before removing from PC

### Windows Hangs at Cyan Logo
**Symptom:** Cyan Windows logo appears but no progress bar, pressing F8 does nothing

**Cause:** Windows was installed in UEFI mode instead of MBR mode

**Solution:** Start over, ensure you:
- Don't click "Install now"
- Use the manual partitioning method (diskpart with `convert mbr`)
- Use `bcdboot` with `/f BIOS` flag

### Right-Click Doesn't Work
**Symptom:** Can't right-click with trackpad

**Cause:** Boot Camp drivers not installed

**Solution:** Install Boot Camp (see Step 4 above)

### No Sound
**Symptom:** Audio device not detected or no sound output

**Causes:**
1. Boot Camp drivers not installed
2. Windows installed in UEFI mode (Cirrus driver requires MBR)

**Solution:** 
- Install Boot Camp drivers
- If still no sound, verify MBR installation: Open Disk Management, right-click disk → Properties → Volumes → should show "Master Boot Record (MBR)"

### Screen Goes Black During Setup
**Symptom:** Screen turns black during OOBE or after driver installation

**Cause:** Normal - GPU driver being installed/reinitialized

**Solution:** Wait 30-60 seconds, screen will return

### Brightness Controls Don't Work
**Symptom:** Brightness keys don't adjust screen

**Solution:** 
1. Ensure Boot Camp installed
2. Disable auto-brightness: Settings → Display → uncheck "Change brightness automatically"
3. Reboot

### Disk Already GPT/Initialized Error
**Symptom:** PowerShell script fails with "disk already initialized" or GPT errors

**Solution:**
1. Open Disk Management (`diskmgmt.msc`)
2. Delete all volumes on USB drive
3. Right-click disk → "Convert to MBR Disk"
4. Run script again

## 📖 References

This project is based on the excellent work and documentation from:

- [Installing Windows 10 on 2011 MacBook Air without macOS](https://gist.github.com/purplesyringa/0083a8b553df3a22b55136289dcd2f7e) by purplesyringa
- [Installing Windows 10 on iMac mid 2011 Without macOS](https://www.reddit.com/r/bootcamp/comments/150boe8/installing_windows_10_on_imac_mid_2011_without/) by u/Specialist_Loan_9702

## ⚠️ Warnings

- **All data on the Mac's internal drive will be erased** - backup important files before proceeding
- **USB drive will be completely formatted** - backup USB data before running script
- This method is for **older Macs only** - newer Macs (2013+) should use standard UEFI installation
- **No dual-boot** - this installs Windows only, removing macOS completely
- **No official support** - this is a community solution, not supported by Apple or Microsoft

## 🤝 Contributing

Found a bug? Have an improvement? Contributions are welcome!

1. Fork the repository
2. Create your feature branch
3. Test thoroughly on real hardware
4. Submit a pull request

## 📜 License

MIT License - feel free to modify and distribute

## 🙏 Credits

- Original guides by purplesyringa and u/Specialist_Loan_9702
- Boot Camp drivers by Apple
- wimlib by Eric Biggers
- Community testing and feedback

## ⭐ Support

If this helped you breathe new life into your old MacBook, please star this repository!

---

**Last Updated:** March 2025  
**Tested On:** MacBook Air 4,2 (Mid 2011), Windows 10 22H2
