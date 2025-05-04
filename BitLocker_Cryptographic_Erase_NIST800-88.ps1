# BitLocker Cryptographic Erase Script for NIST 800-88 rev.1 Compliance
# This script will use BitLocker to perform a cryptographic erase on all internal drives,
# ensuring data is permanently deleted and unrecoverable.

# Requires -RunAsAdministrator

<#
.SYNOPSIS
    BitLocker Cryptographic Erase Script for NIST 800-88 rev.1 Compliance

.DESCRIPTION
    This script performs a cryptographic erase on all internal drives using BitLocker,
    ensuring data is permanently deleted and unrecoverable in accordance with
    NIST Special Publication 800-88 Revision 1 guidelines.

.NOTES
    Version:        1.0
    Author:         Abdullah Kareem
    GitHub:         https://github.com/cyberkareem
    Contact:        abdullahalikareem@gmail.com
    Creation Date:  April 25, 2025
    
    WARNING: THIS WILL MAKE DATA IRRECOVERABLE
    * Requires TPM 1.2+ and BitLocker capability
    * Must perform COLD shutdown after execution
    * For use only on systems being decommissioned or repurposed

.EXAMPLE
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\BitLocker-CryptoErase.ps1

.LINK
    https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-88r1.pdf
#>

#-------------------------------------------------------------------------------------
# CONFIGURATION VARIABLES
#-------------------------------------------------------------------------------------

# Configuration
$backupDir = 'D:\'  # Ensure USB D: is present for backup
$countdownSeconds = 10
# ADDITIONAL USER PROMPT SECTION
Write-Output "====================================================================="
Write-Output "          BitLocker Cryptographic Erase - NIST 800-88 Rev.1          "
Write-Output "          Developed by: Abdullah Kareem                              "
Write-Output "====================================================================="

Write-Output "====================================================================="
Write-Output "          BitLocker Crypto-Erase Script Starting                     "
Write-Output "====================================================================="

Write-Output "====================================================================="
Write-Output "          WARNING: SECURE DATA ERASURE                               "
Write-Output "====================================================================="

Write-Output "THIS PROCESS WILL PERMANENTLY DESTROY ALL DATA ON THIS SYSTEM."
Write-Output "THERE IS NO RECOVERY OPTION AFTER COMPLETION."

$confirmation = Read-Host "Type 'ERASE ALL DATA' (all caps) to confirm and continue"
if ($confirmation -ne "ERASE ALL DATA") {
    Write-Error "Confirmation text doesn't match. Process aborted."
    exit 1
}

# MANUAL BITLOCKER ACTIVATION INSTRUCTIONS
Write-Output "====================================================================="
Write-Output "          Manual BitLocker Activation Instruction                    "
Write-Output "====================================================================="

Write-Output "Before proceeding, please ensure BitLocker is activated manually as follows:"
Write-Output "1. Open the Start menu and type 'BitLocker'."
Write-Output "2. Select 'Manage BitLocker'."
Write-Output "3. For each internal drive listed, click 'Turn on BitLocker'."
Write-Output "4. Follow prompts to set encryption mode (select 'Encrypt entire drive')."
Write-Output "5. Save the recovery key safely."
Write-Output "`nPress Enter once you have manually activated BitLocker on all drives to continue."
Read-Host

# 1. TPM Verification
$tpm = Get-Tpm
if (-not $tpm.TpmPresent -or -not $tpm.TpmEnabled -or -not $tpm.TpmActivated -or -not $tpm.TpmOwned -or -not $tpm.TpmReady) {
    Write-Error "TPM is not enabled, activated, owned, or ready. Aborting. Ensure TPM is set up correctly."
    exit 1
}
Write-Output "TPM is present, enabled, activated, owned, and ready."

# 2. Set backup directory for recovery keys (ensure USB D: is present)
if (-not (Test-Path -Path $backupDir)) {
    Write-Error "Backup drive $backupDir not found. Please insert the USB drive as D: and rerun."
    exit 1
}

# 3. Get all fixed internal volumes (exclude the backup drive and no-letter volumes)
$volumes = Get-BitLockerVolume | Where-Object {
    $_.MountPoint -and ($_.MountPoint -ne 'D:') -and ($_.VolumeType -ne 'Unknown')
}

foreach ($vol in $volumes) {
    $drive = $vol.MountPoint
    Write-Output "`n--- Processing volume ${drive} ---"
    try {
        # 4. Backup existing BitLocker recovery key(s) for the volume
        $keyProtectors = $vol.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
        if ($keyProtectors) {
            foreach ($protector in $keyProtectors) {
                $recKey = $protector.RecoveryPassword
                $outfile = "${backupDir}BitLockerRecovery_${drive.TrimEnd(':')}.txt"
                "$drive Recovery Key: $recKey" | Out-File -FilePath $outfile -Append -Encoding ASCII
            }
            Write-Output "Backed up existing recovery key(s) for ${drive} to USB."
        } else {
            # If no recovery password protector exists (e.g., only TPM protector present), add one for backup
            $newProt = Add-BitLockerKeyProtector -MountPoint $drive -RecoveryPasswordProtector -ErrorAction Stop
            # Retrieve the newly added protector and save it
            $volUpdated = Get-BitLockerVolume -MountPoint $drive
            $newRecProtector = $volUpdated.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
            foreach ($protector in $newRecProtector) {
                if ($protector.RecoveryPassword) {
                    $recKey = $protector.RecoveryPassword
                    $outfile = "${backupDir}BitLockerRecovery_${drive.TrimEnd(':')}.txt"
                    "$drive Recovery Key: $recKey" | Out-File -FilePath $outfile -Append -Encoding ASCII
                    Write-Output "Added and backed up a recovery key for ${drive}."
                }
            }
            # Refresh $vol object to include the new protector
            $vol = $volUpdated
        }

        # 5. Check if BitLocker is already enabled
        if ($vol.ProtectionStatus -eq 'On') {
            Write-Output "${drive} is already encrypted. Skipping BitLocker enablement."
        } else {
            # 6. Enable BitLocker encryption if not already encrypted
            Write-Output "${drive} is not encrypted. Enabling BitLocker (full disk encryption)..."
            try {
                # Check if the drive is the operating system drive
                if ($vol.VolumeType -eq 'OperatingSystem') {
                    Write-Output "Enabling BitLocker on Operating System drive ${drive} with TPM and Recovery Password Protector..."
                    Enable-BitLocker -MountPoint $drive -EncryptionMethod XtsAes256 -UsedSpaceOnly:$false `
                                    -TpmProtector -RecoveryPasswordProtector -SkipHardwareTest -ErrorAction Stop
                } else {
                    Write-Output "Enabling BitLocker on data drive ${drive} with Recovery Password Protector..."
                    Enable-BitLocker -MountPoint $drive -EncryptionMethod XtsAes256 -UsedSpaceOnly:$false `
                                    -RecoveryPasswordProtector -ErrorAction Stop
                }
                Write-Output "BitLocker encryption started on ${drive}."
            } catch {
                Write-Error "Failed to enable BitLocker on ${drive}: $_"
                continue
            }
        }

        # 7. Ensure BitLocker is fully activated
        Write-Output "Ensuring BitLocker is fully activated on ${drive}..."
        try {
            # Resume BitLocker if it is in a suspended state
            Resume-BitLocker -MountPoint $drive -ErrorAction Stop
            Write-Output "BitLocker resumed on ${drive}."

            # Check BitLocker status again
            $status = Get-BitLockerVolume -MountPoint $drive
            if ($status.VolumeStatus -ne 'FullyEncrypted') {
                Write-Output "Waiting for ${drive} encryption to complete..."
                while ((Get-BitLockerVolume -MountPoint $drive).VolumeStatus -eq 'EncryptionInProgress') {
                    Start-Sleep -Seconds 5
                }
                Write-Output "${drive} is now fully encrypted."
            } else {
                Write-Output "${drive} is already fully encrypted."
            }
        } catch {
            Write-Error "Failed to ensure BitLocker is fully activated on ${drive}: $_"
            continue
        }

        # If volume was encrypted used-space-only originally, wipe free space to encrypt it as well
        $manageStatus = (manage-bde -status $drive) 2>&1
        if ($manageStatus -match "Used Space Only Encrypted") {
            Write-Output "Volume ${drive} was encrypted using 'used space only'. Wiping free space..."
            manage-bde -wipefreespace $drive
            Write-Output "Free space on ${drive} has been encrypted (wipefreespace complete)."
        }

        # 8. Cryptographic erase: remove all original protectors and leave an unknown one
        Write-Output "Removing known protectors and adding a new unknown recovery key for ${drive}..."
        # Record existing protector IDs to identify the new one later
        $origProtectors = (Get-BitLockerVolume -MountPoint $drive).KeyProtector
        $origIDs = $origProtectors | ForEach-Object { $_.KeyProtectorId }
        # Add a new recovery password protector (do NOT back this one up)
        Add-BitLockerKeyProtector -MountPoint $drive -RecoveryPasswordProtector -ErrorAction Stop | Out-Null
        # Find the newly added protector’s ID (not in original list)
        $allProtectors = (Get-BitLockerVolume -MountPoint $drive).KeyProtector
        $newProtector = $allProtectors | Where-Object { $_.KeyProtectorId -notin $origIDs -and $_.KeyProtectorType -eq 'RecoveryPassword' }
        if (-not $newProtector) {
            throw "Failed to add new recovery protector on ${drive}."
        }
        $newID = $newProtector.KeyProtectorId
        # Remove all old protectors (every protector except the new one)
        foreach ($prot in $allProtectors) {
            if ($prot.KeyProtectorId -ne $newID) {
                Remove-BitLockerKeyProtector -MountPoint $drive -KeyProtectorId $prot.KeyProtectorId -Confirm:$false
            }
        }
        Write-Output "All original protectors removed from ${drive}. Data is now secured by an *unknown* key."
    }
    catch {
        Write-Error "ERROR processing ${drive}: $_"
        # Continue to next volume (or use 'break' if you prefer to stop entirely on first error)
        continue
    }
}

# Disable Fast Startup
Write-Output "====================================================================="
Write-Output "          Wrapping things up                                         "
Write-Output "====================================================================="
Write-Output "Disabling Fast Startup..."
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0 -Force

# Force TPM clearance (requires physical presence)
Write-Output "Clearing TPM authorization..."
try {
    Clear-Tpm -AllowClear -AllowPhysicalPresence -ErrorAction Stop
    Write-Output "TPM cleared successfully."
}
catch {
    Write-Output "TPM clearance (REQUIRES BIOS RESET)"
}

Write-Output "`nAll internal drives processed. The system will reboot now to complete the purge."

# Countdown before rebooting
Write-Host "System will reboot in $countdownSeconds seconds..." -ForegroundColor Yellow
for ($i = $countdownSeconds; $i -gt 0; $i--) {
     Write-Host "`rRebooting in $i seconds..." -NoNewline
    Start-Sleep -Seconds 1
    }

Restart-Computer -Force
