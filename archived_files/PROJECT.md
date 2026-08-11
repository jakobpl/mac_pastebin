# Archived: Encrypted Notes macOS App brief

> Archived on 2026-08-11. This early product brief conflicts with implemented rich-text and inline-image support. Current capabilities are documented in the root `README.md`; security details are documented in the root `ENCRYPTION.md`.

Build a local-only macOS Swift app for encrypted note-taking, writing, brainstorming, and drafting.

Priorities:
1. Security
2. Speed
3. Simplicity
4. Reliability

The app should be practical and fast, not over-designed.

Current UI direction:
- The app is in a focused visual-design phase for an Apple Liquid Glass inspired macOS interface.
- Locked state should feel like a large frosted glass window over the desktop, with a centered lock badge, password pill, and start-new-vault pill.
- Unlocked state should use puffy floating controls, a frosted notes pane, and a warm paper editor surface.
- Visual polish must not weaken the local-only encrypted vault model.

Core requirements:
- macOS app built with Swift / SwiftUI
- Local encrypted note vault
- AES-256-GCM encryption
- Password-derived encryption key
- No plaintext notes stored on disk
- Auto-lock when the app loses focus
- Manual lock button
- Simple writing interface
- Fast create/open/edit/save flow

Avoid:
- Cloud sync
- Accounts
- Collaboration
- Themes
- AI features
- Rich formatting
- Useless polish
