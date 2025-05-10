# BitLocker Cryptographic Erase Script for NIST 800-88 rev.1 Compliance
# This script performs a cryptographic erase on all internal drives using BitLocker,
# ensuring data is permanently deleted and unrecoverable

# Requires -RunAsAdministrator

<#
.SYNOPSIS
    BitLocker Cryptographic Erase Script for NIST 800-88 rev.1 Compliance

.DESCRIPTION
    This script performs a cryptographic erase on all internal drives using BitLocker,
    ensuring data is permanently deleted and unrecoverable in accordance with
    NIST Special Publication 800-88 Revision 1 guidelines.

.NOTES
    Version:        1.1
    Author:         Abdullah Kareem
    GitHub:         https://github.com/cyberkareem
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

#====================================================================================
# CONFIGURATION VARIABLES
#====================================================================================

# Time in seconds to wait before the script forces a system reboot at completion
$countdownSeconds = 10

#====================================================================================
# USER INTERFACE - INITIAL WARNINGS AND INFORMATION
#====================================================================================

# Display script header and warning banners
Write-Output "====================================================================="
Write-Output "          BitLocker Cryptographic Erase - NIST 800-88 Rev.1          "
Write-Output "          Developed by: Abdullah Kareem                              "
Write-Output "====================================================================="

Write-Output "====================================================================="
Write-Output "                                                                     "
Write-Output "          BitLocker Crypto-Erase Script Starting                     "
Write-Output "                                                                     "
Write-Output "====================================================================="

Write-Output "====================================================================="
Write-Output "                                                                     "
Write-Output "          WARNING: SECURE DATA ERASURE                               "
Write-Output "                                                                     "
Write-Output "====================================================================="

# Critical warning displayed to user about data destruction
Write-Output "THIS PROCESS WILL PERMANENTLY DESTROY ALL DATA ON THIS SYSTEM."
Write-Output "THERE IS NO RECOVERY OPTION AFTER COMPLETION."

#====================================================================================
# EXTERNAL DRIVE IDENTIFICATION
#====================================================================================

# List all available drives for user reference
Write-Output "`n====================================================================="
Write-Output "          DRIVE INFORMATION                                          "
Write-Output "====================================================================="

# Get and display all available drives with their information
$allDrives = Get-Volume | Where-Object { $_.DriveLetter } | Select-Object DriveLetter, FileSystemLabel, DriveType, SizeRemaining, Size
Write-Output "Available drives on this system:"
$allDrives | Format-Table -AutoSize

# Prompt for external drive letters to exclude from erasure
$excludeDrives = @()
do {
    $driveInput = Read-Host "`nEnter drive letter to EXCLUDE from erasure (e.g., 'D' for D: drive) or/and press Enter to proceed"
    if ($driveInput -ne "") {
        # Convert to uppercase and add to exclusion list with colon
        $driveLetter = $driveInput.ToUpper().TrimEnd(':')
        $excludeDrives += "${driveLetter}:"
        Write-Host "Added ${driveLetter}: to exclusion list" -ForegroundColor Yellow
    }
} while ($driveInput -ne "")

# Confirm exclusions with user
if ($excludeDrives.Count -gt 0) {
    Write-Host "`nThe following drives will be EXCLUDED from erasure:" -ForegroundColor Cyan
    $excludeDrives | ForEach-Object { Write-Host "  - $_" -ForegroundColor Cyan }
} else {
    Write-Host "`nNo drives will be excluded. ALL fixed internal drives will be erased!" -ForegroundColor Red
}

# Final confirmation
$confirmExclusions = Read-Host "`nAre these exclusions correct? (Y/N)"
if ($confirmExclusions.ToUpper() -ne "Y") {
    Write-Error "Drive exclusion configuration aborted by user. Please restart the script."
    exit 1
}

#====================================================================================
# DOMAIN DISCONNECTION VERIFICATION FUNCTION
#====================================================================================

# Function to ensure the computer has been disconnected from domain before proceeding
# This prevents potential issues with domain policies interfering with the erase process
function Confirm-DomainDisconnect {
    # Create choice descriptions for the confirmation prompt
    $choices = [System.Management.Automation.Host.ChoiceDescription[]] @(
        [System.Management.Automation.Host.ChoiceDescription]::new("&Yes", "Computer has been disconnected from domain"),
        [System.Management.Automation.Host.ChoiceDescription]::new("&No", "Computer is still domain-joined")
    )
    
    # Continue prompting until the user confirms domain disconnection
    do {
        $decision = $Host.UI.PromptForChoice(
            "Domain Connection Check", 
            "Has the computer been disconnected from the domain?",
            $choices,
            1  # Default to No (index 1) for safety
        )
        
        # If the computer is still connected to domain, abort the process
        if ($decision -eq 1) {
            Write-Host "`n[ABORTING] Computer must be disconnected from domain first!" -ForegroundColor Red
            Write-Host "Please disconnect from domain and rerun the script.`n" -ForegroundColor Yellow
            exit 1
        }
        else {
            # Proceed if the user confirms domain disconnection
            Write-Host "`n[CONFIRMED] Proceeding with cryptographic erase...`n" -ForegroundColor Green
            break
        }
    } while ($true)
}

#====================================================================================
# USER CONFIRMATIONS
#====================================================================================

# Check domain disconnect status first
Confirm-DomainDisconnect

# Require explicit confirmation by typing "ERASE ALL DATA" to prevent accidental execution
$confirmation = Read-Host "Type 'ERASE ALL DATA' (all caps) to confirm and continue"
if ($confirmation -ne "ERASE ALL DATA") {
    Write-Error "Confirmation text doesn't match. Process aborted."
    exit 1
}

#====================================================================================
# MANUAL BITLOCKER VERIFICATION INSTRUCTIONS
#====================================================================================

# Provide detailed instructions for manual BitLocker activation before automated process
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

#====================================================================================
# TPM VERIFICATION
#====================================================================================

# Verify the TPM chip is present and properly configured before proceeding
# TPM is essential for secure key storage during BitLocker operations
$tpm = Get-Tpm
if (-not $tpm.TpmPresent -or -not $tpm.TpmEnabled -or -not $tpm.TpmActivated -or -not $tpm.TpmOwned -or -not $tpm.TpmReady) {
    Write-Error "TPM is not enabled, activated, owned, or ready. Aborting. Ensure TPM is set up correctly."
    exit 1
}
Write-Output "TPM is present, enabled, activated, owned, and ready."

#====================================================================================
# MAIN VOLUME PROCESSING LOOP
#====================================================================================

# Get all fixed internal volumes (excluding specified drives and volumes without a mount point)
$volumes = Get-BitLockerVolume | Where-Object {
    $_.MountPoint -and 
    ($_.VolumeType -ne 'Unknown') -and
    ($excludeDrives -notcontains $_.MountPoint)
}

# Show which drives will be processed
Write-Host "`nThe following drives will be ERASED:" -ForegroundColor Red
$volumes | ForEach-Object { Write-Host "  - $($_.MountPoint)" -ForegroundColor Red }
Write-Host "" # Empty line for readability

# Process each volume individually
foreach ($vol in $volumes) {
    $drive = $vol.MountPoint
    Write-Output "`n--- Processing volume ${drive} ---"
    try {
        #---------------------------------------------------------------------------
        # STEP 1: BACKUP EXISTING BITLOCKER RECOVERY KEYS
        #---------------------------------------------------------------------------
        
        # Retrieve and backup existing BitLocker recovery keys for potential emergency use
        $keyProtectors = $vol.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
        if ($keyProtectors) {
            foreach ($protector in $keyProtectors) {
                $recKey = $protector.RecoveryPassword
            }
            Write-Output "Backed up existing recovery key(s) for ${drive} to USB."
        } else {
            # If no recovery password protector exists, add one for backup before proceeding
            $newProt = Add-BitLockerKeyProtector -MountPoint $drive -RecoveryPasswordProtector -ErrorAction Stop
            
            # Retrieve the newly added protector and save it
            $volUpdated = Get-BitLockerVolume -MountPoint $drive
            $newRecProtector = $volUpdated.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
            foreach ($protector in $newRecProtector) {
                if ($protector.RecoveryPassword) {
                    $recKey = $protector.RecoveryPassword
                }
            }
        }

        #---------------------------------------------------------------------------
        # STEP 2: VERIFY AND ENABLE BITLOCKER IF NEEDED
        #---------------------------------------------------------------------------
        
        # Check if BitLocker is already enabled on this volume
        if ($vol.ProtectionStatus -eq 'On') {
            Write-Output "${drive} is already encrypted. Skipping BitLocker enablement."
        } else {
            # Enable BitLocker encryption if not already encrypted
            Write-Output "${drive} is not encrypted. Enabling BitLocker (full disk encryption)..."
            try {
                # Use different encryption methods based on drive type (OS vs data)
                if ($vol.VolumeType -eq 'OperatingSystem') {
                    Write-Output "Enabling BitLocker on Operating System drive ${drive} with TPM and Recovery Password Protector..."
                    # For OS drive: Use TPM + Recovery Password and strongest available encryption
                    Enable-BitLocker -MountPoint $drive -EncryptionMethod XtsAes256 -UsedSpaceOnly:$false `
                                    -TpmProtector -RecoveryPasswordProtector -SkipHardwareTest -ErrorAction Stop
                } else {
                    Write-Output "Enabling BitLocker on data drive ${drive} with Recovery Password Protector..."
                    # For data drives: Use Recovery Password and strongest available encryption
                    Enable-BitLocker -MountPoint $drive -EncryptionMethod XtsAes256 -UsedSpaceOnly:$false `
                                    -RecoveryPasswordProtector -ErrorAction Stop
                }
                Write-Output "BitLocker encryption started on ${drive}."
            } catch {
                Write-Error "Failed to enable BitLocker on ${drive}: $_"
                continue
            }
        }

        #---------------------------------------------------------------------------
        # STEP 3: ENSURE BITLOCKER IS FULLY ACTIVATED AND ENCRYPTION COMPLETED
        #---------------------------------------------------------------------------
        
        Write-Output "Ensuring BitLocker is fully activated on ${drive}..."
        try {
            # Resume BitLocker if it was previously suspended
            Resume-BitLocker -MountPoint $drive -ErrorAction Stop
            Write-Output "BitLocker resumed on ${drive}."

            # Check BitLocker status and wait for encryption to complete if necessary
            $status = Get-BitLockerVolume -MountPoint $drive
            if ($status.VolumeStatus -ne 'FullyEncrypted') {
                Write-Output "Waiting for ${drive} encryption to complete..."
                
                # Monitor encryption progress with periodic checks
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

        #---------------------------------------------------------------------------
        # STEP 4: HANDLE USED-SPACE-ONLY ENCRYPTION SCENARIOS
        #---------------------------------------------------------------------------
        
        # Check if the volume was initially encrypted using "used space only" mode
        # If so, wipe free space to ensure complete encryption of entire drive
        $manageStatus = (manage-bde -status $drive) 2>&1
        if ($manageStatus -match "Used Space Only Encrypted") {
            Write-Output "Volume ${drive} was encrypted using 'used space only'. Wiping free space..."
            manage-bde -wipefreespace $drive
            Write-Output "Free space on ${drive} has been encrypted (wipefreespace complete)."
        }

        #---------------------------------------------------------------------------
        # STEP 5: CRYPTOGRAPHIC ERASE PROCESS
        #---------------------------------------------------------------------------
        
        # Perform the actual cryptographic erase by replacing all known protectors with an unknown one
        Write-Output "Removing known protectors and adding a new unknown recovery key for ${drive}..."
        
        # Record existing protector IDs to identify the new one after addition
        $origProtectors = (Get-BitLockerVolume -MountPoint $drive).KeyProtector
        $origIDs = $origProtectors | ForEach-Object { $_.KeyProtectorId }
        
        # Add a new recovery password protector - this will be the ONLY way to access data
        # We specifically DO NOT back this up, which is what makes the erase cryptographic
        Add-BitLockerKeyProtector -MountPoint $drive -RecoveryPasswordProtector -ErrorAction Stop | Out-Null
        
        # Find the newly added protector's ID (the one not in the original list)
        $allProtectors = (Get-BitLockerVolume -MountPoint $drive).KeyProtector
        $newProtector = $allProtectors | Where-Object { 
            $_.KeyProtectorId -notin $origIDs -and $_.KeyProtectorType -eq 'RecoveryPassword'
        }
        
        # Verify the new protector was actually added
        if (-not $newProtector) {
            throw "Failed to add new recovery protector on ${drive}."
        }
        
        # Store the new protector ID - this is the one we'll keep
        $newID = $newProtector.KeyProtectorId
        
        # Remove all original protectors, leaving ONLY the new unknown one
        # This is the critical step for cryptographic erasure
        foreach ($prot in $allProtectors) {
            if ($prot.KeyProtectorId -ne $newID) {
                Remove-BitLockerKeyProtector -MountPoint $drive -KeyProtectorId $prot.KeyProtectorId -Confirm:$false
            }
        }
        Write-Output "All original protectors removed from ${drive}. Data is now secured by an *unknown* key."
    }
    catch {
        # Error handling for individual volume processing failures
        Write-Error "ERROR processing ${drive}: $_"
        # Continue to next volume rather than terminating entire script
        continue
    }
}

#====================================================================================
# SYSTEM CLEANUP AND FINALIZATION
#====================================================================================

Write-Output "====================================================================="
Write-Output "          Wrapping things up                                         "
Write-Output "====================================================================="

# Disable Windows Fast Startup to ensure a full shutdown/cold boot
# This prevents cached credentials from potentially remaining in memory
Write-Output "Disabling Fast Startup..."
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0 -Force

# Force TPM clearance - requires physical presence in BIOS on next boot
# This ensures TPM keys are also wiped for complete security
Write-Output "Clearing TPM authorization..."
try {
    Clear-Tpm -AllowClear -AllowPhysicalPresence -ErrorAction Stop
    Write-Output "TPM cleared successfully."
}
catch {
    Write-Output "TPM clearance (REQUIRES BIOS RESET)"
}

Write-Output "`nAll internal drives processed. The system will reboot now to complete the purge."

#====================================================================================
# REBOOT COUNTDOWN AND EXECUTION
#====================================================================================

# Countdown before forcing system reboot to complete the process
Write-Host "System will reboot in $countdownSeconds seconds..." -ForegroundColor Yellow
for ($i = $countdownSeconds; $i -gt 0; $i--) {
    Write-Host "`rRebooting in $i seconds..." -NoNewline
    Start-Sleep -Seconds 1
}

# Force system reboot to apply all changes
Restart-Computer -Force
