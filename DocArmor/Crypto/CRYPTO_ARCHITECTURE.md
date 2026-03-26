# DocArmor Cryptographic Architecture

## Document Page Encryption

| Property | Value |
|----------|-------|
| Algorithm | AES-256-GCM (Authenticated Encryption with Associated Data) |
| Key size | 256 bits (`SymmetricKey(size: .bits256)`) |
| Nonce | 12 bytes, randomly generated per page per encryption call |
| Authentication tag | 16 bytes, appended to ciphertext |
| Storage format | `encryptedImageData`: ciphertext ‖ tag; `nonce`: stored separately on `DocumentPage` |
| Framework | Apple CryptoKit (`AES.GCM.seal`, `AES.GCM.open`) |

### Encryption Flow

```
UIImage → JPEG (0.85 quality) → AES.GCM.seal(plaintext, using: key)
                                      ↓
                            SealedBox { nonce | ciphertext | tag }
                                      ↓
              DocumentPage { encryptedImageData = ciphertext + tag, nonce = nonce }
```

### Decryption Flow

```
DocumentPage { encryptedImageData, nonce }
    → ciphertext = encryptedImageData.dropLast(16)
    → tag        = encryptedImageData.suffix(16)
    → SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
    → AES.GCM.open(sealedBox, using: key) → JPEG Data → UIImage
```

## Vault Key Storage

| Property | Value |
|----------|-------|
| Key type | `SymmetricKey(size: .bits256)` |
| Storage | iOS Keychain (`kSecClassGenericPassword`) |
| Accessibility (device) | `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` |
| Accessibility (simulator) | `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` |
| iCloud sync | Disabled (`kSecAttrSynchronizable = false`) |
| Scope | This device only — key cannot migrate to another device |

The key is generated once on first launch using CryptoKit's built-in secure random source. It is serialised as raw bytes (`Data`) for Keychain storage and deserialised into a `SymmetricKey` on each load.

## Encrypted Backup KDF

| Property | Value |
|----------|-------|
| KDF | PBKDF2 |
| PRF | HMAC-SHA256 |
| Iterations | 310,000 |
| Salt | 16 bytes, randomly generated per export |
| Output key size | 32 bytes (256 bits) |
| Outer encryption | AES-256-GCM |
| Implementation | CommonCrypto `CCKeyDerivationPBKDF` |

### Backup Archive Format (Version 2)

```json
{
  "version": 2,
  "exportedAt": "<ISO8601 date>",
  "salt": "<base64 16 bytes>",
  "nonce": "<base64 12 bytes>",
  "ciphertext": "<base64 variable bytes + 16-byte GCM tag>"
}
```

The plaintext is a JSON-encoded `BackupPayload` containing:
- `householdMembers`: `[String]`
- `vaultKeyData`: `Data` (the raw 32-byte vault key)
- `documents`: array of document metadata and encrypted page data

### Legacy Version 1 KDF

Version 1 backups used a non-standard iterative SHA-256 scheme:

```
key = SHA256(SHA256(...SHA256(passphrase + salt) + passphrase + salt...))
           ↑____________________ 100,000 times ____________________↑
```

This scheme is **deprecated** and only used for restoring old backups. New backups always use PBKDF2 with 310,000 rounds (version 2).

## iCloud Backup Exclusion

The SwiftData store files (`default.store`, `default.store-wal`, `default.store-shm`) are excluded from device backup on every launch via:

```swift
var resourceValues = URLResourceValues()
resourceValues.isExcludedFromBackup = true
try url.setResourceValues(resourceValues)
```

This ensures encrypted document data never enters iCloud Backup or iTunes/Finder backup.

## SwiftData Configuration

```swift
ModelConfiguration(
    schema: Schema([Document.self, DocumentPage.self]),
    isStoredInMemoryOnly: false,
    allowsSave: true,
    cloudKitDatabase: .none   // iCloud sync explicitly disabled
)
```

`cloudKitDatabase: .none` prevents SwiftData from creating a CloudKit container or syncing any records to iCloud.
