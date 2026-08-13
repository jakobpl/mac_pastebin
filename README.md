# Mac pastebin

A local encrypted rich-text notes app for macOS, written with SwiftUI and AppKit. Notes support font formatting and encrypted inline still images.

Notes are stored in `~/Library/Application Support/Writer/vault.writer`. The vault is encrypted with AES-256-GCM using a key derived from the user's password with PBKDF2-HMAC-SHA256. No password or derived key is written to disk.

## Current capabilities

- Multiple encrypted notes with rename and delete actions
- Rich-text font controls and encrypted inline still images
- Manual save, optional debounced auto-save, and Command-S
- Manual lock and automatic lock when Writer loses focus
- Password-protected vault creation, encrypted archive/restore, and corrupted-vault recovery
- Backward-compatible reading and migration of the original version 1 vault format

See [ENCRYPTION.md](ENCRYPTION.md) for the vault format, threat model, password guidance, recovery limitations, and operational considerations.

Implementation-specific Liquid Glass guidance is in [LIQUID_GLASS.md](LIQUID_GLASS.md). Deferred media-vault and appearance work is documented in [ROADMAP.md](ROADMAP.md).

## Build setup

Copy the local signing config (gitignored; do not commit):

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

Put your Apple Team ID in `Config/Local.xcconfig`, then open `writer.xcodeproj` in Xcode.

## Download

Prebuilt releases are attached on the [GitHub Releases](https://github.com/jakobpl/mac_pastebin/releases) page (`Writer-macOS.zip`).

After unzipping, macOS may block the first launch (unsigned / not notarized). Newer macOS often shows only **Move to Trash** / **Done** — that is normal.

- Control-click (right-click) **Writer.app** → **Open** → confirm **Open**
- Or: **System Settings → Privacy & Security** → scroll down → **Open Anyway**
- Or in Terminal: `xattr -cr /path/to/Writer.app` then open the app again
