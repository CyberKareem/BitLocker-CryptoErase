BitLocker Cryptographic Erase Script (NIST 800-88 Rev.1 Compliant)

Overview

This PowerShell script automates secure data sanitization by performing a cryptographic erase on all internal drives using BitLocker, following the NIST SP 800-88 Rev.1 "Purge" standard.
It is designed to make data permanently unrecoverable by encrypting the drive fully and invalidating all known encryption keys.

Features

- Detects and verifies TPM presence and readiness
- Enables BitLocker (full disk encryption, XTS-AES-256) if not already enabled
- Monitors and waits for full encryption completion
- Backs up recovery keys automatically to a specified USB drive (e.g., D:\)
- Invalidates all known encryption keys (TPM, recovery keys)
- Leaves the drive encrypted but inaccessible
- Clears TPM (optional step, BIOS configuration may be required)
- Provides a 60-second countdown before automatic reboot
- Designed for compliance with NIST 800-88 Rev.1 (Purge) guidelines

Requirements

- Windows 10 or Windows 11
- Administrator privileges
- TPM 1.2+ or 2.0 (enabled, owned, activated, ready)
- External USB drive mounted as D: for recovery key backup
- Secure Boot may be enabled or disabled

Usage Instructions

Insert a USB flash drive and confirm it appears as D:\.
Open PowerShell as Administrator.

Set execution policy to allow running the script:
Set-ExecutionPolicy Bypass -Scope Process -Force

Run the script:
Edit
.\BitLocker_Cryptographic_Erase_NIST800-88.ps1

The script will:

- Validate TPM.
- Encrypt any unprotected internal drives.
- Back up BitLocker recovery keys.
- Invalidate known keys (perform cryptographic erase).
- Clear TPM if allowed.
- Reboot the system automatically after a countdown.

Important Warnings

⚠️ This script makes data recovery impossible.
⚠️ Ensure that all important data is backed up elsewhere before running.
⚠️ After reboot, drives will be encrypted and locked with unknown keys — data will be lost forever.

License

This project is licensed under the MIT License.

Credits

Created and maintained by Abdullah Kareem @CyberKareem.
Designed for secure enterprise-grade media sanitization following best practices.
