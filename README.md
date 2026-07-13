# Writer

A local encrypted notes app for macOS, written in SwiftUI.

Notes are stored in `~/Library/Application Support/Writer/vault.writer`. The vault is encrypted with AES-256-GCM using a key derived from the user's password with PBKDF2-HMAC-SHA256. No password or derived key is written to disk.

See [ENCRYPTION.md](ENCRYPTION.md) for the vault format, threat model, password guidance, recovery limitations, and operational considerations.

## Build setup

Copy the local signing config (gitignored; do not commit):

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

Put your Apple Team ID in `Config/Local.xcconfig`, then open `writer.xcodeproj` in Xcode.

## Download

Prebuilt releases are attached on the [GitHub Releases](https://github.com/jakobpl/writer/releases) page (`Writer-macOS.zip`).

After unzipping, macOS may block the first launch (unsigned / not notarized). Use **Right-click the app → Open**, or allow it under **System Settings → Privacy & Security**.
