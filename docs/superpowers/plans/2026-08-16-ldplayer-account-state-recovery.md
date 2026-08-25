# LDPlayer Account State Recovery Plan

> **For agentic workers:** Execute each checkbox in order and retain runtime evidence before declaring the account flow fixed.

**Goal:** Make the freshly created `MT5-Fresh` LDPlayer instance open the authenticated MT5 demo experience and expose Settings → Account → `+`.

**Architecture:** The app intentionally gates a clean install behind device-token activation. Because the token is stored with `flutter_secure_storage`, its encrypted app data must remain paired with the Android Keystore; preserve the working `MT5-Dev` instance, create a full instance backup, and restore that backup into `MT5-Fresh`. Do not modify Flutter UI or backend code unless the authenticated flow still reproduces a UI defect afterward.

**Tech Stack:** Flutter Android APK, LDPlayer 9, `ldconsole.exe`, existing EX V2 API.

## Global Constraints

- Keep `MT5-Dev` (index 2) unchanged and available as the recovery source.
- Restore the full index-2 image, including its Android Keystore, into `MT5-Fresh` (index 3).
- Do not delete an emulator, modify the required technology stack, or expose the device token.
- Verify behavior through the running app after restore.

---

### Task 1: Verify the diagnosis and exact targets

- [ ] Confirm index 2 is named `MT5-Dev` and index 3 is named `MT5-Fresh` using `ldconsole list2`.
- [ ] Confirm the clean instance shows device activation while the saved working evidence shows the authenticated Settings screen.
- [ ] Confirm the package ID is `com.tradingdemo.trading_mobile`.

### Task 2: Create a recoverable instance backup

- [ ] Stop index 2 cleanly so its virtual disks are consistent.
- [ ] Export the full state from index 2 to a uniquely named file under `.codex_tmp` with `ldconsole backup`.
- [ ] Verify that the backup command succeeds and the backup file exists with non-zero size.
- [ ] Keep index 2 stopped and unchanged as the recovery source.

### Task 3: Restore the state into the fresh instance

- [ ] Stop index 3 cleanly before restoration.
- [ ] Restore the verified full backup into index 3 with `ldconsole restore`.
- [ ] Reapply the `MT5-Fresh` title and `590x1280@240` display settings if the restored source metadata replaces them.
- [ ] Start index 3 and launch the package.
- [ ] Confirm the app no longer shows the device-activation gate.

### Task 4: Verify the requested account flow

- [ ] Confirm the authenticated trading interface opens without a network error.
- [ ] Open Settings, then Account, and confirm the `+` control opens broker/account entry.
- [ ] Confirm the existing working index 2 remains intact.
- [ ] If the authenticated flow still has a reproducible UI defect, capture it and create a separate TDD code-fix plan; otherwise make no source-code changes.

### Task 5: Repository and runtime checks

- [ ] Run Flutter analysis, build, and relevant tests required by `AGENTS.md`.
- [ ] Confirm tracked Git status contains no unintended source changes.
- [ ] Report the exact runtime result and any retained backup path.
