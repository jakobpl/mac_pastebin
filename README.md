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

After unzipping, macOS may block the first launch (unsigned / not notarized). Newer macOS often shows only **Move to Trash** / **Done** — that is normal.

- Control-click (right-click) **Writer.app** → **Open** → confirm **Open**
- Or: **System Settings → Privacy & Security** → scroll down → **Open Anyway**
- Or in Terminal: `xattr -cr /path/to/Writer.app` then open the app again
