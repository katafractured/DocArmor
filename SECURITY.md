# DocArmor Security Architecture

## Data At Rest

- **Encryption algorithm:** AES-256-GCM (AEAD) via Apple CryptoKit
- **Granularity:** Per page, per encryption operation — each page receives its own random 12-byte nonce
- **Storage format:** ciphertext + 16-byte authentication tag stored in SwiftData; nonce stored as a separate field on `DocumentPage`
- **Vault key:** 256-bit `SymmetricKey` stored in iOS Keychain with `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`
  - Key is bound to the device and requires an active device passcode
  - Key is automatically destroyed by the OS if the device passcode is removed
  - Key is never exported, synced, or backed up to iCloud

## Data In Transit

**None.** DocArmor makes zero network calls. There is no server infrastructure, no analytics SDK, no crash reporter, and no third-party framework. This is verified by static analysis — the binary contains no `URLSession`, `URLRequest`, or network-adjacent framework calls in app code.

## Backup Security

- **KDF:** PBKDF2-HMAC-SHA256 with 310,000 iterations (above NIST SP 800-132 minimum recommendation of 210,000 for SHA-256 as of 2023)
- **Salt:** 16-byte random salt generated per export
- **Outer envelope:** AES-256-GCM
- **Format version:** 2 (version 1 legacy KDF supported for restore compatibility only)
- **Scope:** Backup includes all document metadata, encrypted page data, the vault master key, and household member list
- **File type:** `.docarmorbackup` (UTI: `com.katafract.docarmor.backup`)

## Key Management

| Event | Action |
|-------|--------|
| First launch | `SymmetricKey` generated and stored in Keychain |
| App launch | Key loaded from Keychain; app refuses to open vault if key is absent |
| Vault reset | Key deleted before SwiftData flush, then a fresh key is generated |
| Backup restore | Old key replaced atomically via `VaultKey.replace(with:)` |
| Device passcode removed | iOS automatically revokes the Keychain item |

The key is generated with `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`. On Simulator, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` is used as a fallback because Simulator does not enforce passcode presence.

## Threat Model

| Threat | Mitigation |
|--------|-----------|
| Device theft | Keychain accessibility class requires device passcode; AES-256-GCM ciphertext is computationally infeasible to brute-force |
| iCloud backup exfiltration | SwiftData store excluded via `URLResourceValues.isExcludedFromBackup = true` on all store files |
| Screen recording / AirPlay | `UIScreen.capturedDidChangeNotification` triggers a full-screen overlay on VaultView and DocumentDetailView when capture is detected |
| Passphrase-protected backup leak | PBKDF2 with 310,000 rounds makes offline dictionary attacks expensive |
| Malicious backup file | `archive.version <= 2` guard rejects unknown future versions; AES-GCM tag verification rejects tampered ciphertext |

## Known Limitations

- **Emergency Card data** is stored unencrypted in App Group `UserDefaults` by design. This is required for the Home Screen widget to read it without decryption. Users explicitly opt in to this feature and are informed that Emergency Card data is accessible outside the encrypted vault.
- **Exported images** (via the Share sheet) leave the encrypted vault as plain JPEG files. The app presents a privacy confirmation dialog before any share operation.
- **Cross-device sync** is not supported. The vault is a single-device store. Migrating to a new device requires an encrypted backup export and restore.

## Responsible Disclosure

Security vulnerabilities should be reported to: security@katafract.com

Please include a description of the issue, steps to reproduce, and your assessment of severity. We will acknowledge receipt within 48 hours and aim to ship a fix within 30 days for critical vulnerabilities.
