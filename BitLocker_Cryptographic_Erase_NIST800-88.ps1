# BitLocker Cryptographic Erase Script for NIST 800-88 rev.1 Compliance
# This script will use BitLocker to perform a cryptographic erase on all internal drives,
# ensuring data is permanently deleted and unrecoverable.

# Requires -RunAsAdministrator
<#
.SYNOPSIS
Performs a cryptographic erase using BitLocker, compliant with NIST 800-88 rev.1.

.NOTES
- THIS WILL MAKE DATA IRRECOVERABLE
- Requires TPM 1.2+ and BitLocker-enabled drives.
- Must perform COLD shutdown after execution.
#>

# Configuration
$backupDir = 'D:\'  # Ensure USB D: is present for backup
$countdownSeconds = 60

Write-Output "=== BitLocker Crypto-Erase Script Starting ==="

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

        # 5. Enable BitLocker encryption if not already encrypted
        if ($vol.ProtectionStatus -eq 'Off') {
            Write-Output "${drive} is not encrypted. Enabling BitLocker (full disk encryption)..."
            try {
                # Simplified Enable-BitLocker command
                Enable-BitLocker -MountPoint $drive -EncryptionMethod XtsAes256 -UsedSpaceOnly:$false -RecoveryPasswordProtector -ErrorAction Stop
                Write-Output "BitLocker encryption started on ${drive}."
            } catch {
                Write-Error "Failed to enable BitLocker on ${drive}: $_"
                continue
            }
        }

        # 6. Wait for encryption to finish (if in progress)
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

        # If volume was encrypted used-space-only originally, wipe free space to encrypt it as well
        $manageStatus = (manage-bde -status $drive) 2>&1
        if ($manageStatus -match "Used Space Only Encrypted") {
            Write-Output "Volume ${drive} was encrypted using 'used space only'. Wiping free space..."
            manage-bde -wipefreespace $drive
            Write-Output "Free space on ${drive} has been encrypted (wipefreespace complete)."
        }

        # 7. Cryptographic erase: remove all original protectors and leave an unknown one
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
Write-Output "Disabling Fast Startup..."
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0 -Force

# Force TPM clearance (requires physical presence)
Write-Output "Clearing TPM authorization..."
try {
    Clear-Tpm -AllowClear -AllowPhysicalPresence -ErrorAction Stop
    Write-Output "TPM cleared successfully."
}
catch {
    Write-Output "TPM clearance failed (REQUIRES BIOS RESET)"
}

Write-Output "`nAll internal drives processed. The system will reboot now to complete the purge."

# Countdown before rebooting
$seconds = $countdownSeconds
while ($seconds -gt 0) {
    Write-Output "Restarting in $seconds seconds..."
    Start-Sleep -Seconds 1
    $seconds--
}

Restart-Computer -Force
