# SDD ledger — plan: docs/superpowers/plans/2026-08-27-seven-state-visual-parity-completion.md

## Session

- Branch: `codex/reference-parity-foundation`
- Starting HEAD: `30f2841`
- Execution order: Task 1 through Task 7, with one fresh implementer and one independent reviewer per task.
- User authority: the user's explicit instruction to continue through every task authorizes uninterrupted local implementation, verification, evidence generation, and local commits. It does not authorize merge, push, publish, or external deployment.

## Pre-flight consistency scan

| Producer | Consumer(s) | Shared interface/files | Execution ruling |
|---|---|---|---|
| Task 1 | Tasks 2–7 | comparator API, case filtering, CSV schema, dynamic-mask contract | Task 1 must land and be independently reviewed first; all later acceptance uses its 22-column output. |
| Task 2 | Tasks 3–7 | fonts, theme tokens, `TabReferenceMetrics`, AppShell, navigation, all seven candidates | Regenerate all candidates once in Task 2; later tasks may touch only the named state candidates except when their plan explicitly requires a shared regeneration. |
| Task 3 | Task 7 | Prices screen, Prices candidate, manifest evidence | Prices changes stay isolated from Trade/History/Chart behavior. |
| Task 4 | Task 7 | Trade screen, Trade candidate, responsive-width contract | Shared typography/metrics may change only when a strict FAIL maps to an existing shared role, then all impacted cases must be rechecked. |
| Task 5 | Task 7 | one History system, four state candidates and scroll contracts | All four History cases must be regenerated and compared together after every shared History change. |
| Task 6 | Task 7 | Chart static layers, chart matrix, Chart candidate | Preserve untracked session-store source/test byte-for-byte; chart data/interaction logic is out of scope unless a behavior test proves an anchor defect. |
| Task 7 | Completion gate | all source/tests/candidates/evidence/device captures/docs | Final verification consumes the complete branch and may apply only one cross-state fix wave after final review. |

## Internal task checks

| Task | Consistency result |
|---|---|
| 1 | RED fixtures, shared containment helper, foreground measurement, 22-column CSV, and `--case` contract form one coherent comparator boundary. |
| 2 | Font provenance, safe-area contract, shared nav tokens, generated candidates, and host-aware PowerShell test are internally compatible. |
| 3 | Prices behavior assertions precede toolbar/row calibration and single-case evidence. |
| 4 | Trade scrollbar/width/interaction tests precede visual calibration and single-case evidence. |
| 5 | Four scroll-state tests and one shared History implementation prevent screenshot-specific forks. |
| 6 | Behavior/hash locks precede outside-in static Chart calibration and 27-golden regeneration. |
| 7 | Deterministic acceptance precedes device capture, full verification, and evidence-backed documentation. |

## Rulings

1. Treat the seven supplied light-theme JPEGs as the visual authority over stale dark-first documentation. Cost: dark theme remains behavior-preserved but is not claimed as reference-perfect in this work.
2. Continue on the dedicated in-place branch instead of creating a linked worktree because the approved inputs include owner-untracked font assets/tests and the previous parity workspace contains baseline evidence. Cost: branch hygiene must be checked before every commit.
3. Incorporate only the explicitly planned owner-untracked fonts, licenses, safe-inset test, and Trade width test. Preserve all other owner-untracked paths untouched and unstaged. Cost: those approved files become tracked branch content.
4. On non-Windows hosts, skip only the PowerShell process-launch test with the explicit platform reason while keeping all platform-independent manifest assertions active. Cost: the PowerShell process itself cannot be executed on this macOS host.
5. Use a single dynamic-mask full-containment helper for validation and SKIP authorization. Cost: existing partial-mask false passes become hard input errors and manifests may need tighter rectangles.
6. Preserve the required `global.json`; if SDK 8 is absent, attempt a workspace-local official SDK installation rather than changing the stack. Cost: additional local setup time and disk use.
7. Task 2 owns navigation for all seven states and the `system` row only where that row contains shared chrome. In `history-orders-summary` and `history-deals`, the measured `system` residual is app-owned scrolled History content under a translucent edge-to-edge status area, so Task 5 owns those two `system` rows and its strict whole-case gate must make them PASS. Cost: the literal “all seven system rows PASS in Task 2” checkpoint is deferred for exactly two cases, while the global comparator remains strict and failing until Task 5; no row, threshold, or pixel is masked away.
8. Extend each existing typed system-status mask by exactly one physical row (height 40 → 41) only if a manifest test locks the measured y=55 JPEG halo and proves no app-controlled content is covered. Cost: Task 2 touches the manifest/test outside its original file list to correct a platform-owned boundary exposed by the hardened comparator.
9. Normalize bottom-navigation semantic ownership: labels are audited only as static text; five tight icon controls audit icon foreground; selected-pill, capsule surface, and shadow use non-overlapping controls; the visual nav rect is limited to the measured capsule/shadow while whole-canvas and final case residuals remain strict. Cost: Task 2 extends the manifest beyond its original file list and must add exact manifest assertions so no nav foreground becomes unaudited.
10. Regenerate and stage the four tracked 384×848 navigation goldens after the canonical 590×1280 nav geometry changes. Cost: Task 2 extends its generated-asset allowlist, but the images remain production-derived and their updated pixel bounds must be asserted by `bottom_navigation_icon_parity_test.dart`.
11. Replace crop-only JPEG foreground semantics with asymmetric reference-only role calibration where thin/composite foreground is otherwise non-invertible. Explicit interior rectangles in the decoded reference build a repeated radius-2 cluster medoid; manifest ink is only a role key, candidate colors remain raw/unsnapped, the hard RGB4 limit remains unchanged, and composite rows compare every declared role with missing/extra roles failing. Cost: Task 2 amends the Task 1 estimator contract and its design/plan documentation after empirical evidence showed black medians 11–47 and selected-blue deltas 25–67 despite no common RGB4 core; adversarial tests must retain RGB5/RGB12 and hue-shift detection and prove the manifest hint is not the oracle.
12. For role-aware atomic/composite rows, enforce the residual limit on exact-coordinate semantic-core classifications derived only from 3×3-eroded reference role/surface pixels; candidate pixels remain raw and must classify at the same coordinates. Outer feature bounds/edge, role RGB, surface RGB, missing/extra roles, and non-role raw residual remain independent hard gates. Cost: JPEG halo pixels at semantic transitions are excluded from the role-core residual denominator, so tests must prove a same-bounds/equal-density internal deformation and a recolored core still fail, while an empty core fails loudly.
13. Supersede the non-exclusive role-core experiment with reference-derived layered coverage because selected-surface mismatches were 96–100% confined to glyph bands and the scalar shadow role admitted JPEG background. Each foreground region declares raster kind, underlay, and z-order; composited coverage is reconstructed from decoded raw RGB, visible ownership is exclusive, and reference/candidate coverage is compared symmetrically at original coordinates within one physical pixel. Candidate RGB remains unsnapped and RGB4 is enforced separately; coordinate rescaling is forbidden. Cost: comparator/manifest complexity increases, so missing/extra bars, same-bounds deformation, pill deformation, two-pixel shadow translation, RGB5, role coverage, and real seven-state nav tests must all pass before acceptance.
14. Reject the layered-coverage experiment after its raw projection contradicted the real JPEG shadow (Prices shadow-left edge 9 / residual 32.704%) and keep it out of commits. Fix round 2 uses hierarchical ownership instead: atomic foreground owns its detected pixels plus a one-pixel JPEG transition band; parent surfaces audit every remaining pixel; composite rows aggregate independently enforced child and parent residuals; shadow is a dedicated surface-relative darkness layer rather than a solid RGB role. Cost: the blocked implementer is replaced for this bounded subtask, and tests must prove wrong background behind glyphs, extra/missing/deformed child shapes, pill deformation, and a two-pixel shadow shift cannot hide in the transition allowance.

## Baseline

- `flutter analyze`: PASS — `No issues found! (ran in 1.8s)`.
- `flutter test`: FAIL — `+689 -2`; failures:
  - `chart_reference_manifest_test.dart`: `ProcessException: No such file or directory`, command begins `powershell.exe ... capture-chart-parity.ps1` on macOS.
  - `chart_timeframe_transition_test.dart`: `Expected: <4429.0> Actual: <4425.0>` at line 419; independently reproduced in isolation.
- `flutter build apk --debug`: PASS — `build/app/outputs/flutter-apk/app-debug.apk`.
- Initial system `dotnet build Trading.sln` / `dotnet test Trading.sln --no-build`: environment block, exit 155 — required SDK `8.0.421`; only system SDK `10.0.203` was installed.
- Environment remediation: installed the official exact SDK into ignored `.superpowers/dotnet-8.0.421` without changing `global.json` or global PATH.
- Workspace-local `dotnet build Trading.sln`: PASS, 0 warnings / 0 errors.
- Workspace-local `dotnet test Trading.sln --no-build`: PASS, 17/17 across Architecture (1), Unit (7), and Integration (9).
- Baseline ruling: Task 2 owns the platform-truthful PowerShell skip. Task 6 must investigate the reproducible Chart transition mismatch without touching the owner-untracked session store unless separately authorized by the plan (it is not). No earlier task may claim either baseline failure as its regression.

## Task status

| Task | Status | Base | Head | Review | Verification |
|---|---|---|---|---|---|
| 1. Comparator acceptance | Complete | `30f2841` | `c59815e` | Approved; no findings | 68/68 focused tests, analyze, APK, backend 17/17 PASS; Prices comparison expected FAIL |
| 2. Fonts/shared shell/nav | In progress | `c59815e` | — | — | — |
| 3. Prices | Pending | — | — | — | — |
| 4. Trade | Pending | — | — | — | — |
| 5. History (four states) | Pending | — | — | — | — |
| 6. Chart | Pending | — | — | — | — |
| 7. Final gate/device/docs | Pending | — | — | — | — |

## Review rounds

- Task 1 round 1: Approved. No Critical, Important, or Minor findings. Reviewer could not verify command evidence from diff; controller independently reran the combined comparator/manifest/golden suite and confirmed 68/68 PASS.
- Task 2 round 1: Needs fixes. Critical: role-aware atomic/composite writers reported but did not enforce feature-edge and residual metrics, creating a false-pass path. Important: absent assigned role could throw uncaught `StateError`; reasoned system-status SKIP rows were missing. Minor: documentation still said status-mask height 40 instead of 41. Fix round 1 assigned to the same implementer.
- Task 2 fix round 1: BLOCKED after two bounded estimator designs. The exact layered design failed the real shadow while adversarial tests stayed strict; its experiment was removed and not committed. Fix round 2 is split into a smaller hierarchical-ownership/shadow subtask for a fresh implementer, with only one implementation agent active.
- Task 2 fix round 2 amendment: atomic coverage contract is GREEN on 30/30 adversarial fixtures, but bounded production calibration is BLOCKED across the seven separately decoded JPEGs. Final production output passes 6/35 icon leaves and 0/35 labels; the same Trade geometry ranges from `3/653` PASS to `35/651` FAIL across captures. Production tuning stopped pending a reviewer ruling on reference-only multi-JPEG consensus; no thresholds, masks, coordinate rescaling, or candidate calibration changed.
- Task 2 fix round 2 consensus amendment: the reference-only immutable consensus contract is GREEN on 33/33 focused fixtures and covers 18 keys / 70 memberships with strict majority and deterministic median-with-zero provenance. Bounded production reaches 10/70 atomic PASS (10/35 icons, 0/35 labels). Variable/plain weight tuning makes representative label mass nearly exact while immutable support remains `8.434–11.521%`; condensed and static Roboto probes are worse, and three measured Settings shapes remain `11.036–20.000%`. This is the approved fixed-consensus stop; surfaces/shadows were not tuned and no completion commit was created.

## Evidence and blockers

- Task 1 implementer report: `task-1-report.md`.
- Task 1 review package: `review-30f2841..c59815e.diff`.
- Remaining known baseline failure: Chart timeframe transition expected `4429.0`, actual `4425.0`; owned by Task 6.
- Task 2 pre-stage owner asset SHA-256:
  - `Roboto-Variable.ttf`: `d7598e12c5dbef095ff8272cfc55da0250bd07fbdecbac8a530b9b277872a134`
  - `RobotoCondensed-Variable.ttf`: `dace262afcee68a5276f200d8026c57221735c0118ab5fda8c2c0d3dc409a8d0`
  - `assets/fonts/README.md`: `a8396d83d00bd7b0a57922147c502b363a0f3d26153b6f45421b11dc7554e5f8`
  - `OFL-Roboto.txt`: `061402327a96aadb0bfb694a960ed289ecd38d383e396243831ab81feb109c41`
  - `LICENSE-RobotoCondensed-Apache-2.0.txt`: `c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4`
2026-08-27 Task 2 fix round 2: hierarchical atomic/surface/shadow ownership is implemented. Canonical result is verification-deferred, never PASS: atomic 10 PASS/60 FAIL, surfaces 7 capsule PASS/7 pill FAIL, shadows 0 PASS/21 FAIL, navigation total 17 PASS/102 FAIL, system 5 PASS/2 FAIL, status 14 reasoned SKIP. Atomic exact FNV rolled once from 972f9b7dd0ef333e to -fe9fe9695ab2bc3 solely for equivalent maximum-pair coordinate ordering; normalized metric/gate/provenance FNV is 050c4c5ec79384e9. Surface evidence FNV is 6f3fdb15f2e40d7b. Task 7 requires the lossless shared navigation source and removes all reference-evidence deferrals.
