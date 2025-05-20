
# 🔐 BitLocker Cryptographic Erase Script

> **Author**: Abdullah Kareem  
> **License**: [MIT License](./LICENSE)  
> **GitHub**: [github.com/cyberkareem](https://github.com/cyberkareem)  
> **Compliance**: NIST SP 800-88 Rev. 1 – Purge-Level Sanitization
> **Blog Post:** [Introducing the BitLocker Cryptographic Erase Utility – Secure Data Destruction Made Simple](https://medium.com/@cyberkareem/introducing-the-bitlocker-cryptographic-erase-utility-secure-data-destruction-made-simple-1955b830e1aa)

---

## ⚠️ Purpose

The **BitLocker Cryptographic Erase Utility** is a PowerShell-based solution that performs **irreversible data sanitization** on internal drives using native BitLocker encryption. It ensures **compliance with the "Purge" level requirements** defined by the **NIST Special Publication 800-88 Revision 1** the gold standard for secure media sanitization in both government and enterprise environments.

This utility is ideal for IT administrators, cybersecurity professionals, and organizations that need to securely wipe data from systems prior to repurposing, decommissioning, or asset disposal.

---

## ✅ Features

- 🔐 **Cryptographic Erasure**: Securely renders all data inaccessible by destroying encryption keys used by BitLocker.
- 🧩 **Full NIST 800-88 Rev.1 Compliance** (Purge-level, Cryptographic Erase technique).
- 💾 **Internal Drive Focus**: Automatically detects fixed internal drives while allowing exclusion of specific volumes.
- 🔍 **Unallocated Space Sanitization**: Detects, partitions, and encrypts unallocated regions on each drive to ensure no data remnants are missed.
- 🛡 **TPM Verification**: Confirms Trusted Platform Module (TPM) is present, activated, and ready before proceeding.
- 🧠 **Multi-Layered Confirmation Flow**: Prevents accidental execution with explicit user prompts, domain-disconnect verification, and mandatory manual confirmation.
- 🔄 **BitLocker Integration**: It gives you the lead to enforce enabling Bitlocker manually and then ensures that it is enbaled, monitors progress, handles suspended states, and removes known protectors.
- 🔧 **Final Cleanup**: Disables Fast Startup, clears TPM, and enforces cold reboot to eliminate residuals from memory or cached credentials.

---

## 📌 Requirements

- Windows 10/11 with PowerShell
- TPM 1.2 or higher (must be enabled, owned, and ready)
- BitLocker available and supported on internal drives
- Local Administrator privileges
- Must be **disconnected from any domain (Azure AD or On-Prem AD)**

---

## 📦 How to Use

### 🔁 Step-by-Step Instructions

1. **Download the Repository**
   ```bash
   git clone https://github.com/CyberKareem/BitLocker-CryptoErase.git
   ```

2. **Open PowerShell as Administrator**

3. **Allow Script Execution (temporary bypass)**
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   ```

4. **Run the Script**
   ```powershell
   .\BitLocker_Cryptographic_Erase_NIST800-88.ps1
   ```

5. **Interactive Prompts Will Guide You**:
   - Choose drives to exclude (e.g., external USB)
   - Confirm domain disconnection
   - Enable or verify BitLocker
   - Manually activate BitLocker if not already encrypted
   - Confirm destruction by typing `ERASE ALL DATA`
   - TPM will be cleared and system reboot initiated

---

## 🖼 The utility in action

![image](https://github.com/user-attachments/assets/ec6e8a54-42e5-47a8-8380-fd257f3d8c03)

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

## 🚨 Caution

> ⚠️ This utility **permanently deletes** all data from selected internal drives. There is **no recovery** after execution. Use this tool **only on systems being retired, reassigned, or securely wiped**.

Multiple safeguards are included to prevent unintended usage. Please read and follow all prompts carefully.

---

## 📜 NIST SP 800-88 Rev.1 Compliance

This utility is explicitly designed to align with **NIST SP 800-88 Rev.1**, particularly the **Purge** standard through **Cryptographic Erase**, as outlined in the publication’s Appendix A.

### How the Tool Meets NIST 800-88 Requirements

| NIST 800-88 Rev.1 Guideline | Compliance in This Utility |
|-----------------------------|-----------------------------|
| **Media Sanitization Type** | Cryptographic Erase (Purge Level) |
| **Method**                  | Key management via BitLocker. Original keys are destroyed and replaced with unknown keys. |
| **Applicability**           | Solid-State Drives (SSDs), self-encrypting drives (SEDs), fixed internal disks |
| **Verification** | TPM ownership and readiness check, BitLocker encryption status, key protector audit |
| **Post-Erasure State** | Data remains encrypted but is permanently inaccessible without original keys |
| **Additional Measures** | TPM cleared and reboot enforced to flush memory and system state |

### Why Cryptographic Erase Works

Instead of overwriting every byte of data (which is time-consuming and SSD-unfriendly), cryptographic erase renders data inaccessible by:

1. **Encrypting all content using strong AES-256 encryption via BitLocker.**
2. **Removing all known key protectors** (e.g. TPM, recovery key, password).
3. **Replacing them with a newly generated recovery key** that is **not backed up or saved**.
4. The new key is then **immediately forgotten** making all data mathematically irretrievable.

This method is endorsed by NIST as a secure, efficient alternative to traditional wipe methods, especially for encrypted media.

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

## 🤝 Contributing

Your contributions are welcome! You can:  
- Submit feature ideas or bug reports via GitHub Issues  
- Fork the repo and create a pull request  
