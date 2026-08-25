# Settings

## Reference

- File: `giaoDienMau/IMG_5526.MP4`
- Captured viewport: 288 × 640 pixels
- Device style: iOS dark appearance

## Layout

- Safe-area title centered above the content.
- Three rounded dark cards with 19 logical-pixel vertical gaps.
- First card contains the active-account summary and four rows.
- Second card contains messaging/community rows.
- Third card contains OTP, interface, chart, journal, and settings rows.
- Bottom navigation is supplied by the shared app shell and is not owned by this screen.

## Settings root reference

- Video timestamps: 12.8-14.2 seconds and 21.3 seconds.
- Comparison viewport: native 576 × 1280, normalized to 288 × 640 logical pixels.
- The account header shows name, company, account/server, and access point on four centered lines.
- The connected indicator is a blue gradient circle with three light signal strokes.

## Account list reference

- Video timestamps: 0.0-1.4 seconds and 22.7 seconds.
- The selected account uses a yellow Exness mark, blue name, live account/server line, balance/currency/mode line, and a right chevron.
- Back and add actions use 43 logical-pixel circular hit targets.
- Production shows only the account authorized by the device token.

## Account detail reference

- Video timestamps: 2.8-9.9 seconds and 24.1-26.5 seconds.
- The page contains broker hero, company, deposit/withdraw, profile, and security groups in that order.
- Company, trading server, and connected access point match the Settings root.
- The view scrolls with bouncing physics to expose the security group.

## API-owned content

- Active-account name and account code.
- Balance, currency, owner name, email, and phone.
- Unread notification badge count.
- Language/locale subtitle when returned by EX V2.

Personal and financial values must not be replaced with strings copied from the video. Broker metadata resolves from canonical settings fields and then falls back to `Exness Technologies Ltd`, `Exness-MT5Real20`, and `Access Point #9`; `active`, `trochoi.top`, and `EX V2` are not valid broker metadata.

## Static reference copy

- `Cai dat`
- `Tai khoan moi`
- `Hop thu` / `You have registered a new acco...`
- `Tin tuc` / `Australian Dollar: RBA keeps hik...`
- `Tradays` / `Lich Kinh Te`
- `Trao doi va tin nhan` / `Dang nhap vao cong dong MQ...`
- `Cong dong trader`
- `MQL5 Algo Trading`
- `OTP` / `Khoi tao mat khau mot lan`
- `Giao dien` / API language, falling back to `Tieng Viet`
- `Nhung bieu do`
- `Nhat ky`
- `Cai dat`

## Components

- Card radius: 24 logical pixels in the current Android rendering, matching the normalized video silhouette.
- Row icon frame: 29 × 29 logical pixels.
- Messaging badge: 21 × 21 logical pixels, positioned over the upper-right corner of the left icon.
- All twelve row icons use code-native vector glyphs inside 29 x 29 rounded color tiles; no bitmap is scaled into the icon frame.
- The messaging tile contains only the blue tile and white thumbs-up glyph; the unread badge is always rendered separately from the server-owned count.
- Connected status: a blue circular signal glyph with three light strokes, 28 logical pixels inside a 29 × 29 frame.
- Dividers use the semantic `AppColors.divider` token.

## Interactions

- Account summary opens `/profile`.
- Mail and messaging rows open `/messages`.
- Existing section and chart routes remain unchanged.
- The list keeps bouncing/always-scrollable behavior.

## Assumptions

- The iOS AssistiveTouch overlay visible in the recording is not application UI and must not be reproduced.
- iOS status bars, Dynamic Island, screenshot editor, and share sheet are excluded from application comparison.
- Static snippets match the recording until the backend provides canonical message/news snippets.
- No proprietary bitmap logo is introduced; simple marks and the connected indicator are recreated with code-native geometry.
