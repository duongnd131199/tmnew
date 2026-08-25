# META-TRADER-STYLE APP CLONE — CODEX IMPLEMENTATION GUIDE

> Tài liệu này dùng làm chỉ dẫn chính cho Codex khi xây dựng một ứng dụng giao dịch tài chính có giao diện và luồng sử dụng tương tự MetaTrader.
>
> Mục tiêu là tái tạo trải nghiệm, bố cục và chức năng tương đương ở mức hợp pháp; không sao chép logo, tên thương hiệu, mã nguồn, tài nguyên độc quyền hoặc dữ liệu không được cấp phép.

---

# 1. Mục tiêu dự án

Xây dựng ứng dụng mobile giao dịch tài chính hỗ trợ:

- Đăng ký, đăng nhập và quản lý phiên đăng nhập.
- Danh sách mã giao dịch theo thời gian thực.
- Biểu đồ nến và nhiều khung thời gian.
- Đặt lệnh Buy/Sell.
- Lệnh chờ.
- Stop Loss và Take Profit.
- Quản lý vị thế đang mở.
- Theo dõi Balance, Equity, Margin và Profit/Loss.
- Lịch sử giao dịch.
- Ví nạp/rút tiền.
- Thông báo realtime.
- Trang quản trị.
- Hỗ trợ Android trước, sau đó mở rộng sang iOS.

---

# 2. Công nghệ bắt buộc

## 2.1 Mobile app

- Flutter.
- Dart.
- Riverpod để quản lý state.
- GoRouter để điều hướng.
- Dio để gọi REST API.
- SignalR Client hoặc WebSocket để nhận dữ liệu realtime.
- Flutter Secure Storage để lưu access token và refresh token.
- Drift hoặc SQLite để lưu dữ liệu cục bộ.
- Freezed và json_serializable cho model.
- WebView để nhúng biểu đồ tài chính.
- TradingView Lightweight Charts cho biểu đồ.
- Firebase Cloud Messaging cho push notification.

## 2.2 Backend

- ASP.NET Core Web API.
- Entity Framework Core.
- SQL Server.
- Redis.
- SignalR.
- JWT Access Token.
- Refresh Token.
- ASP.NET Core Identity hoặc hệ thống xác thực riêng.
- BackgroundService cho market feed và xử lý nền.
- Serilog cho logging.
- FluentValidation cho validate request.
- Swagger/OpenAPI.
- Docker.
- Nginx.

## 2.3 Hạ tầng

- Ubuntu Server.
- Docker Compose.
- Nginx reverse proxy.
- SQL Server.
- Redis.
- HTTPS.
- CI/CD bằng GitHub Actions hoặc quy trình deploy tương đương.

---

# 3. Nguyên tắc làm việc dành cho Codex

Codex phải tuân thủ các nguyên tắc sau:

1. Đọc toàn bộ tài liệu này trước khi sửa code.
2. Không tự thay đổi stack công nghệ.
3. Không viết toàn bộ dự án trong một file.
4. Không hard-code màu sắc, spacing, font, URL API hoặc key bí mật.
5. Mỗi chức năng phải tách theo module.
6. Mỗi màn hình phải có trạng thái:
   - Loading.
   - Success.
   - Empty.
   - Error.
   - Reconnecting nếu có realtime.
7. Sau mỗi task phải chạy:
   - `flutter analyze`
   - `flutter test`
   - `dotnet build`
   - `dotnet test`
8. Không sửa module không liên quan nếu không cần thiết.
9. Mọi API thay đổi phải cập nhật OpenAPI.
10. Mọi migration phải có tên rõ ràng.
11. Không log access token, refresh token, mật khẩu hoặc thông tin tài chính nhạy cảm.
12. Không tạo dữ liệu giao dịch thật nếu chưa kết nối nguồn dữ liệu được cấp phép.
13. Nếu thiếu thông tin từ ảnh mẫu, phải ghi rõ giả định trong báo cáo.
14. Trước khi hoàn thành task, phải tự kiểm tra giao diện bằng ảnh chụp từ emulator.
15. Khi clone giao diện, ưu tiên độ chính xác về:
    - Kích thước.
    - Khoảng cách.
    - Font.
    - Màu sắc.
    - Bo góc.
    - Border.
    - Icon.
    - Trạng thái tương tác.
    - Chuyển động.
    - Điều hướng.

---

# 4. Phạm vi MVP

MVP phải hoàn thành các module sau.

## 4.1 Authentication

- Splash screen.
- Login.
- Register.
- Forgot password.
- OTP.
- Refresh token.
- Logout.
- Device session.
- Session expiration.
- Biometric unlock là tùy chọn giai đoạn sau.

## 4.2 Market Watch

- Danh sách symbol.
- Bid.
- Ask.
- Spread.
- Giá thay đổi theo thời gian thực.
- Màu tăng/giảm.
- Danh sách yêu thích.
- Tìm kiếm symbol.
- Thêm/xóa symbol.
- Sắp xếp symbol.
- Mở nhanh trang chart.
- Mở nhanh trang đặt lệnh.

## 4.3 Chart

- Candlestick.
- Line chart.
- Bar chart.
- M1, M5, M15, M30, H1, H4, D1, W1, MN.
- Zoom.
- Pan.
- Crosshair.
- OHLC.
- Volume.
- Grid.
- Bid line.
- Ask line.
- Hiển thị vị thế trên chart.
- Hiển thị SL/TP.
- Indicator cơ bản:
  - MA.
  - EMA.
  - RSI.
  - MACD.
  - Bollinger Bands.
- Công cụ vẽ giai đoạn sau:
  - Trendline.
  - Horizontal line.
  - Vertical line.
  - Fibonacci.

## 4.4 Order

- Market Buy.
- Market Sell.
- Buy Limit.
- Sell Limit.
- Buy Stop.
- Sell Stop.
- Stop Loss.
- Take Profit.
- Modify Order.
- Close Order.
- Partial Close.
- Confirm order.
- Chống gửi lệnh trùng.
- Hiển thị trạng thái xử lý.
- Hiển thị lỗi rõ ràng.

## 4.5 Trade

- Balance.
- Equity.
- Margin.
- Free Margin.
- Margin Level.
- Floating Profit/Loss.
- Danh sách position.
- Danh sách pending order.
- Chi tiết position.
- Modify position.
- Close position.

## 4.6 History

- Danh sách deal.
- Danh sách order đã đóng.
- Lọc theo ngày.
- Lọc theo symbol.
- Tổng Profit/Loss.
- Tổng phí.
- Chi tiết giao dịch.

## 4.7 Wallet

- Số dư.
- Deposit request.
- Withdraw request.
- Lịch sử giao dịch ví.
- Trạng thái xử lý.
- Admin duyệt nạp/rút trong bản demo.
- Không tích hợp thanh toán thật trong MVP nếu chưa có yêu cầu pháp lý.

## 4.8 Profile

- Thông tin tài khoản.
- Đổi mật khẩu.
- Cài đặt giao diện.
- Cài đặt thông báo.
- Quản lý thiết bị.
- Ngôn ngữ.
- Logout.

## 4.9 Admin

- Quản lý user.
- Khóa/mở user.
- Quản lý trading account.
- Quản lý symbol.
- Quản lý spread.
- Quản lý leverage.
- Quản lý lệnh.
- Quản lý position.
- Duyệt deposit.
- Duyệt withdraw.
- Quản lý thông báo.
- Audit log.
- Dashboard thống kê.

---

# 5. Kiến trúc tổng thể

```text
Flutter Mobile App
    |
    |-- REST API
    |-- SignalR / WebSocket
    |
ASP.NET Core API
    |
    |-- Auth Module
    |-- User Module
    |-- Market Module
    |-- Order Module
    |-- Position Module
    |-- Wallet Module
    |-- Notification Module
    |-- Admin Module
    |
    |-- SQL Server
    |-- Redis
    |-- Market Data Adapter
```

## 5.1 Luồng market data

```text
Market Data Provider
    -> Market Feed Worker
    -> Chuẩn hóa tick
    -> Redis lưu giá mới nhất
    -> Candle Aggregator
    -> SignalR Hub
    -> Flutter App
```

## 5.2 Luồng đặt lệnh

```text
Người dùng nhấn Buy/Sell
    -> Mobile tạo ClientOrderId
    -> Gửi OrderRequest
    -> API xác thực người dùng
    -> Kiểm tra symbol
    -> Kiểm tra market status
    -> Kiểm tra giá
    -> Kiểm tra lot
    -> Kiểm tra margin
    -> Kiểm tra idempotency
    -> Tạo order
    -> Khớp lệnh giả lập hoặc gửi broker
    -> Tạo position/deal
    -> Cập nhật account
    -> Gửi realtime result về app
```

---

# 6. Cấu trúc Flutter

```text
mobile/
├── assets/
│   ├── fonts/
│   ├── icons/
│   ├── images/
│   └── chart/
├── lib/
│   ├── app/
│   │   ├── app.dart
│   │   ├── router.dart
│   │   ├── bootstrap.dart
│   │   └── dependencies.dart
│   ├── core/
│   │   ├── config/
│   │   ├── constants/
│   │   ├── errors/
│   │   ├── extensions/
│   │   ├── network/
│   │   ├── realtime/
│   │   ├── storage/
│   │   ├── theme/
│   │   ├── utils/
│   │   └── widgets/
│   ├── shared/
│   │   ├── models/
│   │   ├── providers/
│   │   └── widgets/
│   ├── features/
│   │   ├── authentication/
│   │   ├── market_watch/
│   │   ├── chart/
│   │   ├── order/
│   │   ├── trade/
│   │   ├── history/
│   │   ├── wallet/
│   │   ├── notifications/
│   │   └── profile/
│   └── main.dart
├── test/
├── integration_test/
├── pubspec.yaml
└── README.md
```

## 6.1 Cấu trúc mỗi feature

```text
feature_name/
├── data/
│   ├── data_sources/
│   ├── dto/
│   ├── mappers/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── use_cases/
└── presentation/
    ├── controllers/
    ├── providers/
    ├── screens/
    └── widgets/
```

---

# 7. Cấu trúc Backend

```text
backend/
├── src/
│   ├── Trading.Api/
│   ├── Trading.Application/
│   ├── Trading.Domain/
│   ├── Trading.Infrastructure/
│   ├── Trading.Realtime/
│   └── Trading.Workers/
├── tests/
│   ├── Trading.UnitTests/
│   ├── Trading.IntegrationTests/
│   └── Trading.ArchitectureTests/
├── docker-compose.yml
└── Trading.sln
```

## 7.1 Domain chính

```text
User
TradingAccount
Symbol
Quote
Candle
Order
Position
Deal
Wallet
WalletTransaction
DepositRequest
WithdrawRequest
Notification
DeviceSession
AuditLog
```

---

# 8. Database

## 8.1 Bảng người dùng

```text
Users
- Id
- Email
- PhoneNumber
- PasswordHash
- FullName
- Status
- CreatedAt
- UpdatedAt

DeviceSessions
- Id
- UserId
- DeviceId
- RefreshTokenHash
- IpAddress
- UserAgent
- ExpiresAt
- RevokedAt
- CreatedAt
```

## 8.2 Tài khoản giao dịch

```text
TradingAccounts
- Id
- UserId
- AccountNumber
- AccountType
- Currency
- Balance
- Equity
- Margin
- FreeMargin
- Leverage
- Status
- CreatedAt
- UpdatedAt
```

## 8.3 Symbol

```text
Symbols
- Id
- Code
- Name
- BaseCurrency
- QuoteCurrency
- Digits
- ContractSize
- MinLot
- MaxLot
- LotStep
- SpreadMode
- FixedSpread
- IsTradable
- CreatedAt
- UpdatedAt
```

## 8.4 Order

```text
Orders
- Id
- ClientOrderId
- TradingAccountId
- SymbolId
- OrderType
- Side
- Volume
- RequestedPrice
- ExecutedPrice
- StopLoss
- TakeProfit
- Status
- RejectionReason
- CreatedAt
- ExecutedAt
- ClosedAt
```

## 8.5 Position

```text
Positions
- Id
- TradingAccountId
- SymbolId
- Side
- Volume
- OpenPrice
- CurrentPrice
- StopLoss
- TakeProfit
- FloatingProfit
- Status
- OpenedAt
- ClosedAt
```

## 8.6 Deal

```text
Deals
- Id
- TradingAccountId
- OrderId
- PositionId
- SymbolId
- Side
- Volume
- Price
- Profit
- Commission
- Swap
- CreatedAt
```

## 8.7 Wallet Ledger

```text
WalletTransactions
- Id
- WalletId
- Type
- Amount
- BalanceBefore
- BalanceAfter
- ReferenceId
- Status
- Description
- CreatedAt
```

Không cập nhật số dư theo cách cộng/trừ tùy ý mà không tạo ledger.

---

# 9. Redis Key Convention

```text
quote:{symbol}
candle:{symbol}:{timeframe}
market:status
account:summary:{accountId}
connection:user:{userId}
session:{sessionId}
order:idempotency:{accountId}:{clientOrderId}
```

---

# 10. API dự kiến

## Authentication

```text
POST /api/auth/register
POST /api/auth/login
POST /api/auth/refresh
POST /api/auth/logout
POST /api/auth/forgot-password
POST /api/auth/verify-otp
GET  /api/auth/sessions
DELETE /api/auth/sessions/{id}
```

## Market

```text
GET /api/market/symbols
GET /api/market/symbols/{symbol}
GET /api/market/candles
GET /api/market/watchlist
POST /api/market/watchlist
DELETE /api/market/watchlist/{symbol}
```

## Orders

```text
POST /api/orders
GET /api/orders
GET /api/orders/{id}
PUT /api/orders/{id}
POST /api/orders/{id}/close
POST /api/orders/{id}/partial-close
DELETE /api/orders/{id}
```

## Trading Account

```text
GET /api/trading-accounts
GET /api/trading-accounts/{id}
GET /api/trading-accounts/{id}/summary
GET /api/trading-accounts/{id}/positions
GET /api/trading-accounts/{id}/history
```

## Wallet

```text
GET /api/wallet
GET /api/wallet/transactions
POST /api/wallet/deposits
POST /api/wallet/withdrawals
GET /api/wallet/deposits
GET /api/wallet/withdrawals
```

## Admin

```text
GET  /api/admin/users
PUT  /api/admin/users/{id}/status
GET  /api/admin/orders
GET  /api/admin/positions
GET  /api/admin/deposits
PUT  /api/admin/deposits/{id}/approve
PUT  /api/admin/deposits/{id}/reject
GET  /api/admin/withdrawals
PUT  /api/admin/withdrawals/{id}/approve
PUT  /api/admin/withdrawals/{id}/reject
```

---

# 11. SignalR Events

## Client gửi lên

```text
SubscribeSymbols
UnsubscribeSymbols
SubscribeAccount
UnsubscribeAccount
SubscribeChart
UnsubscribeChart
```

## Server gửi xuống

```text
QuoteUpdated
CandleUpdated
OrderUpdated
PositionUpdated
AccountSummaryUpdated
WalletUpdated
NotificationReceived
ConnectionStatusChanged
```

## Quote payload

```json
{
  "symbol": "XAUUSD",
  "bid": 3345.20,
  "ask": 3345.65,
  "timestamp": "2026-07-17T07:00:00Z"
}
```

## Candle payload

```json
{
  "symbol": "XAUUSD",
  "timeframe": "M1",
  "time": 1784267100,
  "open": 3345.20,
  "high": 3346.80,
  "low": 3344.90,
  "close": 3346.15,
  "volume": 1200
}
```

---

# 12. Biểu đồ

## 12.1 Kiến trúc chart

```text
Flutter Screen
    -> WebView Controller
    -> JavaScript Bridge
    -> TradingView Lightweight Charts
```

## 12.2 Yêu cầu chart

- Chỉ tạo chart một lần.
- Không reload toàn bộ chart khi có tick mới.
- Cập nhật cây nến hiện tại bằng `series.update`.
- Chỉ tải lịch sử khi người dùng kéo về quá khứ.
- Debounce các thao tác gửi dữ liệu qua bridge.
- Không gửi toàn bộ danh sách candle ở mỗi tick.
- Dữ liệu candle phải được sort theo thời gian.
- Không gửi candle trùng timestamp.
- Khi đổi timeframe:
  - Hủy subscription cũ.
  - Xóa series cũ.
  - Tải lịch sử mới.
  - Subscribe timeframe mới.
- Phải có trạng thái mất kết nối.
- Phải hiển thị giá Bid/Ask hiện tại.
- Phải giữ vị trí zoom khi cập nhật tick.

---

# 13. Design System

Tạo các file:

```text
lib/core/theme/
├── app_colors.dart
├── app_typography.dart
├── app_spacing.dart
├── app_radius.dart
├── app_shadows.dart
├── app_icons.dart
└── app_theme.dart
```

## 13.1 Quy tắc

- Không dùng màu trực tiếp trong widget.
- Không dùng `TextStyle` rải rác.
- Không dùng spacing số lẻ không có token.
- Không hard-code kích thước icon.
- Tất cả màn hình phải dùng cùng design system.
- Hỗ trợ dark mode trước.
- Light mode là giai đoạn sau.

## 13.2 Token mẫu

```text
Spacing:
4, 8, 12, 16, 20, 24, 32

Radius:
4, 8, 12, 16, 24

Text:
caption
bodySmall
bodyMedium
bodyLarge
titleSmall
titleMedium
titleLarge
numberSmall
numberMedium
numberLarge
```

---

# 14. Danh sách màn hình cần clone

## Giai đoạn 1

```text
01_splash
02_login
03_register
04_market_watch
05_symbol_search
06_chart
07_new_order
08_trade
09_position_detail
10_order_modify
11_history
12_history_detail
13_wallet
14_deposit
15_withdraw
16_profile
17_settings
18_notifications
```

## Giai đoạn 2

```text
19_indicator_list
20_indicator_settings
21_chart_objects
22_account_switch
23_device_sessions
24_security
25_admin_dashboard
```

---

# 15. Quy trình clone từng màn hình

Với mỗi màn hình, Codex phải làm đúng thứ tự sau:

1. Đọc ảnh mẫu.
2. Xác định:
   - Kích thước viewport.
   - Safe area.
   - App bar.
   - Bottom navigation.
   - Màu nền.
   - Typography.
   - Khoảng cách.
   - Icon.
   - Border.
   - Shadow.
   - Trạng thái tương tác.
3. Tạo bản mô tả màn hình trong `docs/screens`.
4. Dựng giao diện tĩnh.
5. Dùng dữ liệu giả.
6. Chạy trên LDPlayer.
7. Chụp ảnh màn hình.
8. So sánh với ảnh mẫu.
9. Chỉnh sai lệch.
10. Thêm state.
11. Kết nối API.
12. Thêm test.
13. Ghi báo cáo thay đổi.

## Template mô tả màn hình

```markdown
# Screen Name

## Reference

- File ảnh:
- Kích thước:
- Thiết bị:

## Layout

- AppBar:
- Body:
- Bottom navigation:
- Scroll behavior:

## Components

- Component 1:
- Component 2:

## States

- Loading:
- Empty:
- Error:
- Success:

## Interactions

- Tap:
- Swipe:
- Long press:
- Back:

## Assumptions

- ...
```

---

# 16. Mock Data

Tạo chế độ mock để frontend có thể chạy khi backend chưa hoàn thành.

```text
AppConfig.useMockData = true
```

Mock phải có:

- Giá tăng.
- Giá giảm.
- Mất kết nối.
- Market đóng cửa.
- Không có position.
- Có nhiều position.
- Lệnh thành công.
- Lệnh thất bại.
- Không đủ margin.
- Symbol không giao dịch.
- Deposit đang xử lý.
- Withdraw bị từ chối.

---

# 17. Bảo mật

- HTTPS bắt buộc.
- Không lưu mật khẩu dạng plain text.
- Refresh token lưu dạng hash ở server.
- Access token thời gian sống ngắn.
- Có cơ chế revoke session.
- Rate limit:
  - Login.
  - OTP.
  - Place order.
  - Withdraw.
- Mỗi request tài chính phải có correlation ID.
- Đặt lệnh phải có idempotency key.
- Dữ liệu tiền dùng `decimal`, không dùng `float`.
- Thời gian lưu UTC.
- Không tin dữ liệu giá do client gửi.
- Không tính Balance, Equity hoặc Profit ở client làm nguồn chính.
- Không cho client tự quyết trạng thái order.
- Audit mọi thao tác:
  - Login.
  - Logout.
  - Place order.
  - Modify.
  - Close.
  - Deposit.
  - Withdraw.
  - Admin approve/reject.

---

# 18. Hiệu năng

## Mobile

- Không rebuild toàn bộ danh sách Market Watch khi một symbol thay đổi.
- Mỗi symbol có provider hoặc state riêng phù hợp.
- Dùng ListView builder.
- Giới hạn số lần render mỗi giây.
- Không ghi SQLite ở mỗi tick.
- Không cập nhật UI nếu giá không đổi.
- Hủy subscription khi màn hình dispose.
- Không giữ WebView khi màn hình không cần thiết nếu gây tốn RAM.

## Backend

- Redis dùng cho giá mới nhất.
- Không ghi mỗi tick vào SQL Server.
- Candle history dùng batch insert.
- SignalR group theo symbol.
- SignalR group theo account.
- Không broadcast toàn bộ symbol cho mọi client.
- Dùng cancellation token.
- Dùng background queue cho tác vụ nặng.
- Đặt index cho các trường tìm kiếm thường xuyên.

---

# 19. Testing

## Flutter Unit Test

- Auth controller.
- Market state.
- Order validation.
- Account summary.
- Number formatting.
- Profit color.
- Reconnect logic.

## Flutter Widget Test

- Login.
- Market Watch.
- New Order.
- Trade.
- History.
- Wallet.

## Integration Test

- Login.
- Mở Market Watch.
- Mở chart.
- Đặt lệnh demo.
- Xem position.
- Đóng position.
- Xem history.
- Logout.

## Backend Unit Test

- Margin calculation.
- Profit calculation.
- Order validation.
- Idempotency.
- Wallet ledger.
- Authorization.

## Backend Integration Test

- Login/refresh.
- Create order.
- Modify order.
- Close position.
- Deposit workflow.
- Withdraw workflow.
- SignalR authorization.

---

# 20. Công thức nghiệp vụ bản demo

## Profit

```text
Buy:
Profit = (CurrentPrice - OpenPrice) × ContractSize × Volume

Sell:
Profit = (OpenPrice - CurrentPrice) × ContractSize × Volume
```

## Margin đơn giản

```text
Margin = ContractSize × Volume × Price / Leverage
```

## Equity

```text
Equity = Balance + FloatingProfit
```

## Free Margin

```text
FreeMargin = Equity - Margin
```

Các công thức thực tế có thể khác theo loại tài sản, currency conversion và broker. Không dùng trực tiếp cho giao dịch thật nếu chưa được kiểm chứng.

---

# 21. Lộ trình triển khai

## Phase 0 — Chuẩn bị

- Khởi tạo monorepo.
- Tạo Flutter app.
- Tạo .NET solution.
- Tạo Docker Compose.
- Tạo design system.
- Tạo mock data.
- Cấu hình môi trường dev.

## Phase 1 — UI Clone

- Splash.
- Login.
- Market Watch.
- Chart.
- New Order.
- Trade.
- History.
- Wallet.
- Profile.

Chưa kết nối giao dịch thật.

## Phase 2 — Backend Core

- Auth.
- User.
- Trading Account.
- Symbol.
- Orders.
- Positions.
- Deals.
- Wallet.
- Admin.

## Phase 3 — Realtime

- Market Feed Worker.
- Redis.
- SignalR.
- Quote subscription.
- Candle update.
- Account update.
- Reconnect.

## Phase 4 — Trading Demo

- Market execution.
- Pending orders.
- SL/TP.
- Close.
- Partial close.
- Margin validation.
- Profit calculation.
- History.

## Phase 5 — Admin

- User management.
- Order management.
- Position management.
- Symbol management.
- Deposit/withdraw approval.
- Audit log.

## Phase 6 — Hardening

- Security review.
- Performance test.
- Integration test.
- Crash reporting.
- Monitoring.
- Backup.
- Deploy.

---

# 22. Definition of Done

Một task chỉ được coi là hoàn thành khi:

- Build thành công.
- Không có lỗi analyzer nghiêm trọng.
- Test liên quan chạy thành công.
- Có xử lý loading/error/empty.
- Có responsive cho màn hình 360–430 logical pixels.
- Không hard-code token hoặc API key.
- Không có code thừa rõ ràng.
- Không phá vỡ module khác.
- Có ảnh chụp emulator.
- Có báo cáo file đã sửa.
- Có hướng dẫn test thủ công.
- Có ghi rõ giới hạn hoặc giả định.

---

# 23. Checklist nghiệm thu UI

- [ ] Màu nền đúng.
- [ ] Font đúng.
- [ ] Font weight đúng.
- [ ] Kích thước chữ đúng.
- [ ] Line height đúng.
- [ ] Icon đúng kích thước.
- [ ] Khoảng cách đúng.
- [ ] Border đúng.
- [ ] Radius đúng.
- [ ] App bar đúng.
- [ ] Bottom navigation đúng.
- [ ] Trạng thái selected đúng.
- [ ] Scroll đúng.
- [ ] Loading đúng.
- [ ] Empty đúng.
- [ ] Error đúng.
- [ ] Dark mode không bị lệch màu.
- [ ] Không overflow trên màn hình nhỏ.
- [ ] Bàn phím không che input.
- [ ] Nút Back hoạt động đúng.
- [ ] Chụp ảnh so sánh đã được thực hiện.

---

# 24. Checklist nghiệm thu giao dịch

- [ ] Không gửi lệnh khi chưa đăng nhập.
- [ ] Không gửi lot ngoài min/max.
- [ ] Lot tuân theo step.
- [ ] Không gửi lệnh khi market đóng.
- [ ] Không gửi lệnh trùng ClientOrderId.
- [ ] Không cho client tự đặt executed price.
- [ ] Server kiểm tra margin.
- [ ] Server kiểm tra symbol.
- [ ] Có audit log.
- [ ] Có trạng thái Pending/Accepted/Rejected/Filled.
- [ ] Có xử lý timeout.
- [ ] Có xử lý mất kết nối.
- [ ] Có retry phù hợp.
- [ ] Không retry tự động Place Order nếu không dùng idempotency.
- [ ] Position cập nhật realtime.
- [ ] Balance và Equity cập nhật đúng.
- [ ] History ghi nhận deal.
- [ ] Close position tạo deal đóng.
- [ ] Partial close cập nhật volume đúng.

---

# 25. Prompt khởi tạo dự án cho Codex

```text
Bạn đang xây dựng một ứng dụng giao dịch tài chính mobile có trải nghiệm tương tự MetaTrader.

Hãy đọc toàn bộ file META_TRADER_CLONE_GUIDE.md trước khi thực hiện.

Yêu cầu:
1. Tạo monorepo gồm mobile Flutter và backend ASP.NET Core.
2. Mobile dùng Flutter, Riverpod, GoRouter, Dio, Secure Storage và WebView.
3. Backend dùng ASP.NET Core Web API, EF Core, SQL Server, Redis và SignalR.
4. Tạo cấu trúc thư mục đúng tài liệu.
5. Tạo Docker Compose cho SQL Server và Redis.
6. Tạo design system dark mode.
7. Tạo mock data service.
8. Tạo README hướng dẫn chạy.
9. Chưa triển khai giao dịch thật.
10. Sau khi hoàn thành, chạy build và test cơ bản.
11. Báo cáo file tạo mới, lệnh chạy và các bước tiếp theo.
```

---

# 26. Prompt clone một màn hình

```text
Hãy đọc META_TRADER_CLONE_GUIDE.md.

Triển khai màn hình [TÊN MÀN HÌNH] dựa trên ảnh:
reference/screens/[TÊN FILE ẢNH].

Yêu cầu:
1. Phân tích bố cục từ ảnh.
2. Ghi mô tả vào docs/screens/[screen-name].md.
3. Dùng design token, không hard-code style.
4. Tách widget tái sử dụng.
5. Tạo đủ Loading, Empty, Error và Success.
6. Dùng mock data.
7. Responsive từ 360 đến 430 logical pixels.
8. Không tự thay đổi thiết kế.
9. Chạy flutter analyze và flutter test.
10. Chụp màn hình trên LDPlayer.
11. So sánh với ảnh mẫu và chỉnh sai lệch.
12. Báo cáo phần nào chưa xác định chính xác.
```

---

# 27. Prompt triển khai Market Watch

```text
Hãy đọc META_TRADER_CLONE_GUIDE.md.

Triển khai module Market Watch.

Yêu cầu:
1. Danh sách symbol có Bid, Ask, Spread và trạng thái tăng/giảm.
2. Dữ liệu mock cập nhật realtime.
3. Không rebuild toàn bộ danh sách khi một symbol đổi giá.
4. Có search, favorite, add/remove symbol.
5. Tap symbol mở menu hành động.
6. Có hành động mở chart và new order.
7. Có loading, empty, error và reconnecting.
8. Tạo unit test cho state update.
9. Tạo widget test cho danh sách.
10. Chạy analyze và test.
```

---

# 28. Prompt triển khai Chart

```text
Hãy đọc META_TRADER_CLONE_GUIDE.md.

Triển khai module Chart bằng Flutter WebView và TradingView Lightweight Charts.

Yêu cầu:
1. Tạo chart HTML/JS trong assets/chart.
2. Hỗ trợ candlestick, line và bar.
3. Hỗ trợ M1, M5, M15, M30, H1, H4, D1.
4. Hỗ trợ zoom, pan, crosshair và OHLC.
5. Dữ liệu candle lấy từ mock service trước.
6. Chỉ update candle mới nhất, không reload chart.
7. Tạo JavaScript bridge rõ ràng.
8. Khi đổi timeframe phải hủy subscription cũ.
9. Hiển thị trạng thái mất kết nối.
10. Không gửi toàn bộ candle list mỗi tick.
11. Viết test cho candle aggregation và bridge payload.
12. Chạy analyze và test.
```

---

# 29. Prompt triển khai Order

```text
Hãy đọc META_TRADER_CLONE_GUIDE.md.

Triển khai module New Order.

Yêu cầu:
1. Hỗ trợ Market Buy và Market Sell trước.
2. Có symbol, volume, price, SL và TP.
3. Validate min lot, max lot và lot step.
4. Tạo ClientOrderId duy nhất.
5. Ngăn double tap gửi lệnh trùng.
6. Có trạng thái submitting.
7. Hiển thị success hoặc rejection.
8. Không để client quyết định executed price.
9. Dùng mock order repository.
10. Viết unit test cho validation và idempotency phía client.
11. Viết widget test cho form.
12. Chạy analyze và test.
```

---

# 30. Prompt triển khai Backend Order Service

```text
Hãy đọc META_TRADER_CLONE_GUIDE.md.

Triển khai Order Service trong ASP.NET Core.

Yêu cầu:
1. Tạo endpoint POST /api/orders.
2. Validate trading account, symbol, lot và market status.
3. Kiểm tra ClientOrderId chống gửi trùng.
4. Kiểm tra margin.
5. Lấy giá từ Market Price Service, không lấy executed price từ client.
6. Tạo Order, Deal và Position trong transaction.
7. Cập nhật account summary.
8. Gửi SignalR event OrderUpdated, PositionUpdated và AccountSummaryUpdated.
9. Tạo audit log.
10. Dùng decimal cho dữ liệu tiền.
11. Viết unit test.
12. Viết integration test.
13. Chạy dotnet build và dotnet test.
```

---

# 31. Prompt kiểm tra toàn dự án

```text
Hãy đọc META_TRADER_CLONE_GUIDE.md và rà soát toàn bộ repository.

Kiểm tra:
1. Sai kiến trúc.
2. Hard-code.
3. Code trùng lặp.
4. Token hoặc secret trong source.
5. Lỗi decimal/float.
6. Lỗi timezone.
7. Lỗi authorization.
8. Lỗi idempotency.
9. Lỗi SignalR subscription.
10. Memory leak.
11. Widget rebuild quá nhiều.
12. WebView reload không cần thiết.
13. N+1 query.
14. Thiếu database index.
15. Thiếu cancellation token.
16. Thiếu loading/error/empty.
17. Thiếu test.
18. API không đồng bộ với mobile.

Không tự sửa ngay.

Hãy tạo báo cáo:
- Critical.
- High.
- Medium.
- Low.
- File liên quan.
- Nguyên nhân.
- Cách sửa.
- Thứ tự ưu tiên.
```

---

# 32. Cách sử dụng tài liệu này

1. Đặt file này ở thư mục gốc repository.
2. Đổi tên thành:

```text
META_TRADER_CLONE_GUIDE.md
```

3. Tạo thêm file:

```text
AGENTS.md
```

4. Trong `AGENTS.md`, ghi:

```markdown
# Codex Instructions

Before any implementation, read:

- META_TRADER_CLONE_GUIDE.md
- README.md
- docs/architecture.md
- docs/design-system.md

Do not change the required technology stack without approval.
After every task, run build, analyze and relevant tests.
```

5. Đưa ảnh app mẫu vào:

```text
reference/screens/
```

6. Giao cho Codex từng màn hình, không nên giao toàn bộ app trong một prompt.
7. Mỗi task chỉ nên tập trung vào một module hoặc một màn hình.
8. Sau mỗi task, kiểm tra git diff trước khi chuyển sang task tiếp theo.

---

# 33. Thứ tự task đề xuất

```text
TASK-001 Khởi tạo monorepo
TASK-002 Docker SQL Server + Redis
TASK-003 Flutter design system
TASK-004 App shell + navigation
TASK-005 Authentication UI
TASK-006 Market Watch UI
TASK-007 Mock realtime quote
TASK-008 Chart WebView
TASK-009 New Order UI
TASK-010 Trade UI
TASK-011 History UI
TASK-012 Wallet UI
TASK-013 Backend authentication
TASK-014 Backend trading account
TASK-015 Backend symbols
TASK-016 Backend market data
TASK-017 SignalR quote hub
TASK-018 Backend market order
TASK-019 Position management
TASK-020 History
TASK-021 Wallet ledger
TASK-022 Admin
TASK-023 Integration tests
TASK-024 Performance optimization
TASK-025 Security review
TASK-026 Docker deploy
```

---

# 34. Giới hạn pháp lý và sản phẩm

- Không dùng tên MetaTrader làm tên sản phẩm.
- Không sao chép logo hoặc icon độc quyền.
- Không sao chép source code.
- Không dùng dữ liệu thị trường không được cấp phép.
- Không cung cấp giao dịch tiền thật nếu chưa đáp ứng pháp lý.
- Không giả mạo broker hoặc tổ chức tài chính.
- Bản demo nên dùng tiền ảo và market feed giả lập.
- Khi kết nối broker thật, phải dùng API và quyền truy cập hợp lệ.

---

# 35. Kết quả cuối cùng mong muốn

Sau khi hoàn thành toàn bộ tài liệu này, hệ thống phải có:

- Flutter app chạy ổn định trên LDPlayer.
- Giao diện dark mode tương tự phong cách app giao dịch chuyên nghiệp.
- Market Watch realtime.
- Biểu đồ nến.
- Đặt lệnh demo.
- Position realtime.
- History.
- Wallet demo.
- Admin.
- Backend ASP.NET Core.
- SQL Server.
- Redis.
- SignalR.
- Docker deployment.
- Test cơ bản.
- Tài liệu vận hành.

Không coi dự án là hoàn thành chỉ vì giao diện đã giống ảnh. Hệ thống phải có kiến trúc, bảo mật, kiểm thử và luồng dữ liệu rõ ràng.
