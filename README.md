# Writer

A local encrypted notes app for macOS, written in SwiftUI.

Notes are stored in `~/Library/Application Support/Writer/vault.writer`. The vault is encrypted with AES-256-GCM using a key derived from the user's password with PBKDF2-HMAC-SHA256. No password or derived key is written to disk.

See [ENCRYPTION.md](ENCRYPTION.md) for the vault format, threat model, password guidance, recovery limitations, and operational considerations.
