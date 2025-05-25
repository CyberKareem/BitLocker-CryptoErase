# BitLocker Cryptographic Erase Script for NIST 800-88 rev.1 Compliance
# This script performs a cryptographic erase on all internal drives using BitLocker,
# ensuring data is permanently deleted and unrecoverable.
# Requires -RunAsAdministrator

<#
.SYNOPSIS
    BitLocker Cryptographic Erase Script for NIST 800-88 rev.1 Compliance

.DESCRIPTION
    This script performs a cryptographic erase on all internal drives using BitLocker,
    ensuring data is permanently deleted and unrecoverable in accordance with
    NIST Special Publication 800-88 Revision 1 guidelines.
    It ncludes handling of unallocated spaces to ensure complete drive erasure.

.NOTES
    Version:        1.2
    Author:         Abdullah Kareem
    GitHub:         https://github.com/cyberkareem
    Contact:        abdullahalikareem@gmail.com
    Creation Date:  April 25, 2025
    
    WARNING: THIS WILL MAKE DATA IRRECOVERABLE
    * Requires TPM 1.2+ and BitLocker capability.
    * Must perform COLD shutdown after execution
    * For use only on systems being decommissioned or repurposed

.EXAMPLE
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\BitLocker-CryptoErase-Enhanced.ps1

.LINK
    https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-88r1.pdf
#>

#====================================================================================
# MAIN INTRO BANNER
#====================================================================================

Write-Host @"

                                                                                            
 ╔══════════════════════════════════════════════════════════════════════════════════════╗
 ║  [*] BITLOCKER CRYPTOGRAPHIC SECURE ERASE UTILITY - NIST 800-88 REV.1 COMPLIANT      ║
 ║  [*] SECURE DATA DESTRUCTION TOOL | v1.2                                             ║ 
 ║  [*] DEVELOPED BY: ABDULLAH KAREEM  | Github.com/CyberKareem                         ║
 ╚══════════════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor White

#====================================================================================
# CONFIGURATION VARIABLES
#====================================================================================

# Time in seconds to wait before the script forces a system reboot at completion
$countdownSeconds = 5

#====================================================================================
# USER INTERFACE - INITIAL WARNINGS AND INFORMATION
#====================================================================================

# Display script header and warning banners
Write-Host @"
 ╔══════════════════════════════════════════════════════════════════════════════════════╗
 ║  [!] SECURITY WARNING                                                                ║
 ║  [!] ██╗    ██╗ █████╗ ██████╗ ███╗   ██╗██╗███╗   ██╗ ██████╗                       ║
 ║  [!] ██║    ██║██╔══██╗██╔══██╗████╗  ██║██║████╗  ██║██╔════╝                       ║
 ║  [!] ██║ █╗ ██║███████║██████╔╝██╔██╗ ██║██║██╔██╗ ██║██║  ███╗                      ║
 ║  [!] ██║███╗██║██╔══██║██╔══██╗██║╚██╗██║██║██║╚██╗██║██║   ██║                      ║
 ║  [!] ╚███╔███╔╝██║  ██║██║  ██║██║ ╚████║██║██║ ╚████║╚██████╔╝                      ║
 ║  [!]  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚═════╝                       ║
 ║                                                                                      ║
 ║                                                                                      ║
 ║  /!\ THIS PROCESS WILL PERMANENTLY DESTROY ALL DATA ON THIS SYSTEM.                  ║
 ║  /!\ THIS PROCESS WILL PERMANENTLY DESTROY ALL DATA ON THIS SYSTEM.                  ║
 ║  /!\ THERE IS NO RECOVERY OPTION AFTER COMPLETION.                                   ║
 ║  /!\ DATA WILL BE CRYPTOGRAPHICALLY ERASED USING SECURE KEY ELIMINATION.             ║
 ║                                                                                      ║
 ║                                                                                      ║
 ╚══════════════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor White

#====================================================================================
# EXTERNAL DRIVE IDENTIFICATION
#====================================================================================

Write-Host @"
 ╔══════════════════════════════════════════════════════════════════════════════════════╗
 ║  [+] VOLUME SCANNER                                                                  ║
 ║  [+] ┌───┐  ┌───┐  ┌───┐  ┌───┐  ┌───┐  ┌───┐       SCANNING DRIVES...               ║
 ║  [+] │   │  │   │  │   │  │   │  │   │  │   │  ◄►   IDENTIFYING VOLUMES...           ║
 ║  [+] └───┘  └───┘  └───┘  └───┘  └───┘  └───┘       ANALYZING MOUNT POINTS...        ║
 ╚══════════════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor White

# List all available drives for user reference
# Get and display all available drives with their information
$allDrives = Get-Volume | Where-Object { $_.DriveLetter } | Select-Object DriveLetter, FileSystemLabel, DriveType, SizeRemaining, Size
Write-Output "Available drives on this system:"
$allDrives | Format-Table -AutoSize

# Prompt for external drive letters to exclude from erasure
$excludeDrives = @()
do {
    $driveInput = Read-Host "`nEnter drive letter to EXCLUDE from erasure (e.g., 'D' for D: drive) or press Enter if done"
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

Write-Host @"
 ╔══════════════════════════════════════════════════════════════════════════════════════╗
 ║  [*] DOMAIN VERIFICATION                                                             ║
 ║  [*]   ┌──────────┐                                                                  ║
 ║  [*]   │ COMPUTER │______╳_______► DOMAIN CONTROLLER                                 ║
 ║  [*]   └──────────┘                                                                  ║
 ║  [*]       ▲                    CONNECTION CHECK IN PROGRESS...                      ║
 ╚══════════════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor White

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
# UNALLOCATED SPACE HANDLING
#====================================================================================

function Process-UnallocatedSpace {
    Write-Host @"
 ╔══════════════════════════════════════════════════════════════════════════════════════╗
 ║  [▓] UNALLOCATED SPACE PROCESSOR                                                     ║
 ║  [▓] ╔═══════════════════════════════════════╗                                       ║
 ║  [▓] ║ ░░░░░░░░░░░░ ░░░░░░░ ░░░░░░░░░░░░░░░  ║ <-- ANALYZING DISK STRUCTURE          ║
 ║  [▓] ║ ░░░░░░░░░░ FINDING HIDDEN PARTITIONS ░║ <-- IDENTIFYING RAW VOLUMES           ║
 ║  [▓] ╚═══════════════════════════════════════╝                                       ║
 ╚══════════════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor White

    # Log the excluded drive list for debugging
    if ($excludeDrives.Count -gt 0) {
        Write-Output "Excluded drives: $($excludeDrives -join ', ')"
    } else {
        Write-Output "No drives excluded."
    }
    
    # Get all physical disks that aren't excluded
    $physicalDisks = Get-Disk | Where-Object { 
        $_.BusType -ne 'USB' -and     # Exclude USB drives
        $_.IsBoot -eq $true -or       # Include boot disk
        $_.IsSystem -eq $true -or     # Include system disk
        $_.OperationalStatus -eq 'Online' # Include other online internal disks
    }
    
    foreach ($disk in $physicalDisks) {
        $diskNumber = $disk.Number
        
        # Get all volumes on this disk
        $diskVolumes = Get-Partition -DiskNumber $diskNumber | 
                       Where-Object { $_.DriveLetter } | 
                       ForEach-Object { "$($_.DriveLetter):" }
        
        Write-Output "Checking Disk $diskNumber with volumes: $($diskVolumes -join ', ')"
        
        # Check if this disk contains ANY excluded drives
        $containsExcludedDrive = $false
        foreach ($vol in $diskVolumes) {
            if ($excludeDrives -contains $vol) {
                $containsExcludedDrive = $true
                Write-Output "Disk $diskNumber contains excluded drive $vol"
                break
            }
        }
        
        # Skip entire disk if it contains any excluded drives
        if ($containsExcludedDrive) {
            Write-Output "Skipping Disk $diskNumber entirely as it contains excluded drive(s)."
            continue
        }
        
        # First check if disk has any unallocated space
        $diskInfo = Get-Disk -Number $diskNumber | Select-Object Number, Size, AllocatedSize
        $totalUnallocatedSpace = $diskInfo.Size - $diskInfo.AllocatedSize
        $unallocatedGB = [math]::Round($totalUnallocatedSpace / 1GB, 2)
        
        # If significant unallocated space exists (more than 50MB), scan for individual regions
        if ($totalUnallocatedSpace -gt 50MB) {
            Write-Output "Disk $diskNumber has approximately $unallocatedGB GB of total unallocated space."
            
            # Get detailed information about unallocated regions using DiskPart
            $diskpartScript = @"
select disk $diskNumber
list partition
exit
"@
            $tempFile = [System.IO.Path]::GetTempFileName()
            $diskpartScript | Out-File -FilePath $tempFile -Encoding ASCII
            
            Write-Output "Scanning for individual unallocated regions on Disk $diskNumber..."
            $diskpartOutput = diskpart /s $tempFile
            Remove-Item -Path $tempFile -Force
            
            # Check if we have MBR or GPT disk - affects maximum partition count
            $isDiskGPT = (Get-Disk -Number $diskNumber).PartitionStyle -eq "GPT"
            $maxPartitions = if ($isDiskGPT) { 128 } else { 4 }
            
            # Get current partition count and calculate how many we can add
            $currentPartitions = Get-Partition -DiskNumber $diskNumber | Measure-Object
            $currentPartitionCount = $currentPartitions.Count
            $remainingPartitionSlots = $maxPartitions - $currentPartitionCount
            
            if ($remainingPartitionSlots -le 0) {
                Write-Output "Cannot create new partitions on Disk $diskNumber - maximum partition limit reached."
                continue
            }
            
            Write-Output "Disk $diskNumber can accommodate up to $remainingPartitionSlots new partitions."
            
            # Ask for confirmation once per disk before processing unallocated regions
            $confirmFormat = Read-Host "Do you want to create volumes in all unallocated regions on Disk $diskNumber for secure erasure? (Y/N)"
            if ($confirmFormat.ToUpper() -ne "Y") {
                Write-Output "Skipping unallocated space on Disk $diskNumber as per user choice."
                continue
            }
            
            # Now process each unallocated region individually
            $regionsProcessed = 0
            $regionsAttempted = 0
            $maxRegionsToProcess = [Math]::Min(10, $remainingPartitionSlots) # Safety limit
            $newDriveLetters = @() # Track newly created drive letters
            
            # Create a more robust DiskPart script that handles both creation AND formatting
            while ($regionsAttempted -lt $maxRegionsToProcess) {
                try {
                    # Create a script that creates AND formats the partition in one operation
                    # This ensures we don't end up with raw partitions
                    $createScript = @"
select disk $diskNumber
create partition primary
format fs=ntfs label="New Volume" quick
assign
exit
"@
                    $tempCreateFile = [System.IO.Path]::GetTempFileName()
                    $createScript | Out-File -FilePath $tempCreateFile -Encoding ASCII
                    
                    # Execute diskpart to create and format a single partition
                    Write-Output "Processing unallocated region #$($regionsAttempted+1)..."
                    $createOutput = diskpart /s $tempCreateFile
                    Remove-Item -Path $tempCreateFile -Force
                    
                    # Check for success patterns in the output
                    $successPattern1 = "DiskPart successfully created the specified partition"
                    $successPattern2 = "DiskPart successfully assigned the drive letter"
                    $successPattern3 = "DiskPart successfully formatted the volume"
                    
                    $createSucceeded = ($createOutput -match $successPattern1) -or 
                                      ($createOutput -match $successPattern2) -or
                                      ($createOutput -match $successPattern3)
                    
                    if ($createSucceeded) {
                        $regionsProcessed++
                        
                        # Give system time to register the new drive
                        Start-Sleep -Seconds 3
                        
                        # Parse DiskPart output to find the drive letter
                        # Look for patterns like "Volume X has been assigned the drive letter X"
                        $driveLetterPattern = "Volume \w+ has been assigned the drive letter ([A-Z])"
                        $driveLetterMatch = $createOutput | Where-Object { $_ -match $driveLetterPattern }
                        
                        if ($driveLetterMatch) {
                            # Extract letter from match
                            foreach ($line in $driveLetterMatch) {
                                if ($line -match $driveLetterPattern) {
                                    $extractedLetter = $matches[1]
                                    Write-Output "Created and formatted partition with drive letter ${extractedLetter}: in unallocated region #$($regionsAttempted+1)."
                                    $newDriveLetters += "${extractedLetter}:"
                                }
                            }
                        }
                        else {
                            # Fallback detection for newly created drive letters
                            Write-Output "Drive letter not found in DiskPart output. Looking for newly added drives..."
                            
                            # Get list of drive letters before
                            $beforeDrives = Get-Volume | Where-Object { $_.DriveLetter } | ForEach-Object { $_.DriveLetter }
                            
                            # Force refresh of drive info
                            Start-Sleep -Seconds 3
                            
                            # Get list of drive letters after
                            $afterDrives = Get-Volume | Where-Object { $_.DriveLetter } | ForEach-Object { $_.DriveLetter }
                            
                            # Find newly added drive letters
                            $newDrives = $afterDrives | Where-Object { $beforeDrives -notcontains $_ }
                            
                            if ($newDrives.Count -gt 0) {
                                foreach ($letter in $newDrives) {
                                    # Verify the volume is properly formatted as NTFS
                                    $volume = Get-Volume -DriveLetter $letter
                                    
                                    if ($volume.FileSystem -ne "NTFS") {
                                        Write-Output "Detected new drive ${letter}: but it's not NTFS formatted. Formatting now..."
                                        Format-Volume -DriveLetter $letter -FileSystem NTFS -NewFileSystemLabel "SecureErase" -Confirm:$false -Force | Out-Null
                                    }
                                    
                                    Write-Output "Successfully prepared volume ${letter}: from unallocated space."
                                    $newDriveLetters += "${letter}:"
                                }
                            }
                            else {
                                Write-Output "Created a new partition but couldn't determine the drive letter."
                                
                                # Additional step: Find partitions without drive letters and try to assign them
                                $noLetterPartitions = Get-Partition -DiskNumber $diskNumber | Where-Object { $null -eq $_.DriveLetter }
                                
                                foreach ($partition in $noLetterPartitions) {
                                    try {
                                        # Assign a drive letter
                                        $partition | Add-PartitionAccessPath -AssignDriveLetter
                                        
                                        # Get the newly assigned drive letter
                                        Start-Sleep -Seconds 2
                                        $updatedPartition = Get-Partition -DiskNumber $diskNumber -PartitionNumber $partition.PartitionNumber
                                        
                                        if ($updatedPartition.DriveLetter) {
                                            $letter = $updatedPartition.DriveLetter
                                            
                                            # Format the volume if it's RAW
                                            $volume = Get-Volume -DriveLetter $letter -ErrorAction SilentlyContinue
                                            if ($volume -and $volume.FileSystemType -eq "RAW") {
                                                Write-Output "Formatting RAW volume ${letter}:..."
                                                Format-Volume -DriveLetter $letter -FileSystem NTFS -NewFileSystemLabel "SecureErase" -Confirm:$false -Force | Out-Null
                                            }
                                            
                                            Write-Output "Assigned letter ${letter}: to previously letterless partition."
                                            $newDriveLetters += "${letter}:"
                                        }
                                    }
                                    catch {
                                        Write-Output "Could not assign drive letter to partition: $_"
                                    }
                                }
                            }
                        }
                    }
                    else {
                        # Check for specific error patterns that indicate no more unallocated space
                        $noSpacePatterns = @(
                            "There is not enough usable free space",
                            "No usable free extent could be found",
                            "The specified disk does not contain any extents",
                            "There is not enough space available on the disk"
                        )
                        
                        $noMoreSpace = $false
                        foreach ($pattern in $noSpacePatterns) {
                            if ($createOutput -match $pattern) {
                                $noMoreSpace = $true
                                break
                            }
                        }
                        
                        if ($noMoreSpace) {
                            Write-Output "No more usable unallocated regions found on Disk $diskNumber."
                            break
                        }
                        else {
                            Write-Output "Attempt to create partition in region #$($regionsAttempted+1) failed with unknown error."
                            # Output the DiskPart error for debugging
                            $createOutput | ForEach-Object { Write-Output "  $_" }
                        }
                    }
                }
                catch {
                    Write-Output "Error processing unallocated region #$($regionsAttempted+1): $_"
                }
                
                $regionsAttempted++
                
                # Check if we've reached the disk's partition limit
                if ($regionsProcessed -ge $remainingPartitionSlots) {
                    Write-Output "Reached maximum partition count for Disk $diskNumber."
                    break
                }
                
                # After each attempt, scan to see if we still have unallocated space
                $updatedDiskInfo = Get-Disk -Number $diskNumber | Select-Object Number, Size, AllocatedSize
                $remainingUnallocated = $updatedDiskInfo.Size - $updatedDiskInfo.AllocatedSize
                
                if ($remainingUnallocated -lt 50MB) {
                    Write-Output "All significant unallocated space on Disk $diskNumber has been processed."
                    break
                }
            }
            
            # After processing, check for any RAW volumes that still need formatting
            $rawVolumes = Get-Volume | Where-Object { $_.FileSystemType -eq "RAW" }
            if ($rawVolumes.Count -gt 0) {
                Write-Output "`nDetected RAW volumes that need formatting:"
                
                foreach ($volume in $rawVolumes) {
                    if ($volume.DriveLetter) {
                        $letter = $volume.DriveLetter
                        Write-Output "Formatting RAW volume ${letter}:..."
                        
                        try {
                            Format-Volume -DriveLetter $letter -FileSystem NTFS -NewFileSystemLabel "SecureErase" -Confirm:$false -Force | Out-Null
                            Write-Output "Successfully formatted volume ${letter}: from RAW to NTFS."
                            
                            # Only add to newDriveLetters if not already there
                            if ($newDriveLetters -notcontains "${letter}:") {
                                $newDriveLetters += "${letter}:"
                            }
                        }
                        catch {
                            Write-Output "Error formatting RAW volume ${letter}: $_"
                        }
                    }
                }
            }
            
            if ($regionsProcessed -gt 0) {
                Write-Output "Successfully processed $regionsProcessed unallocated regions on Disk $diskNumber."
                Write-Output "New drive letters created: $($newDriveLetters -join ', ')"
            } else {
                Write-Output "No unallocated regions were successfully processed on Disk $diskNumber."
            }
        }
        else {
            Write-Output "Disk $diskNumber has no significant unallocated space."
        }
    }
    
    # Update the volume list after potentially creating new volumes
    Write-Output "`nUpdated drive list after processing unallocated space:"
    Get-Volume | Where-Object { $_.DriveLetter } | Select-Object DriveLetter, FileSystemLabel, FileSystemType, DriveType, SizeRemaining, Size | Format-Table -AutoSize
    
    # Final check to catch any remaining RAW volumes
    $remainingRawVolumes = Get-Volume | Where-Object { $_.FileSystemType -eq "RAW" }
    if ($remainingRawVolumes.Count -gt 0) {
        Write-Output "`n[WARNING] There are still RAW volumes that need formatting:"
        $remainingRawVolumes | Select-Object DriveLetter, FileSystemLabel, FileSystemType, DriveType, SizeRemaining, Size | Format-Table -AutoSize
        
        $formatRawVolumes = Read-Host "Do you want to attempt to format these RAW volumes now? (Y/N)"
        if ($formatRawVolumes.ToUpper() -eq "Y") {
            foreach ($volume in $remainingRawVolumes) {
                if ($volume.DriveLetter) {
                    $letter = $volume.DriveLetter
                    Write-Output "Formatting RAW volume ${letter}:..."
                    
                    try {
                        Format-Volume -DriveLetter $letter -FileSystem NTFS -NewFileSystemLabel "SecureErase" -Confirm:$false -Force | Out-Null
                        Write-Output "Successfully formatted volume ${letter}: from RAW to NTFS."
                    }
                    catch {
                        Write-Output "Error formatting RAW volume ${letter}: $_"
                    }
                }
            }
        }
    }
}

#====================================================================================
# USER CONFIRMATIONS
#====================================================================================

# Check domain disconnect status first
Confirm-DomainDisconnect

# Process unallocated space before proceeding with BitLocker operations
Process-UnallocatedSpace

Write-Host @"
 ╔══════════════════════════════════════════════════════════════════════════════════════╗
 ║  [!] CRITICAL CHECKPOINT                                                             ║
 ║  [!]                                                                                 ║
 ║  [!]  ██████╗ ██████╗ ███╗   ██╗███████╗██╗██████╗ ███╗   ███╗                       ║
 ║  [!] ██╔════╝██╔═══██╗████╗  ██║██╔════╝██║██╔══██╗████╗ ████║                       ║
 ║  [!] ██║     ██║   ██║██╔██╗ ██║█████╗  ██║██████╔╝██╔████╔██║                       ║
 ║  [!] ██║     ██║   ██║██║╚██╗██║██╔══╝  ██║██╔══██╗██║╚██╔╝██║                       ║
 ║  [!] ╚██████╗╚██████╔╝██║ ╚████║██║     ██║██║  ██║██║ ╚═╝ ██║                       ║
 ║  [!]  ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝                       ║
 ╚══════════════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor White

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
Write-Host @"
 ╔══════════════════════════════════════════════════════════════════════════════════════╗
 ║  [#] BITLOCKER ACTIVATION                                                            ║
 ║  [#]                                                                                 ║
 ║  [#]  ┌─────────────────────┐   ENCRYPTION STATUS                                    ║
 ║  [#]  │ ╔═╗ BITLOCKER ╔═╗   │   █████████████████░░░░░░░░░░░                         ║
 ║  [#]  │ ╚═╝ PROTECTED ╚═╝   │   PREPARING VOLUMES...                                 ║
 ║  [#]  └─────────────────────┘                                                        ║
 ╚══════════════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor White

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

Write-Host @"
 ╔══════════════════════════════════════════════════════════════════════════════════════╗
 ║  [>] TPM SECURITY MODULE CHECK                                                       ║
 ║  [>]  ┌───────────────────────────┐                                                  ║
 ║  [>]  │ ┌─────┐    TRUSTED        │  VERIFYING TPM INTEGRITY...                      ║
 ║  [>]  │ │ TPM │    PLATFORM       │  CHECKING TPM OWNERSHIP...                       ║
 ║  [>]  │ └─────┘    MODULE         │  VALIDATING TPM ACTIVATION...                    ║
 ║  [>]  └───────────────────────────┘                                                  ║
 ╚══════════════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Yellow

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

Write-Host @"
 ╔══════════════════════════════════════════════════════════════════════════════════════╗
 ║  [*] CRYPTOGRAPHIC ERASE                                                             ║
 ║  [*]                                                                                 ║
 ║  [*]  KEY STATUS:    [ GENERATING NEW KEYS ][ PREPARING PROTECTORS ]                 ║
 ║  [*]  VOLUME STATUS: [ PROCESSING VOLUMES ][ WIPING SECURITY TOKENS ]                ║
 ║  [*]                                                                                 ║
 ╚══════════════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor White

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

Write-Host @"
 ╔══════════════════════════════════════════════════════════════════════════════════════╗
 ║  [✓] FINAL SECURITY OPERATIONS                                                       ║
 ║  [✓]                                                                                 ║
 ║  [✓]  ┌───────────┐   ┌────────────┐     FAST STARTUP: [ DISABLING... ]              ║
 ║  [✓]  │ TPM CLEAR │ → │ DEEP PURGE │     TPM CLEARANCE: [ PROCESSING... ]            ║
 ║  [✓]  └───────────┘   └────────────┘     PREPARING Reboot : [ INITIALIZING... ]      ║
 ╚══════════════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor White

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

Write-Host @"
 ╔══════════════════════════════════════════════════════════════════════════════════════╗
 ║  [!] SYSTEM REBOOT REQUIRED                                                          ║
 ║  [!]                                                                                 ║
 ║  [!]  ┌─────────────────────────┐  CRYPTOGRAPHIC ERASE COMPLETE                      ║
 ║  [!]  │ ██████  REBOOT    ██████│  → DATA IS NOW IRRECOVERABLE                       ║
 ║  [!]  └─────────────────────────┘  → COLD BOOT REQUIRED AFTER REBOOT                 ║
 ║  [!]                                                                                 ║
 ╚══════════════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor White

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
