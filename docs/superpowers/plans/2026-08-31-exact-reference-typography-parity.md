# Exact Reference Typography Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Use
> `superpowers:test-driven-development` for every production change and
> `superpowers:verification-before-completion` before any parity claim. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make all app-controlled text visible in the 11 supplied reference
images use the correct role-specific face, apparent weight, size, tracking,
baseline, and color, with exact font-input locking and auditable visual parity.

**Architecture:** Add isolated, SHA-locked reference font families and an
explicit semantic-role contract; remove global width/weight inheritance; select
the winning face per role through glyph-level bake-off evidence; migrate each
screen independently; and verify through separate JPEG diagnostic and lossless
certification modes.

**Tech Stack:** Existing Flutter 3.44+ / Dart 3.12+ application, Riverpod,
GoRouter, existing CustomPainter chart, Flutter widget/golden/integration tests,
pure-Dart image comparison, static TTF font assets. No application-stack change.

**Spec:**
`docs/superpowers/specs/2026-08-31-exact-reference-typography-parity-design.md`

## Relationship to Existing Plans

This plan supersedes the font-binary, global `wdth: 90`, global inherited tab
style, synthetic-weight, and typography-acceptance assumptions in:

- `docs/superpowers/plans/2026-08-25-tab-typography-spacing-parity.md`
- `docs/superpowers/plans/2026-08-27-seven-state-visual-parity-completion.md`

It does not supersede their trading behavior, chart interaction, reference
fixtures, non-text layout, masking safety, or evidence-topology work.

## Non-Negotiable Constraints

- Read `META_TRADER_CLONE_GUIDE.md`, `README.md`, `docs/architecture.md`, and
  `docs/design-system.md` before Task 1 and again after any context compaction.
- Preserve the user's dirty worktree. Never run `git reset --hard`, broad
  checkout/restore, or bulk golden replacement. Patch only paths named by the
  active task and inspect the overlapping diff before every edit.
- Do not change providers, repositories, routes, API/realtime/auth/trading
  behavior, account fixtures, gestures, chart data, or backend contracts.
- Do not add the extracted Avenir binary to the repository without documented
  redistribution rights. A local `/tmp` copy is forensic input only.
- Do not loosen thresholds, expand masks, normalize candidates, or accept a
  screenshot as a production background.
- Treat every evidence/artifact output directory as immutable. Require it to be
  absent before first write; a retry uses a new UTC/run suffix and never
  overwrites or mixes an earlier manifest/report.
- Do not claim raw-pixel 100% from a JPEG. Use the exact claim vocabulary in the
  spec.
- Do not commit or push unless the user separately requests it.

## Canonical Commands

The repository guide requires the full mobile and backend gates after every
task. Before implementation, `dotnet --version` must report `8.0.421`, matching
`global.json`. If that SDK is unavailable, implementation is blocked until it is
installed; do not edit `global.json` or use a different SDK.

Command working directories are part of the contract. Preflight blocks and
asset-acquisition blocks containing repository-prefixed paths such as `mobile/`
or `docs/` run from the repository root. Every task-local `flutter` or `dart`
block whose paths start with `lib/`, `test/`, `tool/`, `integration_test/`, or
`test_driver/` runs with the executor workdir set explicitly to `mobile/`.
Backend-only blocks run with workdir `backend/`. Each fenced block is an
independent shell invocation: it must not depend on `cd` state or temporary
variables created in another block.

After the focused RED/GREEN command named by each implementation task (Tasks
1-12), run this complete common gate from the repository root:

```bash
(
  cd mobile
  flutter pub get
  flutter test
  flutter analyze
  flutter build apk --debug
)
(
  cd backend
  dotnet build Trading.sln
  dotnet test Trading.sln --no-build
)
```

No task checkbox may be completed unless every common-gate command exits 0. The
final task additionally runs the iOS simulator build. Task-local command blocks
do not replace this common gate; they add focused evidence to it.

## File Structure

### Create

- `mobile/assets/fonts/mt5-reference/Roboto-Regular.ttf`
- `mobile/assets/fonts/mt5-reference/Roboto-Bold.ttf`
- `mobile/assets/fonts/mt5-reference/RobotoCondensed-Regular.ttf`
- `mobile/assets/fonts/mt5-reference/RobotoCondensed-Bold.ttf`
- `mobile/assets/fonts/mt5-reference/LICENSE-Apache-2.0.txt`
- `mobile/assets/fonts/mt5-reference/font-lock.json`
- `mobile/lib/core/theme/reference_typography_profile.dart`
- `mobile/test/test_support/reference_typography_sources.dart`
- `mobile/test/test_support/reference_font_lock.dart`
- `mobile/test/test_support/sfnt_metadata_reader.dart`
- `mobile/test/test_support/reference_typography_role_manifest.dart`
- `mobile/test/test_support/tab_typography_candidate_export.dart`
- `mobile/test/reference_font_lock_test.dart`
- `mobile/test/reference_font_specimen_render_test.dart`
- `mobile/test/reference_font_specimen_test.dart`
- `mobile/test/reference_typography_role_coverage_test.dart`
- `mobile/test/primary_renderer_typography_evidence_test.dart`
- `mobile/test/tab_typography_candidate_export_test.dart`
- `mobile/integration_test/reference_font_specimen_device_test.dart`
- `mobile/test_driver/reference_font_specimen_device_test.dart`
- `mobile/tool/render_forensic_font_specimens.swift`
- `mobile/tool/compare_reference_font_specimens.dart`
- `mobile/tool/assemble_tab_capture_manifest.dart`
- `docs/screens/reference-typography-capture-protocol.md`
- `docs/screens/reference-typography-capture-manifest.schema.json`
- `docs/screens/reference-typography-capture-manifest.json`
- `docs/screens/reference-typography-color-lock.json`
- `docs/screenshots/reference-typography-font-bakeoff/README.md`

### Modify

- `mobile/pubspec.yaml`
- `mobile/pubspec.lock`
- `mobile/assets/fonts/README.md`
- `mobile/lib/core/theme/app_colors.dart`
- `mobile/lib/core/theme/app_typography.dart`
- `mobile/lib/core/theme/tab_reference_metrics.dart`
- `mobile/lib/core/theme/settings_reference_metrics.dart`
- `mobile/lib/core/theme/app_theme.dart`
- `mobile/lib/shared/widgets/app_shell.dart`
- `mobile/lib/features/market_watch/presentation/screens/market_watch_screen.dart`
- `mobile/lib/features/chart/presentation/screens/chart_screen.dart`
- `mobile/lib/features/chart/presentation/rendering/mt5_candle_painter.dart`
- `mobile/lib/features/chart/presentation/theme/chart_reference_theme.dart`
- `mobile/lib/features/trade/presentation/screens/trade_screen.dart`
- `mobile/lib/features/history/presentation/screens/history_screen.dart`
- `mobile/lib/features/profile/presentation/screens/settings_screen.dart`
- `mobile/test/test_support/reference_font_loader.dart`
- `mobile/test/test_support/tab_reference_manifest.dart`
- `mobile/test/tab_reference_manifest_test.dart`
- `mobile/test/tab_typography_tokens_test.dart`
- `mobile/test/tab_typography_comparator_test.dart`
- `mobile/test/tab_typography_golden_test.dart`
- `mobile/tool/compare_tab_typography.dart`
- `mobile/integration_test/tab_typography_device_test.dart`
- `mobile/test_driver/tab_typography_device_test.dart`
- the focused screen tests named in Tasks 5-9
- `docs/screens/reference-parity-manifest.md`
- `docs/screenshots/tab-typography-parity/README.md`

Do not assume every listed path needs a change. If a role already passes after
the correct face is installed, leave its production file untouched and record
the passing evidence.

---

## Preflight Gate 0: Protect the Dirty Worktree and Freeze the Failing Baseline

**Files:**

- Create, untracked evidence only:
  `artifacts/reference-typography-preflight/2026-08-31/`
- Do not modify production or existing golden files.

- [ ] **Step 1: Re-read project instructions and inspect overlap**

Run:

```bash
sed -n '1,$p' META_TRADER_CLONE_GUIDE.md
sed -n '1,$p' README.md
sed -n '1,$p' docs/architecture.md
sed -n '1,$p' docs/design-system.md
git status --short --untracked-files=all
dotnet --list-sdks
dotnet --version
git diff -- mobile/lib/core/theme/app_typography.dart \
  mobile/lib/core/theme/app_colors.dart \
  mobile/lib/core/theme/tab_reference_metrics.dart \
  mobile/lib/shared/widgets/app_shell.dart \
  mobile/lib/features/market_watch/presentation/screens/market_watch_screen.dart \
  mobile/lib/features/chart/presentation/screens/chart_screen.dart \
  mobile/lib/features/trade/presentation/screens/trade_screen.dart \
  mobile/lib/features/history/presentation/screens/history_screen.dart \
  mobile/lib/features/profile/presentation/screens/settings_screen.dart
```

Expected before implementation: `dotnet --version` is exactly `8.0.421`. The
2026-08-31 audit found only SDK `10.0.203`; if that remains true, stop here and
install the required SDK through the normal developer-machine process. Do not
change repository SDK policy to bypass the gate.

- [ ] **Step 2: Save a recoverable scoped preflight patch without changing it**

Run from the repository root:

```bash
test ! -e artifacts/reference-typography-preflight/2026-08-31
mkdir -p artifacts/reference-typography-preflight/2026-08-31
git diff --binary \
  --output=artifacts/reference-typography-preflight/2026-08-31/user-overlap.patch \
  -- mobile/lib mobile/test mobile/pubspec.yaml
shasum -a 256 iconMau/anhmau/* \
  artifacts/reference-typography-preflight/2026-08-31/user-overlap.patch
tar -czf artifacts/reference-typography-preflight/2026-08-31/untracked-overlap.tar.gz \
  mobile/lib/core/theme/settings_reference_metrics.dart \
  mobile/lib/shared/widgets/mt_tab_header_fade.dart \
  mobile/assets/images/metatrader5_settings_menu.png \
  mobile/test/goldens/settings \
  mobile/ios
shasum -a 256 \
  artifacts/reference-typography-preflight/2026-08-31/untracked-overlap.tar.gz
tar -tf artifacts/reference-typography-preflight/2026-08-31/untracked-overlap.tar.gz
```

The archive covers current untracked paths that overlap typography/platform work;
the terminal log from `git status --short --untracked-files=all` is the no-clobber
inventory. These backups are not permission to restore over later work.

- [ ] **Step 3: Reproduce and record the current baseline**

Run:

```bash
cd mobile
flutter pub get
flutter test test/tab_reference_manifest_test.dart \
  test/tab_typography_tokens_test.dart \
  test/tab_typography_comparator_test.dart \
  test/tab_typography_golden_test.dart
dart run tool/compare_tab_typography.dart \
  --candidate-dir test/goldens/tab-typography \
  --output-dir ../artifacts/reference-typography-preflight/2026-08-31/comparator
```

Expected baseline before implementation: the focused suite is not green; the
known audit found seven self-golden failures plus three stale comparator-evidence
expectations. The full comparator should exit 1. If the shape of failure differs,
stop and re-audit instead of updating snapshots.

The full `flutter test` run on 2026-08-31 ended `+760 ~1 -41`; failures extend
beyond the focused typography set into other dirty goldens and at least one
chart interaction test. Preserve this evidence. Task 1 cannot start until the
user selects/checkpoints a baseline and that complete suite is green.

- [ ] **Step 4: Run the required task gate**

This is a read-only preflight, not an implementation task. Run all common-gate
commands to expose baseline state, but record rather than conceal the known
failures. Do not begin Task 1 until the user-owned dirty baseline is checkpointed
and the complete suite is reproducibly green, or the user explicitly authorizes
a named baseline-reconciliation task. Never update dirty goldens merely to pass
this gate.

---

## Task 1: Lock All References and the Exact Redistributable Font Inputs

**Files:**

- Create: the six files under `mobile/assets/fonts/mt5-reference/`
- Create: `mobile/test/test_support/reference_typography_sources.dart`
- Create: `mobile/test/test_support/reference_font_lock.dart`
- Create: `mobile/test/test_support/sfnt_metadata_reader.dart`
- Create: `mobile/test/reference_font_lock_test.dart`
- Modify: `mobile/pubspec.yaml`
- Modify: `mobile/pubspec.lock`
- Modify: `mobile/assets/fonts/README.md`
- Modify: `mobile/test/test_support/reference_font_loader.dart`
- Modify: `mobile/test/tab_reference_manifest_test.dart`

- [ ] **Step 1: Write the failing corpus/font-lock tests**

Add a typed 11-source inventory with fields `id`, `path`, `sha256`, `width`,
`height`, `encoding`, `authority`, `theme`, `losslessSource`,
`hasCaptureProvenance`, and `certificationEligible`.

Add `reference_font_lock_test.dart` with this contract:

```dart
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all eleven reference files retain exact identity and authority', () async {
    expect(referenceTypographySources, hasLength(11));
    for (final source in referenceTypographySources) {
      final bytes = await File(source.path).readAsBytes();
      expect(sha256.convert(bytes).toString(), source.sha256, reason: source.id);
      final decoded = image.decodeImage(bytes)!;
      expect((decoded.width, decoded.height), (source.width, source.height));
      expect(source.losslessSource, source.encoding == 'png');
      expect(
        source.certificationEligible,
        source.losslessSource && source.hasCaptureProvenance,
      );
    }
  });

  test('current sources are diagnostic because capture provenance is absent', () {
    expect(referenceTypographySources, everyElement(
      isA<ReferenceTypographySource>()
          .having((item) => item.hasCaptureProvenance, 'provenance', isFalse)
          .having((item) => item.certificationEligible, 'eligible', isFalse),
    ));
  });

  test('all reference fonts match their hash, metadata, axes, and license', () {
    final lock = ReferenceFontLock.read(
      File('assets/fonts/mt5-reference/font-lock.json'),
    );
    const requiredBaseShas = <String>{
      'f87925e2be4c38abba7920ec54e5634f0538ba6368d758e4da300d9af12c9d27',
      '9287925cae90ac480804094ff0876832065e2db116470da1f524d79ed9c18b70',
      'f66f4e3088a52aa5e685a45d9a532c28d8de4bf1cf267586961018e5af488ec8',
      'ae01d956edc5a944ebbbd0c1d344b03973ab634419bc06093ce89f737e7e6e9a',
    };
    final lockedShas = lock.fonts.map((entry) => entry.sha256).toSet();
    expect(lockedShas, containsAll(requiredBaseShas));
    for (final entry in lock.fonts) {
      entry.verifyBytesAndSfntMetadata();
      expect(entry.axes, isEmpty);
      expect(entry.approvedRoleGroups, isNotEmpty);
      expect(entry.redistributable, isTrue);
      expect(entry.licenseEvidencePath, isNotEmpty);
      expect(File(entry.licenseEvidencePath).existsSync(), isTrue);
      if (requiredBaseShas.contains(entry.sha256)) {
        expect(entry.license, 'Apache-2.0');
      } else {
        expect(
          entry.approvedRoleGroups,
          everyElement(isIn(const <String>[
            'pricesNumeric',
            'chartNumeric',
            'tradeNumeric',
            'historyNumeric',
          ])),
        );
      }
    }
  });

  test('the forensic Avenir hash is absent unless a licensed lock approves it', () {
    const forensicSha =
        '94c0952db172bed2d0c030488a9d3f7f4bebb1398baf9e46e6a1acf5173ac192';
    final shipped = ReferenceFontLock.scanProductFonts();
    for (final font in shipped.where((item) => item.sha256 == forensicSha)) {
      final entry = ReferenceFontLock.current.bySha(font.sha256);
      expect(entry.licenseEvidencePath, isNotEmpty);
      expect(File(entry.licenseEvidencePath).existsSync(), isTrue);
      expect(entry.redistributable, isTrue);
    }
  });
}
```

Add `crypto: ^3.0.6` under `dev_dependencies` for SHA-256 verification. The
existing `image` dependency remains the decoder.

- [ ] **Step 2: Run RED**

```bash
flutter test test/reference_font_lock_test.dart \
  test/tab_reference_manifest_test.dart
```

Expected: FAIL because the 11-source inventory, four locked files, metadata
reader, font lock, and new family registrations do not exist.

- [ ] **Step 3: Add the exact four permitted files and license**

Use the four Apache-licensed font bytes corroborated by official package
`net.metaquotes.metatrader5` version `500.6140`. Do not add Avenir. The lock must
initially contain exactly these four baseline records. Task 2's lawful exact
branch may append a fifth numeric record, but it may not replace or weaken these
four records:

Retrieve and verify without unpacking any proprietary face into the repository:

```bash
MT5_FONT_AUDIT_DIR="$(mktemp -d)"
curl --fail --location \
  https://download.terminal.free/cdn/web/metaquotes.software.corp/mt5/metatrader5.apk \
  --output "$MT5_FONT_AUDIT_DIR/metatrader5.apk"
test "$(shasum -a 256 "$MT5_FONT_AUDIT_DIR/metatrader5.apk" | awk '{print $1}')" = \
  c76582495cdd55061a38942bae9a4d2d33ed140840af94dec82cc6ad7001782b
mkdir -p "$MT5_FONT_AUDIT_DIR/extracted"
unzip -j "$MT5_FONT_AUDIT_DIR/metatrader5.apk" \
  assets/fonts/Roboto-Regular.ttf \
  assets/fonts/Roboto-Bold.ttf \
  assets/fonts/RobotoCondensed-Regular.ttf \
  assets/fonts/RobotoCondensed-Bold.ttf \
  -d "$MT5_FONT_AUDIT_DIR/extracted"
test "$(shasum -a 256 "$MT5_FONT_AUDIT_DIR/extracted/Roboto-Regular.ttf" | awk '{print $1}')" = \
  f87925e2be4c38abba7920ec54e5634f0538ba6368d758e4da300d9af12c9d27
test "$(shasum -a 256 "$MT5_FONT_AUDIT_DIR/extracted/Roboto-Bold.ttf" | awk '{print $1}')" = \
  9287925cae90ac480804094ff0876832065e2db116470da1f524d79ed9c18b70
test "$(shasum -a 256 "$MT5_FONT_AUDIT_DIR/extracted/RobotoCondensed-Regular.ttf" | awk '{print $1}')" = \
  f66f4e3088a52aa5e685a45d9a532c28d8de4bf1cf267586961018e5af488ec8
test "$(shasum -a 256 "$MT5_FONT_AUDIT_DIR/extracted/RobotoCondensed-Bold.ttf" | awk '{print $1}')" = \
  ae01d956edc5a944ebbbd0c1d344b03973ab634419bc06093ce89f737e7e6e9a
strings "$MT5_FONT_AUDIT_DIR"/extracted/*.ttf | \
  rg 'Licensed under the Apache License, Version 2.0'
test ! -e mobile/assets/fonts/mt5-reference/Roboto-Regular.ttf
test ! -e mobile/assets/fonts/mt5-reference/Roboto-Bold.ttf
test ! -e mobile/assets/fonts/mt5-reference/RobotoCondensed-Regular.ttf
test ! -e mobile/assets/fonts/mt5-reference/RobotoCondensed-Bold.ttf
test ! -e mobile/assets/fonts/mt5-reference/LICENSE-Apache-2.0.txt
mkdir -p mobile/assets/fonts/mt5-reference
cp "$MT5_FONT_AUDIT_DIR/extracted/Roboto-Regular.ttf" \
  mobile/assets/fonts/mt5-reference/Roboto-Regular.ttf
cp "$MT5_FONT_AUDIT_DIR/extracted/Roboto-Bold.ttf" \
  mobile/assets/fonts/mt5-reference/Roboto-Bold.ttf
cp "$MT5_FONT_AUDIT_DIR/extracted/RobotoCondensed-Regular.ttf" \
  mobile/assets/fonts/mt5-reference/RobotoCondensed-Regular.ttf
cp "$MT5_FONT_AUDIT_DIR/extracted/RobotoCondensed-Bold.ttf" \
  mobile/assets/fonts/mt5-reference/RobotoCondensed-Bold.ttf
cp mobile/assets/fonts/LICENSE.txt \
  mobile/assets/fonts/mt5-reference/LICENSE-Apache-2.0.txt
shasum -a 256 mobile/assets/fonts/mt5-reference/*
```

The printed APK hash must equal
`c76582495cdd55061a38942bae9a4d2d33ed140840af94dec82cc6ad7001782b`
before extraction is accepted. Each font hash must match the literal lock below,
and all four binaries must contain the Apache 2.0 notice. Only then copy those
four exact files into `mobile/assets/fonts/mt5-reference/` and add the full
Apache 2.0 text whose SHA is locked below. If the live official package has changed, stop
and obtain the already audited `500.6140` artifact through an approved source;
never replace the lock with a newer unreviewed package just to continue. The
single block above intentionally keeps acquisition, verification, and copying in
one shell so the private temporary path is never assumed to survive another
command block.

```json
{
  "schemaVersion": 1,
  "sourcePackage": {
    "package": "net.metaquotes.metatrader5",
    "versionName": "500.6140",
    "versionCode": 6140,
    "downloadUrl": "https://download.terminal.free/cdn/web/metaquotes.software.corp/mt5/metatrader5.apk",
    "retrievedAt": "2026-08-31",
    "apkSha256": "c76582495cdd55061a38942bae9a4d2d33ed140840af94dec82cc6ad7001782b",
    "licenseTextSha256": "c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4"
  },
  "fonts": [
    {
      "file": "Roboto-Regular.ttf",
      "family": "Roboto",
      "subfamily": "Regular",
      "fullName": "Roboto Regular",
      "nameVersion": "Version 1.200310; 2013",
      "headRevision": 1.0,
      "unitsPerEm": 2048,
      "os2WeightClass": 400,
      "byteLength": 114976,
      "archivePath": "assets/fonts/Roboto-Regular.ttf",
      "sourceUrl": "https://download.terminal.free/cdn/web/metaquotes.software.corp/mt5/metatrader5.apk",
      "retrievedAt": "2026-08-31",
      "flutterFamily": "Mt5ReferenceRoboto",
      "weight": 400,
      "sha256": "f87925e2be4c38abba7920ec54e5634f0538ba6368d758e4da300d9af12c9d27",
      "license": "Apache-2.0",
      "licenseEvidencePath": "assets/fonts/mt5-reference/LICENSE-Apache-2.0.txt",
      "redistributable": true,
      "approvedRoleGroups": ["navigation", "settings", "toolbar", "tradeMetrics", "historySummary", "chartCanvas"],
      "axes": []
    },
    {
      "file": "Roboto-Bold.ttf",
      "family": "Roboto",
      "subfamily": "Bold",
      "fullName": "Roboto Bold",
      "nameVersion": "Version 1.100141; 2013",
      "headRevision": 1.0,
      "unitsPerEm": 2048,
      "os2WeightClass": 700,
      "byteLength": 135820,
      "archivePath": "assets/fonts/Roboto-Bold.ttf",
      "sourceUrl": "https://download.terminal.free/cdn/web/metaquotes.software.corp/mt5/metatrader5.apk",
      "retrievedAt": "2026-08-31",
      "flutterFamily": "Mt5ReferenceRoboto",
      "weight": 700,
      "sha256": "9287925cae90ac480804094ff0876832065e2db116470da1f524d79ed9c18b70",
      "license": "Apache-2.0",
      "licenseEvidencePath": "assets/fonts/mt5-reference/LICENSE-Apache-2.0.txt",
      "redistributable": true,
      "approvedRoleGroups": ["navigation", "settings", "toolbar", "tradeMetrics", "historySummary", "chartCanvas"],
      "axes": []
    },
    {
      "file": "RobotoCondensed-Regular.ttf",
      "family": "Roboto Condensed",
      "subfamily": "Regular",
      "fullName": "Roboto Condensed Regular",
      "nameVersion": "Version 1.200311; 2013",
      "headRevision": 1.0,
      "unitsPerEm": 2048,
      "os2WeightClass": 400,
      "byteLength": 114575,
      "archivePath": "assets/fonts/RobotoCondensed-Regular.ttf",
      "sourceUrl": "https://download.terminal.free/cdn/web/metaquotes.software.corp/mt5/metatrader5.apk",
      "retrievedAt": "2026-08-31",
      "flutterFamily": "Mt5ReferenceRobotoCondensed",
      "weight": 400,
      "sha256": "f66f4e3088a52aa5e685a45d9a532c28d8de4bf1cf267586961018e5af488ec8",
      "license": "Apache-2.0",
      "licenseEvidencePath": "assets/fonts/mt5-reference/LICENSE-Apache-2.0.txt",
      "redistributable": true,
      "approvedRoleGroups": ["pricesDense", "chartTicket", "tradeDense", "historyDense"],
      "axes": []
    },
    {
      "file": "RobotoCondensed-Bold.ttf",
      "family": "Roboto Condensed",
      "subfamily": "Bold",
      "fullName": "Roboto Condensed Bold",
      "nameVersion": "Version 1.200311; 2013",
      "headRevision": 1.0,
      "unitsPerEm": 2048,
      "os2WeightClass": 700,
      "byteLength": 115036,
      "archivePath": "assets/fonts/RobotoCondensed-Bold.ttf",
      "sourceUrl": "https://download.terminal.free/cdn/web/metaquotes.software.corp/mt5/metatrader5.apk",
      "retrievedAt": "2026-08-31",
      "flutterFamily": "Mt5ReferenceRobotoCondensed",
      "weight": 700,
      "sha256": "ae01d956edc5a944ebbbd0c1d344b03973ab634419bc06093ce89f737e7e6e9a",
      "license": "Apache-2.0",
      "licenseEvidencePath": "assets/fonts/mt5-reference/LICENSE-Apache-2.0.txt",
      "redistributable": true,
      "approvedRoleGroups": ["pricesDense", "chartTicket", "tradeDense", "historyDense"],
      "axes": []
    }
  ]
}
```

Implement a small pure-Dart SFNT reader for `head`, `name`, `OS/2`, `cmap`, and
optional `fvar`. In addition to the literal lock fields, assert that every Unicode
code point used by the 11 reference/specimen strings exists in the selected
face's `cmap`. Do not depend on machine-local `fc-scan` in the automated test.

- [ ] **Step 4: Register isolated families and load them in tests**

Append without changing existing family declarations or unrelated asset lines:

```yaml
    - family: Mt5ReferenceRoboto
      fonts:
        - asset: assets/fonts/mt5-reference/Roboto-Regular.ttf
          weight: 400
        - asset: assets/fonts/mt5-reference/Roboto-Bold.ttf
          weight: 700
    - family: Mt5ReferenceRobotoCondensed
      fonts:
        - asset: assets/fonts/mt5-reference/RobotoCondensed-Regular.ttf
          weight: 400
        - asset: assets/fonts/mt5-reference/RobotoCondensed-Bold.ttf
          weight: 700
```

`loadReferenceFonts()` must load these aliases in addition to existing families
until migration is complete.

- [ ] **Step 5: Run GREEN and the task gate**

```bash
flutter pub get
flutter test test/reference_font_lock_test.dart \
  test/tab_reference_manifest_test.dart
dart format --output=none --set-exit-if-changed test/test_support \
  test/reference_font_lock_test.dart test/tab_reference_manifest_test.dart
rg -n '[[:blank:]]+$' assets/fonts/mt5-reference test/test_support \
  test/reference_font_lock_test.dart test/tab_reference_manifest_test.dart
git diff --check -- pubspec.yaml pubspec.lock assets/fonts \
  test/reference_font_lock_test.dart \
  test/tab_reference_manifest_test.dart test/test_support
```

Expected `rg` status is 1 with no output (no trailing whitespace). The focused
tests parse both JSON and all binary metadata. Then run the complete common gate.

Expected: all reference hashes, font hashes, metadata, axis, license, and family
registration checks pass. Existing production typography is still unchanged.

---

## Task 2: Freeze the Primary Renderer, Export Current Candidates, and Select Faces

**Files:**

- Create: `mobile/test/test_support/reference_typography_role_manifest.dart`
- Create: `mobile/test/test_support/tab_typography_candidate_export.dart`
- Create: `mobile/test/reference_font_specimen_render_test.dart`
- Create: `mobile/test/reference_font_specimen_test.dart`
- Create: `mobile/test/tab_typography_candidate_export_test.dart`
- Create: `mobile/integration_test/reference_font_specimen_device_test.dart`
- Create: `mobile/test_driver/reference_font_specimen_device_test.dart`
- Create: `mobile/tool/render_forensic_font_specimens.swift`
- Create: `mobile/tool/compare_reference_font_specimens.dart`
- Create: `docs/screens/reference-typography-color-lock.json`
- Create: `docs/screenshots/reference-typography-font-bakeoff/README.md`
- Modify: `mobile/test/test_support/tab_reference_manifest.dart`
- Exact branch only: create the licensed numeric font and license evidence under
  `mobile/assets/fonts/mt5-reference/`, and modify `mobile/pubspec.yaml`,
  `mobile/pubspec.lock`, `mobile/assets/fonts/mt5-reference/font-lock.json`,
  `mobile/test/test_support/reference_font_loader.dart`, and
  `mobile/test/reference_font_lock_test.dart`.

**Interfaces:**

- `ReferenceRendererProfile.primary` is `ios`; Android and deterministic host
  rendering are separate secondary profiles.
- `TabTypographyCandidateExport.capture(caseId, outputDirectory)` renders the
  current widget tree inside a 393.333333 x 853.333333 logical
  `RepaintBoundary`, calls `toImage(pixelRatio: 1.5)`, and writes the PNG plus a
  candidate manifest with the sorted scoped source-file list/hash. Dark Trade
  uses 413 x 881 physical output and its own logical/DPR contract.
- Exact candidate filenames are the existing seven ids plus
  `settings-primary-590x1280.png`, `settings-secondary-590x1280.png`, and
  `dark-trade-413x881.png`.
- `TAB_REFERENCE_CASE=history` exports exactly the four `history-*` cases;
  `TAB_REFERENCE_CASE=all` exports all ten full-screen cases. Every other value
  is an exact id.

- [ ] **Step 1: Write RED tests for renderer and candidate export contracts**

`reference_font_specimen_render_test.dart` asserts that the primary profile is
iOS, semantic tokens are platform-independent, and every capture records the
actual renderer. `tab_typography_candidate_export_test.dart` asserts one selected
case is rendered from current source, has exact dimensions/opacity, and writes a
manifest whose PNG SHA matches disk. It must not read or copy an existing golden.

Run:

```bash
flutter test test/reference_font_specimen_render_test.dart \
  test/tab_typography_candidate_export_test.dart
```

Expected: FAIL because the renderer profile, fixed-boundary capture helper,
Settings/dark fixtures, and manifest writer do not exist.

- [ ] **Step 2: Implement the renderer and candidate-export harness**

Add exact fixtures for:

- seven existing `TabReferenceCase` states at 590 x 1280;
- Settings primary using the `image.png` account/scroll state;
- Settings secondary using only its shared role regions;
- dark Trade at 413 x 881 with the dark theme and its captured fixture values.

Case filtering happens before any candidate preflight, so exporting or comparing
`prices` never requires Settings/dark files. The export helper writes current
pixels to a new temporary directory; it never writes `test/goldens`.

- [ ] **Step 3: Render lawful candidates on iOS and Avenir only in a host forensic lane**

At DPR 1.5 and text scale 1.0, render the locked Roboto regular/bold, locked
Roboto Condensed regular/bold, and current repo faces as controls in the primary
iOS app. Use exact strings:

```text
Giá  Biểu đồ  Giao dịch  Lịch sử  Cài đặt
Số dư:  Vốn:  Tiền ký quỹ:  Mức ký quỹ (%):
XAUUSD buy 1
4637.05 → 4640.81
376.00  -341.00  103 310.00  203.24
L:  H:  M1  Orders  Deals
```

The integration app encodes its keyed specimen
`RenderRepaintBoundary.toImage(pixelRatio: 1.5)` as PNG and places the base64
bytes plus renderer/font/case metadata and app-observable
`Platform.operatingSystem`/`Platform.operatingSystemVersion` in
`binding.reportData`. The host driver
uses `integrationDriver(responseDataCallback: ...)`, reads the absolute output
directory and device id from `REFERENCE_SPECIMEN_OUTPUT` and
`REFERENCE_SPECIMEN_DEVICE_ID`, resolves that exact id in the saved
`flutter-devices.json`, decodes and hashes every PNG, and writes the candidate
manifest. It cross-checks app renderer/operating-system metadata against the
host target-platform record. If a native-window context
image is useful, the app may additionally call `binding.takeScreenshot(name)`
with no metadata arguments and the driver may retain it through `onScreenshot`;
that native-size file is not scored as the fixed specimen. The sandboxed app
never receives or writes a host filesystem path.

Select the actual iOS simulator/device shown by `flutter devices`. Use a stable,
new artifact directory so later scoring commands do not depend on a temporary
shell variable:

```bash
flutter devices --machine
: "${MT5_IOS_DEVICE_ID:?Set the exact iOS id from flutter devices --machine}"
test ! -e ../artifacts/reference-typography-font-bakeoff/ios-candidates-2026-08-31
mkdir -p ../artifacts/reference-typography-font-bakeoff/ios-candidates-2026-08-31
flutter devices --machine > \
  ../artifacts/reference-typography-font-bakeoff/ios-candidates-2026-08-31/flutter-devices.json
REFERENCE_SPECIMEN_OUTPUT="$PWD/../artifacts/reference-typography-font-bakeoff/ios-candidates-2026-08-31" \
REFERENCE_SPECIMEN_DEVICE_ID="$MT5_IOS_DEVICE_ID" \
flutter drive \
  --driver=test_driver/reference_font_specimen_device_test.dart \
  --target=integration_test/reference_font_specimen_device_test.dart \
  -d "$MT5_IOS_DEVICE_ID" \
  --dart-define=REFERENCE_RENDERER=ios
```

If the locked iOS renderer cannot run, stop the bake-off instead of ranking
host-renderer pixels as iOS evidence.

The external Avenir file cannot be loaded from a host `/tmp` path by a sandboxed
iOS app. Extract it only into a new temporary directory, verify it, and render a
separate diagnostic specimen on the host with CoreText/CoreGraphics via
`tool/render_forensic_font_specimens.swift`. The binary never enters the product,
test bundle, pubspec, or workspace artifacts:

```bash
MT5_FORENSIC_FONT_DIR="$(mktemp -d)"
MT5_FORENSIC_APK_DIR="$(mktemp -d)"
curl --fail --location \
  https://download.terminal.free/cdn/web/metaquotes.software.corp/mt5/metatrader5.apk \
  --output "$MT5_FORENSIC_APK_DIR/metatrader5.apk"
test "$(shasum -a 256 "$MT5_FORENSIC_APK_DIR/metatrader5.apk" | awk '{print $1}')" = \
  c76582495cdd55061a38942bae9a4d2d33ed140840af94dec82cc6ad7001782b
unzip -j "$MT5_FORENSIC_APK_DIR/metatrader5.apk" \
  assets/fonts/Avenir-Condensed-DemiBold.ttf \
  -d "$MT5_FORENSIC_FONT_DIR"
test "$(shasum -a 256 "$MT5_FORENSIC_FONT_DIR/Avenir-Condensed-DemiBold.ttf" | awk '{print $1}')" = \
  94c0952db172bed2d0c030488a9d3f7f4bebb1398baf9e46e6a1acf5173ac192
test ! -e ../artifacts/reference-typography-font-bakeoff/host-coretext-avenir-2026-08-31
mkdir -p ../artifacts/reference-typography-font-bakeoff/host-coretext-avenir-2026-08-31
xcrun swift tool/render_forensic_font_specimens.swift \
  --font "$MT5_FORENSIC_FONT_DIR/Avenir-Condensed-DemiBold.ttf" \
  --output ../artifacts/reference-typography-font-bakeoff/host-coretext-avenir-2026-08-31 \
  --renderer-id host-coretext-forensic
```

The host manifest records the Avenir SHA and renderer id
`host-coretext-forensic`; it is diagnostic evidence only and is never labeled an
iOS Flutter render. If this forensic lane clearly wins an affected numeric role,
stop on the legal gate in Step 6. Only after the exact face is lawfully acquired,
registered, and bundled may it be rerendered and selected on the primary iOS
Flutter lane.

- [ ] **Step 4: Score and review candidates before writing winner tests**

For JPEG reference runs, compare whole-run support, annotated landmarks,
baseline proxy, run extent, JPEG-aware IoU/residual, and density. Do not infer
exact glyph topology or shaping advances from JPEG pixels. For `image.png` and
controlled specimens, additionally score per-glyph topology, advances, centroid,
coverage, and stroke.

Run:

```bash
dart run tool/compare_reference_font_specimens.dart \
  --renderer ios \
  --candidate-dir ../artifacts/reference-typography-font-bakeoff/ios-candidates-2026-08-31 \
  --output-dir ../artifacts/reference-typography-font-bakeoff/ios-review-2026-08-31
dart run tool/compare_reference_font_specimens.dart \
  --renderer host-coretext-forensic \
  --diagnostic-only \
  --candidate-dir ../artifacts/reference-typography-font-bakeoff/host-coretext-avenir-2026-08-31 \
  --output-dir ../artifacts/reference-typography-font-bakeoff/host-review-2026-08-31
```

Review every overlay. The scorer emits proposed winners and measurements but
does not mutate the role manifest or production code.

- [ ] **Step 5: Write RED winner, legality, coverage, and color-lock tests**

Declare every static region's exact fixture string and role. The completeness
set is:

```dart
final staticNames = <String>{
  for (final referenceCase in tabReferenceCases)
    for (final region in referenceCase.staticTextRegions)
      if (region.auditMode == StaticTextAuditMode.static)
        '${referenceCase.id}:${region.name}',
};
```

Tests require exactly one reviewed face SHA per role, that SHA in the canonical
font lock, `redistributable == true`, and all role strings present in its `cmap`.

Create a color-lock record for every semantic color role with `colorRoleId`,
reference SHA, region IDs, physical sample coordinates, decoded background RGB,
compositing method, all sample RGB values, consensus RGB/opacity, uncertainty,
and source class (`jpegDiagnostic` or `losslessUnprovenanced`). Every static
region records its typography-metric role, color role, and explicit variant id. A test recomputes
the consensus from source pixels and rejects a color token without such evidence.

Run:

```bash
flutter test test/reference_font_specimen_test.dart
```

Expected: FAIL until reviewed winner and color records are written.

- [ ] **Step 6: Resolve the legal decision gate and lock reviewed results**

If the forensic Avenir face wins any in-scope numeric role, execution has two
explicit branches:

- **Exact branch:** obtain a redistributable exact face, add its license/source
  and full font-lock record; add the exact font asset and license evidence;
  register `Mt5ReferenceNumeric` at its real weight in `pubspec.yaml`; update
  `pubspec.lock`, `loadReferenceFonts()`, and the lock tests; rerun Task 1's font
  gate and the iOS specimens; then continue to Task 3.
- **Blocked branch:** stop this implementation plan and report the exact affected
  role ids. Do not continue dependent screen migrations or claim completion.

A substitute requires a separate user-approved scope and cannot satisfy the
current exact-font objective.

The current-repository faces rendered as controls are not selectable merely
because they score well. If a nonbaseline control beats both locked Roboto
families for a nonnumeric role, stop and extend the provenance/license/lock
design explicitly before selection; do not bypass the required-base/approved-
numeric-only extra-entry contract in Task 1.

Write lawful reviewed winners, color records, scores, reference region ids, and
artifact hashes. Then run focused tests and the complete common gate:

```bash
flutter test test/reference_font_lock_test.dart \
  test/reference_font_specimen_render_test.dart \
  test/reference_font_specimen_test.dart \
  test/tab_typography_candidate_export_test.dart \
  test/tab_reference_manifest_test.dart
dart format --output=none --set-exit-if-changed test tool integration_test test_driver
git diff --check -- test tool integration_test test_driver \
  ../docs/screens ../docs/screenshots/reference-typography-font-bakeoff
```

Expected on the exact branch: every role has one lawful, primary-renderer winner
and one source-hashed color decision; current candidates can be exported without
touching existing goldens.

---

## Task 3: Split JPEG, Lossless-Source, and Raw-Pixel Result Modes

**Files:**

- Create: `docs/screens/reference-typography-capture-protocol.md`
- Create: `docs/screens/reference-typography-capture-manifest.schema.json`
- Create: `docs/screens/reference-typography-capture-manifest.json`
- Modify: `mobile/tool/compare_tab_typography.dart`
- Modify: `mobile/test/tab_typography_comparator_test.dart`
- Modify: `mobile/test/test_support/tab_reference_manifest.dart`

- [ ] **Step 1: Write failing comparator-mode tests**

Add eight named tests using the existing 64 x 64 synthetic-image helpers:

- `certify-lossless rejects jpeg references before writing evidence`: encode the
  reference with `image.encodeJpg`, request certification, expect exit 2 and no
  output directory.
- `certify-lossless requires capture and font-lock metadata`: use identical PNGs
  but omit each required manifest/hash in turn; expect preflight failure.
- `identical lossless glyphs pass with zero unmasked residual`: draw the same
  three-component black glyph fixture into both opaque PNGs; expect PASS,
  `certified: true`, and zero residual.
- `one-pixel baseline and half-pixel advance limits are enforced`: prove a
  one-pixel baseline move passes, a two-pixel move fails, a half-pixel recorded
  advance delta passes, and a larger delta fails.
- `shape IoU, centroid, coverage, stroke, and core RGB limits are enforced`:
  independently mutate each metric across its Tier C boundary and expect FAIL.
- `diagnostic-jpeg can report but never certify`: use identical JPEG-decoded
  inputs, expect measured PASS rows but `certified: false`.
- `diagnostic-lossless accepts an unprovenanced png but never certifies`: use
  identical PNGs without capture provenance, expect strict measurements,
  `typographyEquivalent: true`, and `certified: false`.
- `case selection accepts repeated unique ids and rejects unknown ids`: select
  two synthetic cases, assert both and only both are emitted, then pass an
  unknown id and expect usage failure.
- `evidence summary hashes match its actual inputs and rows`: recompute every
  emitted SHA and PASS/FAIL/SKIP count from disk and compare with `summary.json`.

- [ ] **Step 2: Run RED**

```bash
flutter test test/tab_typography_comparator_test.dart
```

Expected: new mode and glyph-metric tests fail; the existing stale evidence
snapshot failures remain visible.

- [ ] **Step 3: Implement the two explicit modes**

The CLI becomes:

```text
--mode diagnostic-jpeg|diagnostic-lossless|certify-lossless
--reference-manifest <json>
--candidate-manifest <json>
--candidate-renderer deterministic|android|ios
--candidate-dir <directory>
--output-dir <directory>
--case <case-id>  # repeatable; omitted means all cases
```

`diagnostic-jpeg` keeps current typed masks and Tier B thresholds but writes
`certified: false` unconditionally. `diagnostic-lossless` applies Tier C shape
and color measurements to an unprovenanced PNG but also writes
`certified: false`. `certify-lossless` rejects JPEG, missing reference or
candidate provenance, wrong dimensions/DPR/text scale/locale, hash mismatches,
and any mask growth before pixel comparison.

Both modes emit:

- `summary.json` and the existing 22-column compatibility CSV;
- `glyph-details.json` for baseline, advances, IoU, centroid, coverage, stroke,
  and core/edge RGB metrics that do not fit the compatibility CSV;
- overlays, heatmaps, and per-glyph binary masks;
- font-lock and capture-manifest copies;
- input/output SHA-256 lists;
- command line, Flutter/Dart/engine/OS/device versions;
- explicit PASS/FAIL/SKIP counts, `typographyEquivalent`, `certified`, and
  `rawPixelIdentical` status.

`typographyEquivalent` may pass with Tier C tolerances. `rawPixelIdentical` is
true only when provenance proves the same locked renderer/capture path and the
unmasked differing-pixel count is zero.

- [ ] **Step 4: Replace stale count snapshots with self-consistency checks**

Keep synthetic mutation tests strict. For canonical evidence, assert source
hashes, row topology, reason codes, and internally consistent summary counts
instead of pinning a historical dirty-candidate result. Documentation may quote
counts only when its recorded candidate hashes match current output.

- [ ] **Step 5: Add the capture schema and current diagnostic manifest**

Require package/app version, git revision plus dirty flag, device model/id,
platform/OS build, renderer/engine, orientation, logical/physical size, DPR,
font scale, locale, timezone, state/fixture, capture API/command, image SHA, font
lock SHA, typed masks, and—on candidate manifests—a sorted scoped source-file
list plus its deterministic SHA-256. Mark all seven canonical JPEGs
`certificationEligible: false`. `image.png` is a strict lossless diagnostic
source for compatible Settings regions, but stays ineligible because its
device/renderer capture provenance is unknown.

The comparator must apply repeated `--case` filtering before it preflights image
presence, dimensions, hashes, and manifests; selected-case runs must not depend
on unselected candidates.

- [ ] **Step 6: Run GREEN and the task gate**

```bash
flutter test test/tab_typography_comparator_test.dart \
  test/tab_reference_manifest_test.dart
flutter analyze
flutter build apk --debug
git diff --check -- tool test ../docs/screens
```

Expected: comparator contract tests pass and stale documentation can no longer
masquerade as evidence for different candidate hashes.

---

## Task 4: Replace Global Width Inheritance with Explicit Semantic Roles

**Files:**

- Create: `mobile/lib/core/theme/reference_typography_profile.dart`
- Create: `mobile/test/reference_typography_role_coverage_test.dart`
- Modify: `mobile/lib/core/theme/app_typography.dart`
- Modify: `mobile/lib/core/theme/app_theme.dart`
- Modify: `mobile/lib/shared/widgets/app_shell.dart`
- Modify: `mobile/test/test_support/reference_typography_role_manifest.dart`
- Modify: `mobile/test/tab_typography_tokens_test.dart`

- [ ] **Step 1: Add the opt-in reference-profile contracts**

Keep the legacy-width test temporarily so the user's current default remains
reproducible, and add:

```dart
test('reference roles use only locked static faces', () {
  for (final entry in AppTypography.referenceTokens.entries) {
    final token = entry.value;
    expect(
      token.style.fontFamily,
      anyOf('Mt5ReferenceRoboto', 'Mt5ReferenceRobotoCondensed',
            'Mt5ReferenceNumeric'),
      reason: entry.key.name,
    );
    expect(token.style.fontVariations ?? const <FontVariation>[], isEmpty);
    expect(token.style.color, isNull, reason: entry.key.name);
    expect(referenceFontLock.supports(token.faceSha256, token.style.fontWeight),
           isTrue, reason: entry.key.name);
  }
});

test('every semantic color role is source locked', () {
  expect(
    ReferenceTextColorRole.values.toSet(),
    ReferenceTextColors.reference.keys.toSet(),
  );
  for (final entry in ReferenceTextColors.reference.entries) {
    expect(referenceColorLock.hasEvidenceFor(entry.key), isTrue);
  }
});

testWidgets('reference tab scope injects no family or width axis', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: withTypographyProfile(ThemeData(), TypographyProfile.reference),
      home: const MtTabTextScope(child: Text('probe')),
    ),
  );
  final style = tester.widget<DefaultTextStyle>(
    find.byType(DefaultTextStyle).last,
  ).style;
  expect(style.fontFamily, isNull);
  expect(style.fontVariations ?? const <FontVariation>[], isEmpty);
});

test('iOS and Android use the same semantic token map', () {
  expect(AppTypography.referenceTokensFor(TargetPlatform.iOS),
         AppTypography.referenceTokensFor(TargetPlatform.android));
  expect(AppTypography.referenceVariantOverridesFor(TargetPlatform.iOS),
         AppTypography.referenceVariantOverridesFor(TargetPlatform.android));
  expect(ReferenceTextColors.referenceFor(TargetPlatform.iOS),
         ReferenceTextColors.referenceFor(TargetPlatform.android));
});

test('legacy profile reproduces every captured callsite variant', () {
  for (final callsite in legacyTypographyCallsiteManifest) {
    final resolved = resolveLegacyTypography(
      role: callsite.metricRole,
      colorRole: callsite.colorRole,
      variant: callsite.variant,
      platform: callsite.platform,
      brightness: callsite.brightness,
    );
    expect(resolved.styleSnapshot, callsite.currentStyleSnapshot,
           reason: callsite.id);
    expect(resolved.geometry, callsite.currentGeometry,
           reason: callsite.id);
    expect(resolved.color, callsite.currentColor,
           reason: callsite.id);
  }
});
```

The font lock is authoritative: a 600 role passes only when the selected file
has `OS/2.usWeightClass == 600`; no loose matcher permits synthetic weight.

- [ ] **Step 2: Run RED**

```bash
flutter test test/tab_typography_tokens_test.dart \
  test/reference_typography_role_coverage_test.dart
```

Expected: FAIL because the profile, role enum/token map, and neutral reference
scope do not exist. Legacy default tests remain green.

- [ ] **Step 3: Add the explicit role/profile API without deleting legacy APIs**

Create these production interfaces:

```dart
enum TypographyProfile { legacy, reference }

enum ReferenceTextRole {
  navigationLabel,
  settingsToolbarTitle,
  settingsAccountName,
  settingsAccountCompany,
  settingsAccountMeta,
  settingsRowTitle,
  settingsRowSubtitle,
  pricesToolbarTitle,
  quoteChange,
  quoteSymbol,
  quoteMeta,
  quoteTimeMeta,
  quoteRangeLabel,
  quoteRangeValue,
  quotePriceMajor,
  quotePriceMinor,
  chartToolbar,
  chartTimeframe,
  chartTicketLabel,
  chartTicketPriceMajor,
  chartTicketPriceMinor,
  chartAnnotation,
  chartAxis,
  chartTimeAxis,
  tradeHeaderProfit,
  tradeMetricLabel,
  tradeMetricValue,
  tradeSection,
  tradePositionSymbol,
  tradePositionSide,
  tradePositionSecondary,
  tradePositionProfit,
  historySegment,
  historyDealsSegment,
  historyPrimary,
  historyAction,
  historyTrailingPrimary,
  historySecondary,
  historyPriceRange,
  historyBalancePrimary,
  historyBalanceTrailingPrimary,
  historyBalanceSecondary,
  historyTrailingSecondary,
  historySummary,
  historyOrderSummaryTotal,
  historySummaryValue,
}

enum ReferenceTextColorRole {
  primary,
  secondary,
  navigationSelected,
  navigationUnselected,
  blueAction,
  positive,
  negative,
  historyStatus,
  chartToolbar,
  chartPlot,
  white,
}

@immutable
class TypographyVariantId {
  const TypographyVariantId(this.value);
  static const base = TypographyVariantId('base');
  final String value;
}

@immutable
class TypographyStyleKey {
  const TypographyStyleKey(this.role, this.variant);
  final ReferenceTextRole role;
  final TypographyVariantId variant;
}

@immutable
class TypographyColorKey {
  const TypographyColorKey(this.role, this.variant);
  final ReferenceTextColorRole role;
  final TypographyVariantId variant;
}

@immutable
class ReferenceTextToken {
  const ReferenceTextToken({required this.faceSha256, required this.style});
  final String faceSha256;
  // Metrics only: color must remain null and is supplied by a color role.
  final TextStyle style;
}

@immutable
class TypographyTextGeometry {
  const TypographyTextGeometry({
    this.scaleX = 1,
    this.scaleY = 1,
    this.dx = 0,
    this.dy = 0,
  });
  final double scaleX;
  final double scaleY;
  final double dx;
  final double dy;
}
```

`ReferenceTypographyProfile` is a `ThemeExtension`; its app default remains
`legacy` through Task 11, while candidate fixtures explicitly request
`reference`. `AppTypography.referenceTokens` is a complete const map from every
enum value above to the reviewed Task 2 token/face SHA.
`AppTypography.referenceTokensFor(TargetPlatform)` returns that same map for iOS
and Android; it exists so tests can reject later platform-specific metric drift.

Before refactoring any callsite, create a typed
`legacyTypographyCallsiteManifest` that snapshots every current combination of
metric role, color role, variant id, platform, brightness, resolved style, color,
and text geometry. Variants are explicit and stable, including every navigation
kind/selection combination, XAU/BTC/other quote paths, History segment/state,
and any other current branch discovered by source coverage. A `base` variant is
used only where no branch exists.

`AppTypography.legacyTokens` is keyed by `TypographyStyleKey` and preserves every
current family, width/weight, size, spacing, and platform adjustment, with color
removed before composition. `ReferenceTextColors.legacy` is keyed by
`TypographyColorKey` and separately preserves every current
state/theme/platform color. A parallel complete `legacyGeometry` map uses the
same style keys for current text-only scale/offset wrappers. Resolver methods
also receive platform and brightness. These compatibility maps are mandatory so
the legacy common suite remains byte-for-byte reproducible while screens are
migrated; no missing variant may fall back to a base/reference value.

The reference profile keeps one base token per semantic metric role plus an
explicit `referenceVariantOverrides` map. An override is allowed only when the
reference role manifest proves a real metric distinction; otherwise all legacy
variants normalize to the reviewed base reference token. Reference color
variant overrides follow the same evidence rule. Reference base and override
maps remain identical on iOS and Android.

Typography metrics and semantic color are separate axes. Each static manifest
region maps to one `ReferenceTextRole`, one `ReferenceTextColorRole`, and one
`TypographyVariantId`.
`ReferenceTextColors.reference` is backed by `AppColors` and the source-hashed
color lock. `AppTypography.forRole(context, role, colorRole: colorRole,
variant: variant)` combines the metrics-only token with the selected theme-aware color. This permits one
`navigationLabel` metric role to render selected/unselected states and one
numeric role to render positive/negative states without duplicating font
metrics. The reference color maps are platform-independent; a light/dark theme
variant is allowed only when the corresponding source record proves it.

The existing canonical golden harness reads
`bool.fromEnvironment('REFERENCE_TYPOGRAPHY', defaultValue: false)` during the
migration. Focused commands pass `--dart-define=REFERENCE_TYPOGRAPHY=true`; the
complete common suite remains on the reproducible legacy default until final
promotion in Task 12.

`AppTypography.forRole(context, role, colorRole: ..., variant: ...)` selects the
new metric/color maps only under the reference profile. Under legacy it resolves
the exact composite variant/platform/theme key.
`AppTypography.geometryForRole(context, role, variant: ...)` does the same for
text-only scale/offset behavior. Under the reference profile
`MtTabTextScope` contributes no family, variation, weight, size, or color. Under
legacy it retains current behavior.

Do not delete `tabWidth`, `_width90`, old weight lists, `platformInk`, old role
constants, or variable-family registrations here; Tasks 5-9 still compile
against them. Mark them legacy-only and clean them only after final source search.

- [ ] **Step 4: Define every canonical role from the reviewed role manifest**

For every metric enum value, copy the selected face SHA, real weight, size,
height, tracking, and features from Task 2's role lock. Populate every color enum
from Task 2's independently source-hashed color lock. Do not tune position or
`Transform.scale` in this task. First snapshot every current callsite branch and
encode every current transform/offset in its composite legacy variant key so
later reference-only removals cannot break the full legacy suite.

- [ ] **Step 5: Prove role coverage**

At this stage every metric enum has exactly one token, every color enum has at
least one source-evidence record, and every static manifest region has exactly
one `(metricRole, colorRole, variantId)` tuple. Role reuse across regions and color states is
intentional, so the region mapping is complete but not falsely required to be a
bijection. Tasks 5-9 add callsite coverage: each migrated `Text`, `TextSpan`, and
painter run must call `AppTypography.forRole` with both manifest role ids and
the explicit callsite variant.
Dynamic roles use deterministic replacement strings and select positive,
negative, selected, or unselected colors from state.

- [ ] **Step 6: Run GREEN and the task gate**

```bash
flutter test test/reference_font_lock_test.dart \
  test/tab_typography_tokens_test.dart \
  test/reference_typography_role_coverage_test.dart
flutter analyze
flutter build apk --debug
git diff --check -- lib/core/theme lib/shared/widgets/app_shell.dart test
```

Expected: the opt-in reference profile is deterministic and the legacy default
keeps the complete baseline suite reproducible. No legacy API is deleted.

---

## Task 5: Migrate Shared Navigation and Settings First

Tasks 5-10 use deterministic host exports as fast RED/GREEN development gates.
They may approve a screen for the next migration task, but they are not the
primary renderer acceptance artifact and cannot promote the default profile.
Final app acceptance requires the complete iOS matrix in Tasks 11 and 12.

**Files:**

- Modify: `mobile/lib/shared/widgets/app_shell.dart`
- Modify: `mobile/lib/features/profile/presentation/screens/settings_screen.dart`
- Modify: `mobile/lib/core/theme/settings_reference_metrics.dart`
- Modify: `mobile/test/bottom_navigation_icon_parity_test.dart`
- Modify: `mobile/test/settings_navigation_video_test.dart`
- Modify: `mobile/test/tab_typography_golden_test.dart`
- Modify: `mobile/test/test_support/tab_reference_manifest.dart`

**Role ids / candidates:**

- `navigationLabel`, `settingsToolbarTitle`, `settingsAccountName`,
  `settingsAccountCompany`, `settingsAccountMeta`, `settingsRowTitle`, and
  `settingsRowSubtitle`.
- `settings-primary-590x1280.png` and `settings-secondary-590x1280.png`.
- Exact source/candidate rectangles are the named Settings/nav entries added to
  `tab_reference_manifest.dart`; their source SHA and color sample coordinates
  are required in the role/color locks before the test compiles.

- [ ] **Step 1: Add failing role and pixel-bound assertions**

Use `image.png` as the primary lossless Settings typography reference. Add static
regions for toolbar/account/row titles/subtitles and all five navigation labels.
The second Settings JPEG verifies only shared strings present in the same state.

Assert family/weight/size/tracking/color plus physical glyph bounds, baselines,
advances, and component topology. Keep status-bar text excluded as OS-owned.

- [ ] **Step 2: Run RED**

```bash
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  test/bottom_navigation_icon_parity_test.dart \
  test/settings_navigation_video_test.dart
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  --plain-name settings test/tab_typography_golden_test.dart
```

Expected: Settings/nav typography assertions fail under current variable-family
and transform behavior. Unrelated icon and navigation behavior assertions remain
green.

- [ ] **Step 3: Migrate semantic roles without touching Settings content**

- Apply exact Roboto regular/bold role winners to toolbar, account, rows, and nav.
- Route every migrated run through `AppTypography.forRole(context, role,
  colorRole: colorRole, variant: variant)`; navigation passes its exact kind and
  selection variant. No Settings/nav run may read a legacy role or color
  constant under the reference profile.
- Switch text-only vertical scaling and label-specific synthetic nav
  weight/width tuning to identity only in `referenceGeometry`/reference tokens
  after the exact role renders; preserve their legacy-map values.
- Calibrate font size, real weight, tracking, line height, color, then baseline.
- Preserve Settings artwork, routes, account state, fade behavior, icons, and
  bottom-navigation hit targets from the dirty worktree.

- [ ] **Step 4: Compare only Settings/nav evidence**

```bash
SETTINGS_CANDIDATE_DIR="$(mktemp -d)"
flutter test \
  --dart-define=REFERENCE_TYPOGRAPHY=true \
  --dart-define=TAB_REFERENCE_CASE=settings-primary \
  --dart-define=TAB_CANDIDATE_DIR="$SETTINGS_CANDIDATE_DIR" \
  test/tab_typography_candidate_export_test.dart
dart run tool/compare_tab_typography.dart \
  --mode diagnostic-lossless \
  --reference-manifest ../docs/screens/reference-typography-capture-manifest.json \
  --candidate-manifest "$SETTINGS_CANDIDATE_DIR/manifest.json" \
  --candidate-dir "$SETTINGS_CANDIDATE_DIR" \
  --case settings-primary \
  --output-dir ../artifacts/reference-typography/settings
SETTINGS_SECONDARY_DIR="$(mktemp -d)"
flutter test \
  --dart-define=REFERENCE_TYPOGRAPHY=true \
  --dart-define=TAB_REFERENCE_CASE=settings-secondary \
  --dart-define=TAB_CANDIDATE_DIR="$SETTINGS_SECONDARY_DIR" \
  test/tab_typography_candidate_export_test.dart
dart run tool/compare_tab_typography.dart \
  --mode diagnostic-jpeg \
  --reference-manifest ../docs/screens/reference-typography-capture-manifest.json \
  --candidate-manifest "$SETTINGS_SECONDARY_DIR/manifest.json" \
  --candidate-dir "$SETTINGS_SECONDARY_DIR" \
  --case settings-secondary \
  --output-dir ../artifacts/reference-typography/settings-secondary
```

This is strict lossless-source diagnostic evidence, not certification, because
`image.png` lacks capture provenance. The secondary JPEG run audits only shared
roles whose content/state agrees.

- [ ] **Step 5: Run GREEN and the task gate**

```bash
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  test/bottom_navigation_icon_parity_test.dart \
  test/settings_navigation_video_test.dart
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  --plain-name settings test/tab_typography_golden_test.dart
flutter analyze
flutter build apk --debug
git diff --check -- lib/shared/widgets/app_shell.dart \
  lib/features/profile test
```

Retain the approved current-render candidate and its manifest under artifacts.
Do not update any app golden here; promotion happens atomically in Task 12 after
all screens and the default profile are ready.

---

## Task 6: Migrate Prices Typography

**Files:**

- Modify: `mobile/lib/features/market_watch/presentation/screens/market_watch_screen.dart`
- Modify: `mobile/lib/core/theme/tab_reference_metrics.dart`
- Modify: `mobile/test/market_watch_parity_test.dart`
- Modify: `mobile/test/tab_typography_golden_test.dart`
- Modify: `mobile/test/test_support/tab_reference_manifest.dart`

**Role ids / candidate:** `pricesToolbarTitle`, `quoteChange`, `quoteSymbol`,
`quoteMeta`, `quoteTimeMeta`, `quoteRangeLabel`, `quoteRangeValue`,
`quotePriceMajor`, and `quotePriceMinor`; candidate
`prices-590x1280.png`. Exact rectangles remain the existing named Prices static
regions in `tab_reference_manifest.dart`.

- [ ] **Step 1: Add failing Prices role and glyph assertions**

Cover toolbar title, change values, symbols, timestamps, spread, `L:`/`H:`
labels, range values, and split Bid/Ask runs. Protect the four static `L:`/`H:`
labels while keeping only live numeric values dynamically masked.

- [ ] **Step 2: Run RED**

```bash
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  test/market_watch_parity_test.dart
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  --plain-name prices test/tab_typography_golden_test.dart
```

Expected: role family/weight and static glyph evidence fail.

- [ ] **Step 3: Apply reviewed face mapping in dependency order**

1. Symbols and metadata: exact Roboto Condensed regular/bold winners.
2. Toolbar: exact Roboto winner.
3. Split prices: the lawful exact-branch numeric winner from Task 2.
4. Set size/height, then tracking/tabular feature, then color.
5. Make quote text `scaleY`/offset compensation identity only under the reference
   profile after the exact face is active; preserve its legacy geometry and all
   corner glyphs, rows, live data, gestures, and hit targets.
6. Route every covered text/span through `AppTypography.forRole` with its metric
   role, state-derived color role, and explicit XAU/BTC/other variant; add a
   source coverage assertion that no covered Prices callsite uses a legacy role
   or color directly.

- [ ] **Step 4: Run focused diagnostic comparison**

```bash
PRICES_CANDIDATE_DIR="$(mktemp -d)"
flutter test \
  --dart-define=REFERENCE_TYPOGRAPHY=true \
  --dart-define=TAB_REFERENCE_CASE=prices \
  --dart-define=TAB_CANDIDATE_DIR="$PRICES_CANDIDATE_DIR" \
  test/tab_typography_candidate_export_test.dart
dart run tool/compare_tab_typography.dart \
  --mode diagnostic-jpeg \
  --reference-manifest ../docs/screens/reference-typography-capture-manifest.json \
  --candidate-manifest "$PRICES_CANDIDATE_DIR/manifest.json" \
  --candidate-dir "$PRICES_CANDIDATE_DIR" \
  --case prices \
  --output-dir ../artifacts/reference-typography/prices
```

Accept Prices only when all stable typography rows meet Tier B and masks have
not changed.

- [ ] **Step 5: Run GREEN and the task gate**

```bash
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  test/market_watch_parity_test.dart \
  test/tab_typography_tokens_test.dart
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  --plain-name prices test/tab_typography_golden_test.dart
flutter analyze
flutter build apk --debug
git diff --check -- lib/features/market_watch lib/core/theme test
```

Retain the approved current-render candidate/manifest under artifacts; do not
promote the golden until Task 12.

---

## Task 7: Migrate Chart Widget and Painter Typography

**Files:**

- Modify: `mobile/lib/features/chart/presentation/screens/chart_screen.dart`
- Modify: `mobile/lib/features/chart/presentation/rendering/mt5_candle_painter.dart`
- Modify: `mobile/lib/features/chart/presentation/theme/chart_reference_theme.dart`
- Modify: `mobile/test/chart_controls_test.dart`
- Modify: `mobile/test/chart_geometry_test.dart`
- Modify: `mobile/test/chart_light_theme_test.dart`
- Modify: `mobile/test/tab_typography_golden_test.dart`
- Modify: `mobile/test/test_support/tab_reference_manifest.dart`

**Role ids / candidate:** `chartToolbar`, `chartTimeframe`, `chartTicketLabel`,
`chartTicketPriceMajor`, `chartTicketPriceMinor`, `chartAnnotation`, `chartAxis`,
and `chartTimeAxis`; candidate `chart-590x1280.png`. Both widget text and
`mt5_candle_painter.dart` must obtain styles from the same role map.

- [ ] **Step 1: Add failing widget and painter role assertions**

Cover toolbar/timeframe, sell/buy labels and prices, symbol/timeframe annotation,
price axis, time axis, and any painter-created text. Assert chart canvas text has
an explicit family and never inherits the tab default.

- [ ] **Step 2: Run RED**

```bash
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  test/chart_controls_test.dart \
  test/chart_geometry_test.dart \
  test/chart_light_theme_test.dart
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  --plain-name chart test/tab_typography_golden_test.dart
```

Expected: text-role assertions fail; candle/viewport/interaction geometry stays
unchanged.

- [ ] **Step 3: Migrate Chart roles**

- Use exact Roboto for canvas axes/annotation if the bake-off confirms the APK
  ChartSurface evidence.
- Use the reviewed condensed/numeric winner for ticket labels/prices.
- Make the current M1 vertical shrink identity only under the reference profile
  after correct face metrics pass; preserve it in `legacyGeometry`.
- Calibrate chart toolbar, plot blue, and axis colors as distinct roles.
- Do not change candle geometry, price projection, viewport, gestures, orders,
  or plot masks.
- Pass the resolved reference profile/token into painter construction; every
  painter `TextPainter` uses the named metric role, color role, and callsite
  variant and never a local legacy style.

- [ ] **Step 4: Run the Chart diagnostic and task gate**

```bash
CHART_CANDIDATE_DIR="$(mktemp -d)"
flutter test \
  --dart-define=REFERENCE_TYPOGRAPHY=true \
  --dart-define=TAB_REFERENCE_CASE=chart \
  --dart-define=TAB_CANDIDATE_DIR="$CHART_CANDIDATE_DIR" \
  test/tab_typography_candidate_export_test.dart
dart run tool/compare_tab_typography.dart \
  --mode diagnostic-jpeg \
  --reference-manifest ../docs/screens/reference-typography-capture-manifest.json \
  --candidate-manifest "$CHART_CANDIDATE_DIR/manifest.json" \
  --candidate-dir "$CHART_CANDIDATE_DIR" \
  --case chart \
  --output-dir ../artifacts/reference-typography/chart
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  test/chart_controls_test.dart \
  test/chart_geometry_test.dart \
  test/chart_light_theme_test.dart
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  --plain-name chart test/tab_typography_golden_test.dart
flutter analyze
flutter build apk --debug
git diff --check -- lib/features/chart test
```

Retain the approved current-render candidate/manifest; promotion waits for
Task 12.

---

## Task 8: Migrate Light Trade Typography

**Files:**

- Modify: `mobile/lib/features/trade/presentation/screens/trade_screen.dart`
- Modify: `mobile/lib/core/theme/tab_reference_metrics.dart`
- Modify: `mobile/test/trade_position_bulk_actions_flow_test.dart`
- Modify: `mobile/test/tab_typography_golden_test.dart`
- Modify: `mobile/test/test_support/tab_reference_manifest.dart`

**Role ids / candidate:** `tradeHeaderProfit`, `tradeMetricLabel`,
`tradeMetricValue`, `tradeSection`, `tradePositionSymbol`, `tradePositionSide`,
`tradePositionSecondary`, and `tradePositionProfit`; candidate
`trade-590x1280.png`.

- [ ] **Step 1: Add failing Trade assertions**

Cover header P/L plus static `USD`, metric labels/values, section label, symbol,
side/volume, entry-to-current range, and row profit. The numeric header and live
row profits remain typed dynamic values, but deterministic specimen strings must
prove their family, size, weight, color, and baseline.

- [ ] **Step 2: Run RED**

```bash
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  test/trade_position_bulk_actions_flow_test.dart
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  --plain-name trade test/tab_typography_golden_test.dart
```

Expected: current heavy/synthetic roles and vertical compensation fail.

- [ ] **Step 3: Apply role winners and remove compensations**

- Metrics use the bake-off winner, expected to be exact plain Roboto regular.
- Symbols/sides/secondary ranges use exact condensed regular/bold winners.
- Header and row profits use the licensed numeric winner approved by Task 2's
  exact branch. Task 8 is unreachable on the blocked branch.
- Make platform-dependent `1.03`/`1.08` metric `scaleY` identity only under the
  reference profile after exact face, size, height, and tracking are set; retain
  both current platform values in `legacyGeometry`.
- Preserve positions, close actions, scrollbar, account metrics, and live state.
- Route each covered text/span through `AppTypography.forRole` with metric role,
  state-derived color role, and explicit callsite variant, and assert no covered
  Trade callsite uses a legacy constant under the reference profile.

- [ ] **Step 4: Run diagnostic and GREEN task gate**

```bash
TRADE_CANDIDATE_DIR="$(mktemp -d)"
flutter test \
  --dart-define=REFERENCE_TYPOGRAPHY=true \
  --dart-define=TAB_REFERENCE_CASE=trade \
  --dart-define=TAB_CANDIDATE_DIR="$TRADE_CANDIDATE_DIR" \
  test/tab_typography_candidate_export_test.dart
dart run tool/compare_tab_typography.dart \
  --mode diagnostic-jpeg \
  --reference-manifest ../docs/screens/reference-typography-capture-manifest.json \
  --candidate-manifest "$TRADE_CANDIDATE_DIR/manifest.json" \
  --candidate-dir "$TRADE_CANDIDATE_DIR" \
  --case trade \
  --output-dir ../artifacts/reference-typography/trade
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  test/trade_position_bulk_actions_flow_test.dart \
  test/tab_typography_tokens_test.dart
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  --plain-name trade test/tab_typography_golden_test.dart
flutter analyze
flutter build apk --debug
git diff --check -- lib/features/trade lib/core/theme test
```

Retain the approved current-render candidate/manifest; promotion waits for
Task 12.

---

## Task 9: Migrate All Four History States Together

**Files:**

- Modify: `mobile/lib/features/history/presentation/screens/history_screen.dart`
- Modify: `mobile/lib/core/theme/app_colors.dart`
- Modify: `mobile/lib/core/theme/tab_reference_metrics.dart`
- Modify: `mobile/test/history_screen_detail_test.dart`
- Modify: `mobile/test/tab_typography_golden_test.dart`
- Modify: `mobile/test/test_support/tab_reference_manifest.dart`

**Role ids / candidates:** `historySegment`, `historyDealsSegment`,
`historyPrimary`, `historyAction`, `historyTrailingPrimary`, `historySecondary`,
`historyPriceRange`, `historyBalancePrimary`, `historyBalanceTrailingPrimary`,
`historyBalanceSecondary`, `historyTrailingSecondary`, `historySummary`,
`historyOrderSummaryTotal`, and `historySummaryValue`; the four existing
`history-*-590x1280.png` case ids.

- [ ] **Step 1: Add failing assertions for the complete History role matrix**

Cover segments, primary symbols, action/status text, trailing primary values,
secondary ranges/timestamps, balance rows, order/deal summaries, total labels,
and summary values across Positions, Orders offset, Orders summary, and Deals.
Do not infer the History status or chart blue from generic app blue; assert each
measured semantic color separately.

- [ ] **Step 2: Run RED**

```bash
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  test/history_screen_detail_test.dart
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  --plain-name history test/tab_typography_golden_test.dart
```

Expected: current 400-650 synthetic weights, secondary density, transforms, and
at least the status-color role fail.

- [ ] **Step 3: Apply the role matrix once, then state-specific metrics**

- Segments/summaries use exact plain Roboto winners.
- Symbols/actions/secondary rows use exact condensed regular/bold winners.
- Trailing large values use the licensed numeric winner where Task 2 proves it.
- Make History text-only vertical transforms identity only under the reference
  profile after face metrics pass; retain current values in `legacyGeometry`.
- Calibrate four selected-pill states independently; do not hide their edges or
  adjacent text with masks.
- Preserve row actions, order/deal details, scrolling, summaries, and fixture data.
- Route each covered text/span through `AppTypography.forRole` with metric role,
  state-derived color role, and explicit segment/state variant; the coverage
  test rejects legacy History role or color access under the reference profile.

- [ ] **Step 4: Compare all four states in one run**

```bash
HISTORY_CANDIDATE_DIR="$(mktemp -d)"
flutter test \
  --dart-define=REFERENCE_TYPOGRAPHY=true \
  --dart-define=TAB_REFERENCE_CASE=history \
  --dart-define=TAB_CANDIDATE_DIR="$HISTORY_CANDIDATE_DIR" \
  test/tab_typography_candidate_export_test.dart
dart run tool/compare_tab_typography.dart \
  --mode diagnostic-jpeg \
  --reference-manifest ../docs/screens/reference-typography-capture-manifest.json \
  --candidate-manifest "$HISTORY_CANDIDATE_DIR/manifest.json" \
  --candidate-dir "$HISTORY_CANDIDATE_DIR" \
  --case history-positions \
  --case history-orders \
  --case history-orders-summary \
  --case history-deals \
  --output-dir ../artifacts/reference-typography/history
```

Do not accept History until all four states meet Tier B; a pass in one segment
must not regress another.

- [ ] **Step 5: Run GREEN and the task gate**

```bash
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  test/history_screen_detail_test.dart \
  test/tab_typography_tokens_test.dart
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  --plain-name history test/tab_typography_golden_test.dart
flutter analyze
flutter build apk --debug
git diff --check -- lib/features/history lib/core/theme test
```

Retain all four approved current-render candidates/manifests; promotion waits
for Task 12.

---

## Task 10: Add the Separate Dark Trade Target and Enforce OS Ownership

**Files:**

- Modify: `mobile/test/test_support/reference_typography_sources.dart`
- Modify: `mobile/test/test_support/tab_reference_manifest.dart`
- Modify: `mobile/test/tab_typography_golden_test.dart`
- Modify: `mobile/test/reference_typography_role_coverage_test.dart`
- Modify production theme/style files only if the dark state exposes a real
  semantic typography difference.

**Role ids / candidate:** reuse all eight light Trade role ids; candidate
`dark-trade-413x881.png`. Only dark semantic color records may differ.

- [ ] **Step 1: Write failing dark-state and system-ownership tests**

Create a 413 x 881 dark Trade fixture that shares font metrics with light Trade
while using measured dark-theme colors. Add a test proving the 336 x 331 partial
system crop cannot become a full-screen golden or an app font-role source.

- [ ] **Step 2: Run RED**

```bash
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  test/tab_reference_manifest_test.dart \
  test/reference_typography_role_coverage_test.dart
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  --plain-name dark-trade test/tab_typography_golden_test.dart
```

- [ ] **Step 3: Implement only true theme/viewport differences**

Reuse the exact light Trade face/size/weight contract. Add dark color tokens only
where the dark reference proves a different semantic color. Never tune light
geometry against the smaller dark image and never draw a fake iOS status bar.

- [ ] **Step 4: Run diagnostic and task gate**

```bash
DARK_TRADE_CANDIDATE_DIR="$(mktemp -d)"
flutter test \
  --dart-define=REFERENCE_TYPOGRAPHY=true \
  --dart-define=TAB_REFERENCE_CASE=dark-trade \
  --dart-define=TAB_CANDIDATE_DIR="$DARK_TRADE_CANDIDATE_DIR" \
  test/tab_typography_candidate_export_test.dart
dart run tool/compare_tab_typography.dart \
  --mode diagnostic-jpeg \
  --reference-manifest ../docs/screens/reference-typography-capture-manifest.json \
  --candidate-manifest "$DARK_TRADE_CANDIDATE_DIR/manifest.json" \
  --candidate-dir "$DARK_TRADE_CANDIDATE_DIR" \
  --case dark-trade \
  --output-dir ../artifacts/reference-typography/dark-trade
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  test/tab_reference_manifest_test.dart \
  test/reference_typography_role_coverage_test.dart
flutter test --dart-define=REFERENCE_TYPOGRAPHY=true \
  --plain-name dark-trade test/tab_typography_golden_test.dart
flutter analyze
flutter build apk --debug
git diff --check
```

Expected: dark Trade passes its own diagnostic without changing the seven light
candidate hashes except where a shared role correction was intended and reviewed.

---

## Task 11: Connect Real-Device Captures to the Comparator

**Files:**

- Modify: `mobile/integration_test/tab_typography_device_test.dart`
- Modify: `mobile/test_driver/tab_typography_device_test.dart`
- Modify: `mobile/tool/compare_tab_typography.dart`
- Create: `mobile/tool/assemble_tab_capture_manifest.dart`
- Create: `mobile/test/primary_renderer_typography_evidence_test.dart`
- Modify: `docs/screens/reference-typography-capture-protocol.md`

- [ ] **Step 1: Write failing capture-contract tests**

Assert that each fixed app-boundary capture is opaque RGBA at its manifest-locked
physical dimensions: the nine light/Settings cases are 590 x 1280 and dark Trade
is 413 x 881 under its separate Task 2 logical/DPR contract. Every output has a
unique case/device id, uses the comparator's manifest mapping, and records all
required metadata and SHA. A separate optional native screenshot retains actual
native dimensions. Reject the current `android-<case>-590x1280.png` versus
canonical manifest naming ambiguity. Add a response-payload test that decodes
one base64 boundary PNG and rejects missing host case/renderer/device/output,
app-versus-host case/renderer mismatch, wrong dimensions, or wrong hash. Add an
assembler test that rejects duplicate or missing ids and accepts exactly the ten
full-screen cases. The evidence test
recomputes the SHA-256 of the declared scoped source-file list and rejects a
capture/report whose `sourceSnapshotSha256`, font-lock SHA, candidate hashes,
case set, renderer, or PASS summaries do not match the current worktree.

- [ ] **Step 2: Run RED**

```bash
flutter test test/tab_typography_comparator_test.dart \
  test/tab_reference_manifest_test.dart
```

- [ ] **Step 3: Parameterize capture output and platform**

Use Dart defines only for app-visible case/renderer inputs. Render the selected
case's keyed logical boundary with `RenderRepaintBoundary.toImage` at that case's
locked capture ratio. The nine 590 x 1280 cases use 393.333333 x 853.333333 at
1.5; dark Trade uses the separate logical/DPR contract locked in Task 2 and must
encode to exactly 413 x 881. Put one PNG payload in `binding.reportData` with
case, renderer, logical/physical size, DPR, text scale, locale, fixture,
font-lock SHA, byte SHA, `Platform.operatingSystem`, and
`Platform.operatingSystemVersion`. Do not resize a native screenshot and do not
ask the sandboxed app to write a host path.

In `test_driver/tab_typography_device_test.dart`, read four required host values:
`TAB_CAPTURE_OUTPUT`, `TAB_CAPTURE_CASE`, `TAB_CAPTURE_RENDERER`, and
`TAB_CAPTURE_DEVICE_ID`. Its `integrationDriver(responseDataCallback: ...)`
decodes the boundary base64, cross-checks app case/renderer against the two host
values, validates opacity/dimensions/hash, and writes the manifest-declared
canonical filename plus one immutable `<case>.capture.json` fragment. One drive
invocation transports one case to keep response size bounded. The app may additionally call
`binding.takeScreenshot('native-<renderer>-<case>')` with no second argument;
`onScreenshot` writes that separately named native-size context image. Flutter
3.44.8 IO asserts that screenshot metadata arguments are null, so metadata must
never be routed through `takeScreenshot`.

The device id is host-authoritative because the app cannot observe Flutter's
`-d` selector. The same `TAB_CAPTURE_DEVICE_ID` value is used in the command's
`-d` argument and resolved by the driver against the exact saved
`flutter devices --machine` record, which supplies device name, target platform,
simulator flag, and SDK. The app reports only its observable operating system
strings, not a fabricated model or device id. The driver rejects a missing host
id, a missing matching device record, or an app operating system inconsistent
with the record's target platform/declared renderer.

`tool/assemble_tab_capture_manifest.dart` verifies the ten fragments have one
git revision, dirty flag, renderer, device, engine, font-lock SHA, fixture
contract, scoped source-file list/hash, and a complete unique case set before it
writes the multi-case candidate manifest. The host driver computes the scoped
source snapshot rather than trusting the app to describe the dirty worktree.
Fail on an existing output manifest rather than overwriting it.

The sorted snapshot list includes `pubspec.yaml`, `pubspec.lock`, every file
under `assets/fonts/mt5-reference/` and `lib/`, the selected integration test and
driver, and every fixture/helper it imports under `test/test_support/`. Its hash
is SHA-256 over repeated UTF-8 `relativePath`, NUL, raw file SHA-256, NUL tuples;
untracked files are included by bytes. The evidence test recomputes this exact
algorithm, so a dirty source edit after capture invalidates the report.

`primary_renderer_typography_evidence_test.dart` reads three explicit host
environment paths: `PRIMARY_IOS_CAPTURE_DIR`, `PRIMARY_IOS_JPEG_REPORT_DIR`, and
`PRIMARY_IOS_SETTINGS_REPORT_DIR`. It hashes the capture manifest and both
comparator summaries, requires the complete 9+1 case partition, zero FAIL rows,
PASS for every non-skipped row, and exactly the authorized typed SKIPs, then
recomputes the scoped source snapshot against the current worktree.

Resolve the existing evidence contradiction explicitly: do not label an Android
engine capture as an iPhone simulator. Keep separate `android` and `ios` renderer
evidence and select one declared platform per report.

- [ ] **Step 4: Capture and compare the complete primary iOS matrix**

Run this block with workdir `mobile/`. Set the device id to the actual locked iOS
target shown by `flutter devices --machine`; the other host values are fixed in
the block:

```bash
flutter devices --machine
: "${MT5_IOS_DEVICE_ID:?Set the exact iOS id from flutter devices --machine}"
export TAB_CAPTURE_OUTPUT="$PWD/../artifacts/reference-typography/ios-device-captures-2026-08-31"
export TAB_CAPTURE_RENDERER=ios
export TAB_CAPTURE_DEVICE_ID="$MT5_IOS_DEVICE_ID"
test ! -e "$TAB_CAPTURE_OUTPUT"
mkdir -p "$TAB_CAPTURE_OUTPUT"
flutter devices --machine > "$TAB_CAPTURE_OUTPUT/flutter-devices.json"
for TAB_CAPTURE_CASE in \
  prices chart trade \
  history-positions history-orders history-orders-summary history-deals \
  settings-primary settings-secondary dark-trade
do
  export TAB_CAPTURE_CASE
  flutter drive \
    --driver=test_driver/tab_typography_device_test.dart \
    --target=integration_test/tab_typography_device_test.dart \
    -d "$TAB_CAPTURE_DEVICE_ID" \
    --dart-define=REFERENCE_TYPOGRAPHY=true \
    --dart-define=TAB_REFERENCE_CASE="$TAB_CAPTURE_CASE" \
    --dart-define=TAB_CAPTURE_RENDERER="$TAB_CAPTURE_RENDERER"
done
dart run tool/assemble_tab_capture_manifest.dart \
  --input-dir "$TAB_CAPTURE_OUTPUT" \
  --renderer "$TAB_CAPTURE_RENDERER" \
  --required-case prices \
  --required-case chart \
  --required-case trade \
  --required-case history-positions \
  --required-case history-orders \
  --required-case history-orders-summary \
  --required-case history-deals \
  --required-case settings-primary \
  --required-case settings-secondary \
  --required-case dark-trade \
  --output "$TAB_CAPTURE_OUTPUT/manifest.json"
dart run tool/compare_tab_typography.dart \
  --mode diagnostic-jpeg \
  --reference-manifest ../docs/screens/reference-typography-capture-manifest.json \
  --candidate-renderer ios \
  --candidate-manifest "$TAB_CAPTURE_OUTPUT/manifest.json" \
  --candidate-dir "$TAB_CAPTURE_OUTPUT" \
  --case prices \
  --case chart \
  --case trade \
  --case history-positions \
  --case history-orders \
  --case history-orders-summary \
  --case history-deals \
  --case settings-secondary \
  --case dark-trade \
  --output-dir ../artifacts/reference-typography/ios-device-jpeg-2026-08-31
dart run tool/compare_tab_typography.dart \
  --mode diagnostic-lossless \
  --reference-manifest ../docs/screens/reference-typography-capture-manifest.json \
  --candidate-renderer ios \
  --candidate-manifest "$TAB_CAPTURE_OUTPUT/manifest.json" \
  --candidate-dir "$TAB_CAPTURE_OUTPUT" \
  --case settings-primary \
  --output-dir ../artifacts/reference-typography/ios-device-settings-2026-08-31
```

Both primary iOS reports must pass before Task 12 may promote the default
profile. Host `flutter test` candidates remain deterministic regression/tuning
evidence, not the primary app acceptance artifact. Android may be captured only
as a second complete matrix using a different output path and renderer id; it
cannot replace the iOS gate.

- [ ] **Step 5: Run GREEN and the task gate**

```bash
PRIMARY_IOS_CAPTURE_DIR="$PWD/../artifacts/reference-typography/ios-device-captures-2026-08-31" \
PRIMARY_IOS_JPEG_REPORT_DIR="$PWD/../artifacts/reference-typography/ios-device-jpeg-2026-08-31" \
PRIMARY_IOS_SETTINGS_REPORT_DIR="$PWD/../artifacts/reference-typography/ios-device-settings-2026-08-31" \
flutter test test/primary_renderer_typography_evidence_test.dart \
  test/tab_typography_comparator_test.dart \
  test/tab_reference_manifest_test.dart
flutter analyze
flutter build apk --debug
git diff --check -- integration_test test_driver tool test ../docs/screens
```

Expected: real-device outputs enter the same auditable pipeline as deterministic
goldens; platform provenance is unambiguous.

---

## Task 12: Produce Current Evidence and Run Final Verification

**Files:**

- Modify: `mobile/lib/core/theme/reference_typography_profile.dart`
- Modify: `mobile/lib/core/theme/app_theme.dart`
- Modify: `mobile/test/tab_typography_golden_test.dart`
- Modify: `docs/screens/reference-parity-manifest.md`
- Modify: `docs/screenshots/tab-typography-parity/README.md`
- Modify: existing seven goldens only when every corresponding focused gate is
  already green and its overlay has been reviewed.

- [ ] **Step 1: Re-export all current renders, re-compare, then promote the profile**

First prove every in-scope callsite uses the new API under the reference profile:

```bash
rg -n 'tabWidth|_width90|platformInk|Mt5RobotoVariable|Mt5RobotoCondensedVariable' \
  lib/shared/widgets/app_shell.dart \
  lib/features/profile/presentation/screens/settings_screen.dart \
  lib/features/market_watch/presentation/screens/market_watch_screen.dart \
  lib/features/chart/presentation/screens/chart_screen.dart \
  lib/features/chart/presentation/rendering/mt5_candle_painter.dart \
  lib/features/trade/presentation/screens/trade_screen.dart \
  lib/features/history/presentation/screens/history_screen.dart
```

Expected: no canonical reference-profile callsite match. Legacy definitions may
remain only for demonstrably out-of-scope screens or the temporary legacy branch.

Re-render current source rather than trusting per-task artifacts:

```bash
test ! -e ../artifacts/reference-typography/prepromotion-candidates-2026-08-31
mkdir -p ../artifacts/reference-typography/prepromotion-candidates-2026-08-31
flutter test \
  --dart-define=REFERENCE_TYPOGRAPHY=true \
  --dart-define=TAB_REFERENCE_CASE=all \
  --dart-define=TAB_CANDIDATE_DIR=../artifacts/reference-typography/prepromotion-candidates-2026-08-31 \
  test/tab_typography_candidate_export_test.dart
dart run tool/compare_tab_typography.dart \
  --mode diagnostic-jpeg \
  --reference-manifest ../docs/screens/reference-typography-capture-manifest.json \
  --candidate-manifest ../artifacts/reference-typography/prepromotion-candidates-2026-08-31/manifest.json \
  --candidate-dir ../artifacts/reference-typography/prepromotion-candidates-2026-08-31 \
  --case prices \
  --case chart \
  --case trade \
  --case history-positions \
  --case history-orders \
  --case history-orders-summary \
  --case history-deals \
  --output-dir ../artifacts/reference-typography/final-review-jpeg
dart run tool/compare_tab_typography.dart \
  --mode diagnostic-lossless \
  --reference-manifest ../docs/screens/reference-typography-capture-manifest.json \
  --candidate-manifest ../artifacts/reference-typography/prepromotion-candidates-2026-08-31/manifest.json \
  --candidate-dir ../artifacts/reference-typography/prepromotion-candidates-2026-08-31 \
  --case settings-primary \
  --output-dir ../artifacts/reference-typography/final-review-settings
dart run tool/compare_tab_typography.dart \
  --mode diagnostic-jpeg \
  --reference-manifest ../docs/screens/reference-typography-capture-manifest.json \
  --candidate-manifest ../artifacts/reference-typography/prepromotion-candidates-2026-08-31/manifest.json \
  --candidate-dir ../artifacts/reference-typography/prepromotion-candidates-2026-08-31 \
  --case settings-secondary \
  --case dark-trade \
  --output-dir ../artifacts/reference-typography/final-review-secondary-dark
PRIMARY_IOS_CAPTURE_DIR="$PWD/../artifacts/reference-typography/ios-device-captures-2026-08-31" \
PRIMARY_IOS_JPEG_REPORT_DIR="$PWD/../artifacts/reference-typography/ios-device-jpeg-2026-08-31" \
PRIMARY_IOS_SETTINGS_REPORT_DIR="$PWD/../artifacts/reference-typography/ios-device-settings-2026-08-31" \
flutter test test/primary_renderer_typography_evidence_test.dart
```

Only after all host diagnostics pass and the current-source Task 11 primary iOS
matrix test passes may the app and golden-harness default profile change from
`legacy` to `reference`. Keep an explicit legacy override only if a tested
rollback path is required.

- [ ] **Step 2: Promote reviewed candidates to goldens one case at a time**

After changing the default, export the final current source again without the
opt-in define. This final manifest, not the pre-promotion one, is the hash source
for golden promotion and host regression evidence:

```bash
test ! -e ../artifacts/reference-typography/final-candidates-2026-08-31
mkdir -p ../artifacts/reference-typography/final-candidates-2026-08-31
flutter test \
  --dart-define=TAB_REFERENCE_CASE=all \
  --dart-define=TAB_CANDIDATE_DIR=../artifacts/reference-typography/final-candidates-2026-08-31 \
  test/tab_typography_candidate_export_test.dart
```

```bash
flutter test --update-goldens --plain-name prices \
  test/tab_typography_golden_test.dart
flutter test --update-goldens --plain-name chart \
  test/tab_typography_golden_test.dart
flutter test --update-goldens --plain-name trade \
  test/tab_typography_golden_test.dart
flutter test --update-goldens --plain-name history \
  test/tab_typography_golden_test.dart
flutter test --update-goldens --plain-name settings \
  test/tab_typography_golden_test.dart
flutter test --update-goldens --plain-name dark-trade \
  test/tab_typography_golden_test.dart
```

Before and after each command, confirm only the named case files changed. Do not
run an unfiltered full-suite golden update. A test recomputes the promoted golden
hashes and requires them to equal the corresponding reviewed files in
`../artifacts/reference-typography/final-candidates-2026-08-31`:

```bash
flutter test \
  --dart-define=REVIEWED_CANDIDATE_DIR=../artifacts/reference-typography/final-candidates-2026-08-31 \
  --plain-name 'promoted golden hashes equal reviewed candidates' \
  test/tab_typography_golden_test.dart
```

- [ ] **Step 3: Generate final evidence and keep certification conditional**

First rerun the complete ten-case iOS loop and both comparator commands from
Task 11 Step 4 after the default profile has changed. In that exact block:

- set `TAB_CAPTURE_OUTPUT` to
  `$PWD/../artifacts/reference-typography/final-ios-device-captures-2026-08-31`;
- retain the nonempty `MT5_IOS_DEVICE_ID` assertion and save a fresh matching
  `flutter devices --machine` record inside that new capture directory;
- omit `--dart-define=REFERENCE_TYPOGRAPHY=true` so the run proves the shipped
  default rather than an opt-in path;
- write comparator reports to
  `../artifacts/reference-typography/final-ios-device-jpeg-2026-08-31` and
  `../artifacts/reference-typography/final-ios-device-settings-2026-08-31`.

All ten `flutter drive` invocations, manifest assembly, nine JPEG-source cases,
and the Settings lossless-source case are mandatory. Then prove those reports
and their scoped source snapshot are current:

```bash
PRIMARY_IOS_CAPTURE_DIR="$PWD/../artifacts/reference-typography/final-ios-device-captures-2026-08-31" \
PRIMARY_IOS_JPEG_REPORT_DIR="$PWD/../artifacts/reference-typography/final-ios-device-jpeg-2026-08-31" \
PRIMARY_IOS_SETTINGS_REPORT_DIR="$PWD/../artifacts/reference-typography/final-ios-device-settings-2026-08-31" \
flutter test test/primary_renderer_typography_evidence_test.dart
```

The deterministic host candidate is retained for golden/reproducibility checks,
but the final app acceptance claim is sourced from the complete iOS matrix above:

```bash
dart run tool/compare_tab_typography.dart \
  --mode diagnostic-jpeg \
  --reference-manifest ../docs/screens/reference-typography-capture-manifest.json \
  --candidate-manifest ../artifacts/reference-typography/final-candidates-2026-08-31/manifest.json \
  --candidate-dir ../artifacts/reference-typography/final-candidates-2026-08-31 \
  --case prices \
  --case chart \
  --case trade \
  --case history-positions \
  --case history-orders \
  --case history-orders-summary \
  --case history-deals \
  --output-dir ../artifacts/reference-typography/final-evidence-jpeg
dart run tool/compare_tab_typography.dart \
  --mode diagnostic-lossless \
  --reference-manifest ../docs/screens/reference-typography-capture-manifest.json \
  --candidate-manifest ../artifacts/reference-typography/final-candidates-2026-08-31/manifest.json \
  --candidate-dir ../artifacts/reference-typography/final-candidates-2026-08-31 \
  --case settings-primary \
  --output-dir ../artifacts/reference-typography/final-evidence-lossless
dart run tool/compare_tab_typography.dart \
  --mode diagnostic-jpeg \
  --reference-manifest ../docs/screens/reference-typography-capture-manifest.json \
  --candidate-manifest ../artifacts/reference-typography/final-candidates-2026-08-31/manifest.json \
  --candidate-dir ../artifacts/reference-typography/final-candidates-2026-08-31 \
  --case settings-secondary \
  --case dark-trade \
  --output-dir ../artifacts/reference-typography/final-evidence-secondary-dark
```

All current-source reference comparisons remain diagnostic because the supplied
references lack capture provenance. Run `certify-lossless` only when both
reference and candidate manifests contain verified capture provenance. A Tier C
tolerance pass reports lossless-source typography equivalence. Report raw-pixel
identity only when the separate zero-unmasked-difference field is true under the
same locked renderer.

- [ ] **Step 4: Update documentation from generated hashes and summary JSON**

Record exact primary iOS candidate/reference/font-lock/capture-manifest/source-
snapshot hashes, command/tool versions, per-case counts, remaining typed skips,
overlays, and the exact claim. Host artifacts are labeled regression evidence,
not substituted for primary renderer results:

- `exact font-input/token lock` for locked source assets and semantic tokens;
- `visual equivalence at documented tolerances` for progressive JPEG sources;
- `lossless-source typography equivalence at Tier C tolerances` for qualifying
  PNG/HEIC sources;
- `raw-pixel identity` only for zero unmasked differences under one locked
  renderer/capture path.

Delete or label stale counts; never copy historical 64/186/30 or current
32/218/30 counts into the final report unless the candidate hashes match.

- [ ] **Step 5: Run the complete required verification**

Run the first block with workdir `mobile/`:

```bash
flutter pub get
export PRIMARY_IOS_CAPTURE_DIR="$PWD/../artifacts/reference-typography/final-ios-device-captures-2026-08-31"
export PRIMARY_IOS_JPEG_REPORT_DIR="$PWD/../artifacts/reference-typography/final-ios-device-jpeg-2026-08-31"
export PRIMARY_IOS_SETTINGS_REPORT_DIR="$PWD/../artifacts/reference-typography/final-ios-device-settings-2026-08-31"
flutter test test/reference_font_lock_test.dart \
  test/reference_font_specimen_render_test.dart \
  test/reference_font_specimen_test.dart \
  test/reference_typography_role_coverage_test.dart \
  test/primary_renderer_typography_evidence_test.dart \
  test/tab_typography_candidate_export_test.dart \
  test/tab_reference_manifest_test.dart \
  test/tab_typography_tokens_test.dart \
  test/tab_typography_comparator_test.dart \
  test/tab_typography_golden_test.dart \
  test/bottom_navigation_icon_parity_test.dart \
  test/settings_navigation_video_test.dart \
  test/market_watch_parity_test.dart \
  test/chart_controls_test.dart \
  test/chart_geometry_test.dart \
  test/chart_light_theme_test.dart \
  test/trade_position_bulk_actions_flow_test.dart \
  test/history_screen_detail_test.dart
flutter test
flutter analyze
flutter build apk --debug
flutter build ios --simulator
dart format --output=none --set-exit-if-changed lib test tool integration_test test_driver
```

Run the second block with workdir `backend/`:

```bash
dotnet build Trading.sln
dotnet test Trading.sln --no-build
```

Run the final block from the repository root:

```bash
git diff --check
git status --short
```

Expected: every command exits 0. Inspect `git status` and confirm no unrelated
user-owned file, reference source, mask, or unreviewed golden changed.

- [ ] **Step 6: Perform final visual review at original scale and 4x zoom**

For every screen inspect whole composition plus glyph overlays for roundness,
weight, counters, joins, ascenders/descenders, baseline, spacing, color, and
fallback. A numeric PASS without human glyph-shape review is insufficient.

- [ ] **Step 7: Hand off blockers honestly**

If the licensed numeric-face gate or lossless-source gate remains open, list the
exact affected roles and required input. Do not mark the overall “100% font” goal
complete while either affects an in-scope role.

## Execution Notes

- The most likely fast path is that exact older Roboto/Roboto Condensed files and
  removal of global synthetic width/weight recover most reference appearance.
  Previous read-only comparison showed substantially better static text when the
  recent heavier tuning was absent, but that is evidence to prioritize work, not
  permission to restore whole files.
- Optimize a role only after fixing its font binary. The fixed order is face,
  real weight, size/line metrics, tracking/advance, color, then baseline/position.
- If a change improves one string but worsens another sharing the same role,
  split the semantic role only when the reference demonstrates a real distinction.
- The repository guide requires backend build/test after every task even though
  this plan changes no backend contract. Execution therefore requires .NET SDK
  8.0.421 before Task 1 and never changes `global.json` to bypass that gate.
