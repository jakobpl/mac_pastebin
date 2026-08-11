# Archived: Agentic Build Loop

> Archived on 2026-08-11. This prescriptive file-by-file loop predates current coding agents, references a nonexistent `SECURITY.md`, and no longer describes the project's workflow. It is retained only as project history.

You are building a macOS Swift encrypted note-taking app.

Do not build the whole app in one pass.

Every iteration must follow this loop:

1. Read:
   - PROJECT.md
   - LOOP.md
   - STATE.md
   - SECURITY.md

2. Identify the current phase.

3. Implement only the next small step.

4. Keep the app runnable.

5. Prefer simple, reliable code over clever abstractions.

6. After changes:
   - Explain what changed
   - Explain how to test it
   - Update STATE.md

7. Do not add features outside the current phase.

UI design phase addendum:
- The current UI target is defined by `desired_inrpiration_unlocked.png` and `desired_ui_inspiration__locked.png` in the project root.
- Iterate visually: build, render or capture locked/unlocked screenshots, compare against those references, then delete generated screenshots.
- Keep the encrypted vault behavior unchanged while polishing layout, materials, spacing, and title editing.

Core rule:
Security and reliability matter more than UI polish.

Crypto rule:
Do not invent custom cryptography.
Use platform crypto APIs when possible.
Use authenticated encryption.
Never store plaintext notes on disk.
