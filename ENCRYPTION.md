# Writer security model

## How the vault is encrypted

1. A new vault receives a random 16-byte salt from `SecRandomCopyBytes`.
2. PBKDF2-HMAC-SHA256 derives a 32-byte key from the UTF-8 password, salt, and stored iteration count. New vaults use 600,000 iterations. Existing vaults continue using the count recorded when they were created.
3. The complete notes payload, including note titles, timestamps, rich-text formatting, and original inline-image bytes, is encoded as a binary property list and sealed with AES-256-GCM through CryptoKit. CryptoKit generates a fresh nonce for every save. Version 1 JSON payloads remain readable and are migrated on save.
4. The vault file stores the salt, KDF settings, nonce, ciphertext, and authentication tag. These values do not need to be secret. The password and derived key are not stored.
5. Unlocking derives the same key and asks AES-GCM to authenticate and decrypt the payload. A wrong password, changed ciphertext, or changed authentication tag fails authentication.

The derived key exists only while the vault is unlocked and is discarded when the app locks. The vault directory and current vault file are restricted to the current macOS user (`0700` and `0600`).

## What this protects

The design protects vault contents copied from disk or backups, provided the password is strong. AES-GCM also detects modifications to the encrypted payload.

It does not protect plaintext while the vault is unlocked. A process with access to the user's session may be able to read memory, observe keystrokes, capture the screen, or inspect copied text. Swift strings and UI controls can make internal copies, so the app cannot guarantee complete password or plaintext zeroization.

The outer vault header is not encrypted. It reveals the format version, payload encoding, creation time, algorithms, KDF work factor, salt, nonce, ciphertext length, and authentication tag. Note content, titles, note timestamps, formatting, attachment names, image bytes, and display sizes are inside the encrypted payload.

## Passwords and recovery

- New vaults require a password of at least 12 characters and matching confirmation. Writer rejects a small set of known-trivial values. Existing vaults remain unlockable with their original password so the policy does not strand older data.
- Prefer a unique, randomly generated password or a long passphrase stored in a reputable password manager.
- Losing the password means losing access. Writer has no recovery key, escrow service, reset flow, or back door.
- Changing a password requires decrypting the vault with the old password and re-encrypting it with a new salt and key. Writer does not currently expose that operation.
- The salt is public and prevents attackers from reusing one precomputed password table across vaults. It does not compensate for a weak password.
- The PBKDF2 iteration count slows offline guessing but cannot stop it. Work factors should be reviewed over time and increased for newly created or re-keyed vaults as hardware improves.

## Operational considerations

- Keep encrypted backups of `vault.writer` and any archived vaults. Test that backups can be restored. Backups remain tied to the password used when each vault was created.
- Copying a note places plaintext on the system clipboard. By default Writer preserves that value when locking so it remains available for pasting. An internal `clearClipboardOnLock` policy can opt into clearing Writer's unchanged clipboard value; clipboard managers may retain independent history regardless.
- Writer saves pending changes before locking. A disk-full, permissions, or hardware failure can still prevent a save, so backups remain important.
- The first save of a version 1 vault creates an encrypted `vault.writer.migration.*` rollback archive before atomically replacing the current file with version 2.
- Inline images are decrypted in memory while the vault is unlocked. Writer does not create its own plaintext attachment or thumbnail cache.
- Archived vaults are still encrypted, but they remain sensitive: weak or reused passwords can be attacked offline indefinitely.
- Do not reuse an AES-GCM nonce with the same key. Writer delegates nonce generation to CryptoKit and creates a new sealed box on every save.
- Any future vault-format change should use a new format version, preserve authenticated decryption, strictly bound attacker-controlled KDF parameters, and include a tested migration and rollback path.

## Resource limits

Writer applies one resource policy before reading, decoding, decrypting, parsing, importing, or saving vault content. The current limits are:

- 80 MiB encoded vault file and 48 MiB ciphertext/plaintext
- 500 notes, 2 MiB of body text per note, and 8 MiB of body text across the vault
- 16 MiB of RTFD per note and 32 MiB across the vault
- 64 images per note and 256 across the vault, with 8 MiB per image and 24 MiB of source-image bytes across the vault
- still images only, at most 8,192 pixels on either axis, 40 megapixels per image, 80 megapixels per note, 160 megapixels per vault, and a 100:1 maximum aspect ratio

RTFD packages are inspected before AppKit parsing, and embedded attachment bytes must match their separately authenticated, ImageIO-preflighted image sources. These limits intentionally trade unusually large documents for bounded unlock, rendering, and recovery behavior.

## Current limitations

- Password derivation uses PBKDF2 because it is available through the platform APIs and is part of the existing format. A memory-hard KDF such as Argon2id would provide better resistance to GPU/ASIC guessing, but adopting it requires a carefully versioned format and a vetted implementation.
- Vault header fields are validated but are not supplied to AES-GCM as additional authenticated data. Content tampering is authenticated; a future format should also cryptographically bind the security-relevant header to the ciphertext.
- There is no optional Keychain/Secure Enclave convenience unlock. Adding one should wrap or store a random vault key rather than store the user's password, and must define device migration and recovery behavior first.
