
# 🔐 BitLocker Cryptographic Erase Script

> **Author**: Abdullah Kareem  
> **License**: [MIT License](./LICENSE)  
> **GitHub**: [github.com/cyberkareem](https://github.com/cyberkareem)  
> **Compliance**: NIST SP 800-88 Rev. 1 – Purge-Level Sanitization

---

## 📄 Overview

This PowerShell script performs **cryptographic erasure** on all internal drives using **BitLocker**, in alignment with **NIST SP 800-88 Revision 1 Purge-level** requirements. It ensures data is permanently destroyed by removing all key protectors, making decryption impossible.

This script is intended for **Windows systems** being decommissioned or repurposed and supports:

- Microsoft Surface devices
- Lenovo ThinkPads
- Any NVMe/SATA-based SSD laptop with TPM and BitLocker

---

## ✅ Features

- Full Disk Encryption using **XTS-AES 256**
- Support for **NVMe SSDs**, SEDs, and TPM-backed BitLocker setups
- Automatic protector removal for **Cryptographic Erase**
- Clears **TPM** and disables **Fast Startup** to ensure **cold shutdown**
- Script is **interactive**, provides confirmations, and logs all steps
- **Domain detection** and enforcement of local-only context

---

## 📌 Requirements

- Windows 10/11 with PowerShell
- TPM 1.2 or higher (must be enabled, owned, and ready)
- BitLocker available and supported on internal drives
- Local Administrator privileges
- Must be **disconnected from any domain (Azure AD or On-Prem AD)**

---

## 🛠️ Usage

1. **Disconnect from domain** (Azure AD or On-Prem)   
2. **Run PowerShell as Administrator**  
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   .\BitLocker-CryptoErase.ps1
   ```
3. **Follow on-screen prompts** for confirmation and readiness  
4. Script performs the following:
   - Verifies TPM readiness
   - Enables BitLocker if not already active
   - Ensures full encryption and wipes free space
   - Removes all protectors and adds unknown key
   - Clears TPM and disables Fast Startup
5. **Machine reboots** after countdown

---

## 📋 Checklist

- [ ] Device is disconnected from domain (Azure AD or On-Premise)
- [ ] BitLocker is enabled on all internal drives
- [ ] TPM is functional and ready
- [ ] Data backup is complete (if applicable)
- [ ] Script executed as Administrator
- [ ] System reboots and prompts for recovery key (as expected)
- [ ] Final step: partitions deleted via recovery media

---

## ⚠️ Warning

> **This operation is irreversible.**  
> Once protector keys are removed, encrypted data cannot be decrypted.  
> Run this script **only on devices marked for secure decommissioning or disposal**.

---

## 📜 NIST Compliance

The script meets or exceeds **NIST SP 800-88 Rev. 1 Purge** requirements by:

| Script Phase              | NIST Requirement Met                            | Purpose                                               |
|---------------------------|-------------------------------------------------|-------------------------------------------------------|
| BitLocker Encryption      | Appendix A (FIPS 140-2 AES-XTS)                 | Encrypts drive with approved cryptographic algorithm  |
| Free Space Wipe           | Appendix A / §2.5                               | Ensures full drive content is encrypted               |
| Key Protector Removal     | Appendix A                                      | Removes decryption capability                         |
| TPM Clearance             | Appendix A                                      | Clears stored secrets in hardware                     |
| Fast Startup Disabled     | Page 24                                         | Guarantees cold boot and key removal from memory      |

---

## 📦 Deployment Use Cases

This script is suitable for:

- Enterprises retiring laptops
- Asset disposal procedures
- Zero-touch device purging in IT support environments
- Could be used (via USB or SCCM/Intune automation)

---

## 🧾 License

This project is licensed under the [MIT License](./LICENSE).  
You may use, modify, and distribute it freely with proper attribution.

---

## ✉️ Contact

For contributions, inquiries, or improvements:

- 📧 abdullahalikareem@gmail.com  
- 🌐 https://linktr.ee/cyberkareem  
- 🔗 https://github.com/cyberkareem

---

## 🙏 Acknowledgements

Inspired by community best practices, NIST publications, and real-world enterprise security needs.  
Special thanks to contributors in the InfoSec and PowerShell ecosystems.

---
