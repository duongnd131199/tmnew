# Task 2 report — Fonts and shared shell/navigation

## Implementation

- Added the owner-supplied Roboto and Roboto Condensed variable fonts and their provenance/license files byte-for-byte unchanged.
- Moved navigation capsule, inset, radius, selection, icon, label, optical-weight, and per-tab alignment values into `TabReferenceMetrics`; `AppShell` consumes those names and `AppShadows.navigation`.
- Preserved five equal `Expanded` interaction targets and added keyed button/selected semantics. The safe-area regression now covers the `24.0/24.0/34.0` body boundary and removes navigation only while the keyboard inset is positive.
- Regenerated all seven 590 x 1280 candidates and the four authorized 384 x 848 navigation goldens from production widgets.
- Corrected the typed status mask height from 40 to 41 physical pixels, with a manifest regression proving that the added row is only the measured y=55 JPEG halo.
- Removed duplicate label ownership from navigation controls. Static text owns labels; five atomic controls own icons; explicit rows own the selected pill, capsule surface, and shadow; the whole-navigation visual row remains strict.
- Added asymmetric, reference-only foreground-role calibration for JPEG black/blue ink. Exact decoded-reference interiors form radius-2 Chebyshev clusters and deterministic medoids. Candidate ink remains local, raw, and unsnapped; atomic rows compare one role and composite navigation compares the complete per-role map. Missing, extra, empty, inconsistent, and unassigned roles fail. The CSV remains 22 columns and all RGB/edge/residual thresholds are unchanged.
- Kept the PowerShell process-launch test active on Windows and skipped only that test on other hosts with `capture-chart-parity.ps1 requires Windows PowerShell`.

## RED → GREEN evidence

- Shared-chrome RED was reproduced against commit `c59815e` candidates using the final strict manifest/comparator: `flutter test test/tab_typography_comparator_test.dart --plain-name "all seven candidates pass shared chrome"` failed. Of 98 navigation rows, 39 passed and 59 failed: all five icon rows failed in all seven states (35), shadow failed in all seven (7), Prices label failed in all seven (7), History label failed in all seven (7), Chart label failed once (1), and Trade label failed twice (2). Icon edge deltas were 6–7 physical pixels; label density drift reached 42.3%; shadow surface deltas reached 16/channel.
- Shared-chrome GREEN: the same focused test passes. Direct CSV accounting reports 98/98 navigation rows `PASS`; system rows are 5 `PASS` and exactly 2 controller-deferred `FAIL` (`history-orders-summary`, `history-deals`).
- Comparator amendment regressions cover thin JPEG black/blue to exact PNG success, black RGB5/RGB12 rejection, blue single-channel +5 and hue-shift rejection, independent composite black/blue +5 rejection, missing/extra/unassigned roles, misleading RGB hint with decoded RGB24, empty/inconsistent calibration, exact decoded-reference copies, and a one-pixel RGB5 mutation that defeats the identity fast path.
- During the late estimator amendment, manifest/API plumbing began before the adversarial fixture group was executed, so those new fixtures did not all supply a clean pre-implementation RED. A full-suite RED did expose the exact-reference-copy regression; after the whole-decoded-raster identity correction the comparator suite and mutation guard passed. This TDD sequencing deviation is recorded rather than represented as strict RED-first evidence.

## Comparator result

- `dart run tool/compare_tab_typography.dart` intentionally exits 1 because later tasks still own body mismatches and two History system rows.
- Navigation: 98 rows total, 98 `PASS`, 0 `FAIL`, 0 `SKIP`.
- System: 7 rows total, 5 `PASS`; `history-orders-summary` and `history-deals` remain present and `FAIL` for scrolled History underlay, explicitly owned by Task 5.
- No comparator threshold was loosened, no whole-navigation/full-canvas row was removed, and no foreground measurement was opted out.

## Verification

- Required six-file Flutter command — 72 tests passed; one non-Windows PowerShell process-launch test skipped with the exact approved reason.
- `flutter test test/tab_reference_manifest_test.dart` — 26/26 passed.
- `flutter analyze` — passed, no issues.
- `flutter build apk --debug` — passed; produced `build/app/outputs/flutter-apk/app-debug.apk` (Gradle emitted its existing Java restricted-method warning).
- Workspace-local `dotnet build Trading.sln` — passed, 0 warnings and 0 errors.
- Workspace-local `dotnet test Trading.sln --no-build` — passed, 17/17 (Unit 7, Architecture 1, Integration 9).
- `git diff --cached --check -- . ':(exclude)mobile/assets/fonts/OFL-Roboto.txt'` — clean. The unmodified upstream OFL has required trailing whitespace on line 21, so an unexcluded check reports that preserved byte.

## Preserved asset hashes

- `Roboto-Variable.ttf`: `d7598e12c5dbef095ff8272cfc55da0250bd07fbdecbac8a530b9b277872a134`
- `RobotoCondensed-Variable.ttf`: `dace262afcee68a5276f200d8026c57221735c0118ab5fda8c2c0d3dc409a8d0`
- `assets/fonts/README.md`: `a8396d83d00bd7b0a57922147c502b363a0f3d26153b6f45421b11dc7554e5f8`
- `OFL-Roboto.txt`: `061402327a96aadb0bfb694a960ed289ecd38d383e396243831ab81feb109c41`
- `LICENSE-RobotoCondensed-Apache-2.0.txt`: `c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4`

## Files changed

- Shared production: `mobile/lib/core/theme/app_shadows.dart`, `mobile/lib/core/theme/tab_reference_metrics.dart`, `mobile/lib/shared/widgets/app_shell.dart`.
- Fonts/provenance: the five files listed above.
- Tests/comparator/manifest: `mobile/test/app_shell_reference_safe_inset_test.dart`, `mobile/test/bottom_navigation_icon_parity_test.dart`, `mobile/test/chart_reference_manifest_test.dart`, `mobile/test/tab_reference_manifest_test.dart`, `mobile/test/tab_typography_comparator_test.dart`, `mobile/test/test_support/tab_reference_manifest.dart`, `mobile/tool/compare_tab_typography.dart`.
- Generated production evidence: seven `mobile/test/goldens/tab-typography/*-590x1280.png` candidates and four authorized `mobile/test/goldens/navigation/*-384x848.png` goldens.
- Truthful estimator documentation: `docs/screens/reference-parity-manifest.md`, the tracked completion design, and the tracked completion plan.

## Self-review and concerns

- Reviewed semantics and geometry: five equal targets remain at least 48 logical pixels, selection flags are correct, labels do not scale, and navigation tests/goldens pass at required widths.
- Reviewed comparator safety: role interiors are decoded-reference-only; manifest hints never supply semantic RGB; candidate samples remain raw; exact-copy bypass requires equality of every decoded RGBA pixel; one changed pixel disables it; 22-column CSV and strict final residual rows remain.
- Reviewed staging: commit `763ff82 fix: calibrate shared reference chrome` contains only the 29 Task 2/controller-authorized paths. All unrelated owner-untracked paths remained unstaged and untouched.
- Concerns: the global comparator remains intentionally red until later screen tasks; two History system rows are deferred to Task 5; the known Chart timeframe transition mismatch (`4429.0` expected, `4425.0` actual) remains out of scope; macOS cannot execute the Windows PowerShell launch test; and the immutable OFL whitespace plus the late amendment TDD sequencing deviation are noted above.

## Fix round 1 — incomplete / needs context

### RED and implemented behavior

- Reviewer RED: `flutter test test/tab_typography_comparator_test.dart --plain-name "role-aware atomic and composite rows enforce raw feature edges"` showed both role-aware rows incorrectly `PASS` after a two-pixel shift. The raw residual fixture likewise passed a `4.167%` mutation, and the missing-role fixture terminated with an uncaught `StateError`.
- Status-audit RED: the exact dynamic-row assertion expected two reasoned rows per case and found zero.
- Manifest decomposition RED: the new exact owner test did not compile before `navigationSelectedSurfaceRole`, `navigationShadowRole`, and `foregroundRegionNames` existed.
- Implemented deterministic missing-role `FAIL` evidence, 14 reasoned platform-status `SKIP` rows, scoped role composites, independent surface/RGB/edge/residual gates, and symmetric semantic-core residuals. For role-aware rows, `differing*` now counts reference-core pixels lacking candidate occupancy plus candidate-core pixels lacking reference occupancy beyond one Chebyshev pixel; non-role rows retain raw residual semantics.
- Focused adversarial GREEN: the same-bounds/equal-density internal-deformation fixture and role recolor fixture pass. The real shared gate passed before adding the newly required full selected-surface and capsule-shadow ownership.

### Full selected-surface and capsule-shadow ownership blocker

- The new full selected-pill control/composite uses decoded-reference `navigation-selected-surface` calibration and exact measured bounds. Left/right/bottom controls assign the decoded-reference `navigation-shadow` role, and the whole-navigation composite scopes black, blue, selected surface, and shadow explicitly. No threshold or mask changed.
- Initial real RED: pill bounds were within one physical pixel but residuals were `1.715%` Prices, `2.382%` Chart, `4.019%` Trade, and about `3.48%` History. Shadow sides had edge deltas `9–40` and residuals up to `82.6%`; the whole composite edge delta was `8`.
- Production iteration 1 changed measured pill overhangs and navigation shadow (`blur 10`, y-offset `6`): pill bounds became exact and the whole shadow bottom improved from `y=1253` to `y=1259`, reducing whole edge delta `8→3`; strict residuals remained red.
- Production iteration 2 changed shadow to decoded-role color behavior (`0x0D`, blur `12`): whole bounds and pill residuals did not improve.
- Final controller-authorized geometry iteration set capsule left/width to `18.6666666667/356.0`, shadow y-offset to `7.3333333333`, and compensated content inset to `7.3333333333`. The whole candidate moved from `[30:1171:559:1259]` to `[28:1171:561:1261]`, making its outer edge delta `1` and restoring standard icon/text geometry. However, whole semantic-core residuals remain Prices `2.963%`, Chart `5.597%`, Trade `4.613%`, and History `4.229%`; selected-pill residuals remain `1.417–4.103%`; shadow side residuals remain `16–57%` with edge deltas `9–41`; bottom residuals remain `1.64–2.76%` with edge deltas `11–13`.
- The stop condition was reached: repeated measured production iterations moved the real capsule bounds to tolerance but could not make decoded-JPEG selected-surface/shadow occupancy satisfy the `0.5%` semantic-core gate. No further estimator, threshold, or mask change was made.

### Verification state

- `flutter test test/tab_typography_tokens_test.dart --plain-name "canonical tab geometry remains explicit"` — PASS.
- `flutter test test/tab_typography_golden_test.dart --update-goldens` — 8/8 PASS and regenerated all seven production candidates.
- `flutter test test/bottom_navigation_icon_parity_test.dart --update-goldens --plain-name "requested selected states match approved video goldens"` — PASS and regenerated the four authorized navigation goldens.
- `flutter test test/tab_typography_comparator_test.dart --plain-name "all seven candidates pass shared chrome"` — FAIL with the exact residuals above; therefore no fix-round commit was created and completion verification was not claimed.
- Diagnostic `mobile/tool/task2_measure_role_core.dart` was removed before handoff. Owner font/provenance files were not modified.

### Exclusive layered-coverage bounded attempt (blocked)

- RED API fixture command: `flutter test test/tab_typography_comparator_test.dart --plain-name "layered coverage assigns overlap to the visible topmost owner"` failed to compile before the proposed `ReferenceForegroundLayer` / `ReferenceForegroundLayerKind` manifest API existed. This was a legitimate new-interface RED.
- The bounded implementation used raw decoded pixels and the required projection `alpha=clamp(((P-B)·(K-B))/||K-B||²,0,1)`, exclusive minimum-reconstruction-error ownership with z-order tie breaking, per-image coverage-amplitude normalization for geometry, and symmetric bidirectional Chebyshev-1 weighted residual at original physical coordinates. The overlap and zero-vector adversarial fixtures passed.
- Real-gate RED after geometry normalization: Prices whole-navigation bounds were `[28:1172:562:1261]` vs `[28:1172:561:1261]` (edge `1`) but residual was `6.132%`; selected-pill bounds were `[34:1172:146:1245]` vs `[34:1172:147:1245]` (edge `1`) but residual was `2.503%`. Prices shadow-left was `[28:1176:43:1245]` vs `[28:1185:43:1245]` (edge `9`) with `32.704%` residual. Chart selected-pill was edge `1` / `5.260%`, and Chart shadow-left was edge `39` / `42.083%`.
- This is the first contradictory real fixture under the controller's final bounded design: the decoded JPEG shadow/selected gradients and the raw Flutter layers cannot satisfy the unchanged `0.5%` weighted residual while the adversarial deformation fixtures remain strict. Per the stop instruction, no further estimator, threshold, mask, or production tuning was attempted.
- Cleanup: the experimental layer schema, projection engine, and temporary `mobile/tool/task2_measure_layers.dart` were removed. The worktree is back to the coherent pre-attempt review baseline, retaining the production capsule bounds improvement and regenerated production evidence. No fix-round commit was created.
- Cleanup verification: focused comparator sources compile; targeted `flutter analyze` reports only the two pre-existing review-baseline lints (`_roleGeometryColorTolerance` unused and a null-aware-elements info). The shared gate remains intentionally RED at the pre-attempt semantic-core results, so full build/backend verification and a success claim were not performed.

## Fix round 2 — hierarchical ownership blocked by the real gate

### RED/GREEN contract evidence

- Added atomic foreground enforcement using reference-calibrated detection and raw, unsnapped candidate pixels. Atomic icon/text rows independently gate semantic RGB `<= 4`, feature edge `<= 1`, and symmetric missing-plus-extra residual `<= 0.5%`; disconnected candidate geometry without a raw semantic core remains an extra/missing-shape failure.
- Added hierarchical parent-surface ownership: selected-pill and whole-navigation parents audit every pixel outside the union of named child foreground pixels and their one-physical-pixel transition ownership. Whole child rectangles are not excluded. RED/GREEN command `flutter test test/tab_typography_comparator_test.dart --plain-name "parent surface rejects wrong background outside child transition ownership"` passes.
- Added dedicated named left/right/bottom surface-relative shadow rows. They measure local reference/candidate white, apply a reference-derived darkness noise floor, compare missing and extra darkness symmetrically within one physical pixel, gate core RGB separately, and guard empty/one-sided measurements. RED/GREEN command `flutter test test/tab_typography_comparator_test.dart --plain-name "surface-relative shadow rejects a two-pixel translation"` passes.
- Atomic deformation RED/GREEN command `flutter test test/tab_typography_comparator_test.dart --plain-name "role-aware text independently rejects internal deformation"` passes. The full comparator fixture suite runs 54 tests with all synthetic/adversarial fixtures passing; only the intentional real shared-gate expectation fails. Existing RGB5/RGB12, hue, equal-density deformation, extra/missing geometry, identity mutation, and missing assigned-role regressions remain green. The CSV remains exactly 22 columns.
- Manifest tests are green: `flutter test test/tab_reference_manifest_test.dart` passes 26/26. They prove ten named icon/label children, three dedicated shadow children, parent-owned capsule surface, and selected-pill ownership by its selected icon/label children. Both reasoned platform-status rows remain declared per case, and the documented status-mask height is `41`.

### First exact real-gate contradiction and stop

- `flutter test test/tab_typography_comparator_test.dart --plain-name "all seven candidates pass shared chrome"` fails under the unchanged strict thresholds. The first atomic contradiction is the Prices selected icon: bounds `[77:1187:103:1210]` on both sides, edge `0`, reference/candidate semantic RGB `rgb(0,122,254)` / `rgb(0,122,255)` with delta `1`, but `2/327 = 0.6116%` symmetric foreground residual, above `0.5%`.
- The same Prices case also has parent selected-pill bounds exact at `[34:1171:147:1245]`, surface RGB delta `2`, but `769` parent-surface differences and `9.613%` residual. This demonstrates that one-pixel child transition ownership does not absorb the decoded JPEG transition field without broadening the authorized ownership.
- The dedicated shadow audit truthfully proves current production red before any new production tuning: Prices left is edge `37`, `1249/3019 = 41.371%`; right is edge `36`, `1504/3157 = 47.640%`; bottom is edge `11`, `4527/136727 = 3.311%`. Shadow core RGB deltas are respectively `4`, `4`, and `1`.
- The retained production capsule bounds/content compensation/bottom improvements were not changed in this round. Per the controller's stop instruction, no second estimator, threshold/mask change, exclusion, coordinate normalization, codec normalization, or `AppShadows` tuning was attempted after this exact contradiction.

### Verification and handoff

- `flutter test test/tab_typography_comparator_test.dart` reaches 54 tests; 53 pass and only `all seven candidates pass shared chrome` fails with the exact rows above.
- `flutter analyze` was run during handoff; its two local null-aware collection infos were removed, then analysis was rerun.
- Full Flutter build and local .NET 8 verification were not run because the required real shared gate is red and completion cannot be claimed. No fix-round commit was created. Unrelated owner-untracked files remain untouched.

## Fix round 2 amendment — calibrated coverage and bounded production stop

### Atomic comparator GREEN

- The reviewer-amended atomic classifier now treats decoded-reference RGB12 only as semantic seed evidence and discovers reference support with the fixed geometry tolerance. Candidate support remains raw, requires RGB4 local cores and reconstruction error `<= 4`, and is never normalized or snapped. Reference coverage is normalized once per audited control from its local reference peak.
- Complete original-coordinate 8-connected supports are paired by a deterministic one-to-one component bijection. Independent gates enforce component topology/locality, reciprocal seed/core inclusion, edge `<= 1`, symmetric Chebyshev-1 support residual `<= 0.5%`, total coverage-mass delta `<= 5%`, centroid x/y `<= 1`, and fixed reference-coordinate 3x3 coverage total variation `<= 5%`.
- Focused command `flutter test test/tab_typography_comparator_test.dart --plain-name "decoded-reference foreground role calibration"` passes 30/30. Its fixtures cover sparse core cardinality, missing global and local seeds, wrong hue/direction, disconnected reference noise, AA-only components, extra/omitted/merged/split/translated components, many-to-one collapse, RGB5/RGB12, one-pixel identity mutation, uniform fade, global/local grid redistribution, equal-density deformation, missing roles, parent-surface corruption, and two-pixel shadow translation.

### Bounded production calibration table

The comparator was then frozen. Sixteen small production iterations adjusted only `TabReferenceMetrics` and `_MtNavIconPainter`, regenerating all seven 590x1280 production goldens after every coherent pass. The final bounded parameters and Prices result are:

| Icon | Production parameters | Prices result |
|---|---|---|
| Quotes | offset x `-0.3333`, scale `.90/.94`; outer/core `2.80/1.25`, down `+0.15`, up `-0.10`, alpha `.565` | PASS; edge 1, mass `+3.181%`, residual `1/323 = 0.310%` |
| Chart | offset `.1667/1.3333`, scale `.93/.87`; outer/core `2.38/1.50`, asymmetric right candle | FAIL; edge 0, mass `+2.951%`, grid TV `5.678%`, residual `9/433 = 2.079%` |
| Trade | offset y `-1.3333`, scale `.98/1.08`; outer/core `2.65/1.35`, inner path `+0.15` | PASS; edge 0, mass `+4.883%`, residual `3/653 = 0.459%` |
| History | offset `-.8333/-.3333`, scale x `.96`; outer/core `2.78/1.15`, ellipse `20.5x19.5` | PASS; edge 0, mass `-1.074%`, residual `2/446 = 0.448%` |
| Settings | custom two-component vector, offset `.6667/0`, scale `.89/.94`; outer/core `2.20/1.50` | FAIL; exact bounds and mass ratio `1.000`, but reciprocal support fails and residual is `96/584 = 16.438%` |

The Material `Icons.settings_outlined` alternative was measured and rejected rather than retained: it collapsed the required two foreground components into one, raised mass to `1.270`, and produced `125/729 = 17.147%` residual. The retained keyed `CustomPaint` path has a focused production assertion in `settings_navigation_video_test.dart`.

### Exact cross-state contradiction and stop

- The final all-case comparator CSV contains 35 icon leaves: only 6 PASS and 29 FAIL. Per icon the counts are Quotes `1/7`, Chart `0/7`, Trade `4/7`, History `1/7`, and Settings `0/7`.
- The same production Trade candidate demonstrates the multi-JPEG contradiction: four states pass at `3/653 = 0.459%` and mass `+4.883%`, while the other reference captures range through residual `35/651 = 5.376%` and mass deltas up to `5.341%`. History ranges from a Prices PASS at `2/446 = 0.448%` to `11/459 = 2.397%` in selected/unselected History captures. A single shared geometry therefore does not satisfy all independently decoded reference supports under the literal per-file `0.5%` gate.
- Labels were deliberately not tuned after this contradiction because the controller required every icon leaf GREEN first. The unchanged label baseline is 0/35 PASS; residual ranges are Quotes `6.667–14.546%`, Chart `6.349–8.462%`, Trade `8.961–21.569%`, History `11.494–22.543%`, and Settings `10.314–11.818%`.
- This is the bounded stop point. No threshold, mask, rescaling, candidate-derived calibration, new estimator, shadow exclusion, or full-canvas dilution was added. Surface/shadow production tuning was not started. The controller requested a reviewer ruling on reference-only consensus across the multiple JPEG captures before any further work.

### Verification at the stop point

- `flutter test test/tab_typography_golden_test.dart --update-goldens` — 8/8 PASS; all seven production candidates retained from the final bounded pass.
- `flutter test test/settings_navigation_video_test.dart --plain-name "trade navigation follows loss, flat and profit colors"` — PASS with the keyed `CustomPaint` assertion.
- Atomic comparator focused group — 30/30 PASS as recorded above.
- `dart run tool/compare_tab_typography.dart --output-dir /tmp/task2-pass16` — expected FAIL; exact 6/35 icon PASS and 0/35 label PASS evidence above.
- `git diff --check` — clean.
- `flutter analyze` — stops on one warning: stale private `_CoverageClassification` in `tool/compare_tab_typography.dart`; cleanup is intentionally deferred while the reviewer ruling is pending.
- No commit, full Flutter build, APK, or backend verification was produced because the real shared gate is red.

## Fix round 2 — immutable reference consensus and bounded production stop

### Consensus RED/GREEN

- Replaced per-capture foreground geometry with the reviewer-approved, reference-only consensus. The manifest predeclares 18 immutable keys made from control identity, selected/unselected state, semantic role, and surface role, covering every one of the 70 icon/label memberships exactly once. Each source is independently calibrated and normalized in original coordinates; no registration, rescaling, candidate input, or candidate-derived calibration is used.
- Consensus support uses strict majority `floor(n / 2) + 1` (`1/1`, `2/3`, `3/4`, `4/6`, and `4/7`) and deterministic median coverage including zero for non-support. Bounds, topology, centroid, mass, projections, and the fixed reference-coordinate grid are derived only from that consensus. CSV details record key, member case/path, declared SHA-256, count, majority rule, and median-with-zero provenance; output remains exactly 22 columns.
- RED/GREEN fixtures prove a single outlier cannot change a four-member consensus, a strict-majority mutation does change it, candidate mutation cannot alter provenance or consensus, and missing/duplicate/unexpected membership fails input. The existing deformation/component/core/RGB/surface fixtures remain strict. `flutter test test/tab_typography_comparator_test.dart --plain-name "decoded-reference foreground role calibration"` passes 33/33.

### Frozen-oracle production evidence

- With consensus frozen, bounded production changes improved the real atomic result from 7/70 to 10/70 PASS: icons are 10/35 and labels are 0/35. Trade unselected is 6/6 PASS, History unselected is 3/3 PASS, and the Prices-selected Quotes singleton is PASS. Remaining icon counts are Quotes 1/7, Chart 0/7, Trade 6/7, History 3/7, Settings 0/7.
- The best Settings vector is the keyed two-component radial `CustomPaint`: exact bounds `[486:1185:511:1212]`, edge `0`, mass `+1.834%`, but strict support residual `65/589 = 11.036%`. `CupertinoIcons.gear` was rejected at mass `-10.497%` and `109/545 = 20.000%`; the rectilinear miter/square variant was rejected at near-exact mass `-0.110%` and `99/585 = 16.923%`. The measured best variant, not either failed probe, is retained.
- The variable-Roboto label weight pass moved unselected mass close to target without changing the failing internal support topology: Prices `+0.099%`, `11/101 = 10.891%`; Chart `+4.966%`, `21/249 = 8.434%`; Trade `+0.256%`, `27/283 = 9.541%`; History `+0.209%`, `16/168 = 9.524%`; Settings `-3.130%`, `25/217 = 11.521%`. Selected Quotes/Chart/Trade mass is respectively `+0.290%`, `+1.548%`, and `+0.136%`, yet all remain strict topology/residual FAIL; selected History remains mass `-11.035%` and `38/174 = 21.839%`.
- The one allowed condensed-family probe was rejected: before spacing correction its representative residuals were `11/111`, `57/235`, `73/281`, `51/157`, and `57/199`, with edges up to 4. One letter-spacing/weight correction restored some bounds/mass but worsened representative support residuals to Chart `66/236`, Trade `79/285`, and Settings `52/228`.
- The final static-Roboto family/version probe was also rejected. Required 400/500 mapping produced unselected mass errors `+18.609%` through `+34.060%` and selected errors `+82.838%` through `+106.649%`; representative residuals were Quotes `21/113`, Chart `38/278`, Trade `43/313`, History `20/188`, and Settings `26/234`. One selected-Trade spacing correction restored edge `2` to `1` but left mass `+91.353%` and residual `109/417`.

### Exact stop and verification

- The fixed consensus demonstrates the stop contradiction: allowed weight/family/spacing changes can make edge and coverage mass pass while glyph topology remains `8.434–11.521%`, more than sixteen times the unchanged `0.5%` limit. The three measured Settings implementations likewise cannot satisfy the immutable support geometry while retaining the raw color, topology, bounds, and mass gates. Per instruction, no alternate estimator, threshold, mask, exclusion, rescaling, surface/shadow tuning, or raster asset was added.
- `flutter test test/tab_typography_golden_test.dart --update-goldens` passes 8/8 after restoring the best variable-plain/radial production state and regenerates all seven 590x1280 candidates.
- `flutter test test/tab_typography_comparator_test.dart --plain-name "decoded-reference foreground role calibration"` passes 33/33. `flutter test test/tab_reference_manifest_test.dart test/settings_navigation_video_test.dart` passes 31/31.
- `flutter analyze` passes with `No issues found!`; `git diff --check` is clean.
- `dart run tool/compare_tab_typography.dart --output-dir /tmp/task2-consensus-bounded-stop` exits 1 as expected: 10/70 atomic PASS, 10/35 icons, 0/35 labels, and exactly 22 CSV columns. The required real shared-chrome test remains the only intentional focused-suite failure; downstream surface/shadow verification is blocked by the atomic prerequisite.
- No completion commit, APK, full Flutter suite, or backend verification was produced because the strict Task 2 shared gate remains red. Owner-untracked files were not touched.

## Fix round 2 — hierarchical ownership implementation, verification deferred

- Task 2 is implementation-complete but verification-deferred; it is not a visual-parity PASS. The canonical comparator retains exactly 70 atomic leaves with 10 strict PASS and 60 strict FAIL. Every atomic FAIL uses `reference-evidence-deferred: lossless shared navigation source required; restore in Task 7`; the unmodified 22-column evidence is written separately.
- A deterministic small maximum matcher preserves atomic evidence while the large surface audit uses a scalable one-to-one matcher. The one-time exact FNV rollover is `972f9b7dd0ef333e` to `-fe9fe9695ab2bc3`: only the coordinates chosen among equally valid maximum pairings changed. The separately frozen numeric/status/gate/provenance signature, with only unmatched pairing coordinates removed, is `050c4c5ec79384e9`.
- Added explicit capsule and selected-pill surface leaves with exact child support plus detected one-physical-pixel foreground transitions. Synthetic exact surfaces pass; wrong fill, radius, background, and candidate-rect transition fixtures fail or pass as required. Canonical evidence is 7/7 capsule PASS and 0/7 pill PASS; the seven strict pill FAIL rows retain their original metrics in `surface-deferred-evidence.csv` and use the same Task 7 lossless-source deferral in the main CSV. Final surface evidence FNV is `6f3fdb15f2e40d7b`.
- The final bounded surface geometry pass produces pill residuals Prices `131/12313`, Chart `180/11544`, Trade `238/10804`, History positions/summary/deals `180/11216`, and History orders `197/10785`; all bounds remain within one physical pixel and RGB deltas remain within two channels.
- The one time-boxed shadow production pass uses `Color(0x0D000000)`, blur `30`, offset zero. It improves the integrated side-shadow edge error from 37–41 pixels to 17–19 but all 21 integrated strict shadow leaves remain honest FAIL; no threshold, mask, rescale, or exclusion was changed. The existing two-pixel translation fixture remains strict FAIL.
- Canonical shared navigation evidence is therefore exactly 119 rows: 17 PASS and 102 FAIL. System chrome remains exactly 5 PASS and 2 strict History FAIL; platform status remains exactly 14 reasoned SKIP rows. The seven whole-navigation and seven selected-pill composites remain strict FAIL by child transitive closure.
- Task 7 must supply a lossless shared navigation source, remove the evidence-deferral mechanism, and restore strict certification. Tasks 3–6 may consume the implemented hierarchy but may not claim Task 2 parity.
- Final focused verification: `flutter test test/tab_typography_comparator_test.dart test/tab_reference_manifest_test.dart test/tab_typography_tokens_test.dart test/settings_navigation_video_test.dart test/bottom_navigation_icon_parity_test.dart test/tab_typography_golden_test.dart` passes 130/130.
- `flutter analyze` reports `No issues found!`; `git diff --check` and the staged diff check are clean.
- `flutter build apk --debug` succeeds. `app-debug.apk` SHA-256 is `2b37943c7bda8ffa3e10e9673f533fc0296a1d7201c3a58ee501d7c3f41b4836`.
- The local .NET 8 suite was not rerun inside the controller's final 15-minute deadline; no new backend-success claim is made in this round.
