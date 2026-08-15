# Settings Messages Icon Video-Parity Design

## Goal

Match the `Trao doi va tin nhan` icon and its notification badge to `giaoDienMau/IMG_5526.MP4` while keeping the badge count driven by server state.

## Evidence and root cause

- The reference frame at approximately 12.8 seconds shows a clean blue rounded-square MT5 messages tile with a white thumbs-up glyph. A red circular badge is rendered independently over its upper-right corner.
- The current `messages` entry in `_videoEncoded` is a 43 x 44 crop that already contains a red badge with the number `2`.
- `_SettingsRow` then renders the live notification badge over that raster. The baked badge can leak around or disagree with the dynamic badge and therefore cannot match the reference reliably.
- The existing 20 x 20 official MT5 `messages` raster is clean and contains only the blue tile and white glyph.

## Design

Use the clean official MT5 messages raster as the sole icon artwork. Remove the badge-contaminated messages override from `_videoEncoded`, allowing the existing clean `_encoded` asset and high-quality scaling path to render the icon.

Keep the existing 29 x 29 icon frame, 21 x 21 notification badge, badge offset, row layout, navigation, and connected indicator unless device capture shows an evidence-backed subpixel difference. The notification number remains dynamic; it must not be embedded into the icon or fixed to the sample value `3`.

## Test strategy

Add a widget-level pixel regression test that renders `MtSettingsRasterIconKind.messages` without a notification badge and decodes the actual `MemoryImage`. The test must verify that the upper-right icon artwork contains no badge-red pixels. This fails against the contaminated 43 x 44 raster and passes only when the delivered icon is clean.

Retain the existing Settings layout tests for the 29 x 29 frame, 21 x 21 badge, and badge origin. This separates artwork correctness from overlay geometry.

## Scope

Only the messages icon artwork and evidence-backed badge alignment are in scope. Other Settings icons, server unread-count behavior, account data, navigation, and the technology stack remain unchanged.

## Verification

- Focused icon artwork and Settings navigation tests.
- Full Flutter analyzer and test suite.
- Android debug APK build.
- Backend build and tests as required by repository instructions.
- Portrait device screenshot compared with the 12.8-second reference frame; pixel-perfect parity is not claimed without this capture.
