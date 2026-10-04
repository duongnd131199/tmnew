# Kế hoạch xây dựng app Exness theo video

**Mục tiêu:** Hoàn thiện app Flutter độc lập trong `exness/`, tái hiện các màn hình và thao tác **xuất hiện trong** `IMG_1265.MP4`, dùng cùng API thị trường và EX V2 mà app `mobile/` hiện dùng. Mã cũ ở `mobile/` và backend hiện có được giữ nguyên.

**Nguồn tham chiếu:** Video dài 64,67 giây, khung hình 384 × 848, khoảng 30 fps; kiểm tra các mốc 0–64 giây. Số dư, giá, lịch sử và tên tài khoản trong video là dữ liệu của thời điểm quay, nên bản app mới phải lấy giá trị hiện tại từ API thay vì chép cứng.

## 1. Phạm vi nhìn thấy trong video

| Thời điểm | Màn hình / thao tác cần tái hiện | Hành vi cần kiểm tra |
| --- | --- | --- |
| 1–4s | Tab **Tài khoản**: tiêu đề, banner, thẻ tài khoản MT5 Pro, số dư, bốn thao tác nhanh, tab Mở / Đang chờ / Đã đóng, gợi ý mã giao dịch, thanh điều hướng năm mục | Chạm thẻ, chọn thao tác, đổi tab; trạng thái rỗng và dữ liệu thật |
| 4–10s | Sheet chi tiết tài khoản có hai tab **Thiết lập / Tài khoản quỹ** | Mở bằng biểu tượng bánh răng; đổi tab; sao chép số tài khoản/máy chủ; đóng bằng X hoặc vuốt |
| 12–21s | **Đang chờ** rỗng; **Đã đóng** gồm nhóm ngày, tổng P/L, danh sách lệnh XAU/USD đỏ/xanh; cuộn danh sách dài | Chuyển tab, cuộn, mở chi tiết lệnh nếu có dữ liệu |
| 22–25s | Tab **Giao dịch**: số dư trên đầu, danh mục Mục yêu thích, thẻ BTC / XAU/USD / ETH, sparkline, tìm kiếm, sắp xếp/chỉnh sửa | Chọn mã mở biểu đồ; tìm/lọc, đổi danh mục, trạng thái cập nhật giá |
| 26s | **Thông tin chuyên sâu**: mã nổi bật, tín hiệu, sự kiện sắp tới | Cuộn và mở thẻ chỉ khi có nguồn dữ liệu hợp lệ |
| 27–29s | **Hiệu suất**: giải thích múi giờ, lọc tài khoản và 7 ngày, empty state, nút Bắt đầu giao dịch | Đổi bộ lọc; khi API trả dữ liệu thì hiện số liệu/biểu đồ tương ứng |
| 30–44s | **Hồ sơ**: hạng Bronze, tài khoản, xác minh, quyền lợi, ví, giới thiệu, hỗ trợ; nút Hiển thị thêm; sheet Cài đặt gồm thông báo, ngôn ngữ, giao diện, bảo mật/Face ID; cuộn | Điều hướng/đóng sheet, mở rộng danh sách, lưu tùy chọn có API |
| 46–64s | Biểu đồ **XAU/USD**: nến xanh/đỏ trên nền hồng nhạt, nhãn Bid/Ask, One-click, số dư, chọn mã, khung 1m, công cụ biểu đồ, thông báo giờ mở cửa, sheet Thiết lập | Kéo/thu phóng biểu đồ, đổi khung, mở/đóng sheet, chọn nguồn biểu đồ và các mục truy cập nhanh |

Thanh điều hướng gồm **Tài khoản, Giao dịch, Thông tin chuyên sâu, Hiệu suất, Hồ sơ**. Video bắt đầu sau khi đã đăng nhập; các màn hình đăng nhập, nạp/rút/chuyển tiền, đặt lệnh và chi tiết hỗ trợ **không được quay**. Các mục này phải dùng hành vi API MT5 hiện có hoặc cần thêm video trước khi có thể xác nhận tương đồng về giao diện.

**Tài sản giao diện cần kiểm kê:** banner thưởng với hình kim loại, thẻ Bronze, biểu tượng tab/thao tác, cờ và biểu tượng tài sản, sparkline, ảnh bài viết, hiệu ứng chuyển tab/sheet. Giai đoạn 0 phải xác định font và kích thước từ khung hình gốc; tài sản không tách được ở chất lượng đủ cao từ video sẽ được dựng lại thành asset riêng trong `exness/assets/`.

## 2. Nguồn dữ liệu và ranh giới

`mobile/lib/app/bootstrap.dart` đang bật EX V2 và thị trường realtime. App mới sẽ dùng cùng hợp đồng API, nhưng tạo client/model trong `exness/` để hai app build và cài đặt độc lập. Không nhập trực tiếp `package:trading_mobile/...` và không chia sẻ token giữa hai Android application ID.

| Dữ liệu/chức năng | Nguồn hiện có | Ghi chú triển khai |
| --- | --- | --- |
| Giá, nến, kết nối | `https://trochoi.top/api/market/quotes`, `/candles`, `/status`; SignalR `/hubs/market` | Dùng REST để nạp lần đầu, SignalR cho thay đổi. Feed kiểm tra ngày 19/09/2026 có `XAUUSD+`, không có `XAUUSD`; hiển thị `XAU/USD` nhưng giữ mã API `XAUUSD+`. |
| Phiên và tài khoản | `https://trochoi.top/ex/v2/api/mobile/auth/login`, `/mobile/bootstrap`, `/mobile/accounts` | Thiết lập `X-Device-Token`, `X-Installation-Id` theo hợp đồng cũ; giữ token trong Secure Storage của app mới. Tài khoản/số dư do server quyết định. |
| Lệnh mở/chờ/đã đóng | EX V2 `/orders`, `/positions`, `/history/orders`, `/history/positions`, `/history/deals`, `/history/summary` | Phân nhóm ngày và tính tổng theo dữ liệu server; không dùng con số trong video. Đối chiếu semantics của deal/position trước khi hiện P/L. |
| Ví, chuyển khoản, thông báo | EX V2 `/wallet/transactions`, `/deposits`, `/withdrawals`, `/transfers`, `/notifications` | Giao dịch viết phải dùng `Idempotency-Key` và `X-Correlation-Id`; sau thành công tải lại bootstrap. |
| Hiệu suất và cài đặt | EX V2 `bootstrap.performance`, `/settings` | Bộ lọc thời gian cần kiểm tra thêm API lịch sử; tùy chọn nào API chưa lưu được thì không giả vờ lưu thành công. |
| Đặt lệnh/đóng vị thế | EX V2 `/orders`, `/positions/{id}/close`, `/positions/{id}/protection` | Chỉ luồng demo theo hợp đồng hiện có; không phát sinh giao dịch tiền thật. |

**Khoảng trống API hiện thấy:** Mã hiện có chưa thể hiện nguồn dữ liệu cho banner khuyến mãi/EXD, hạng Bronze và quyền lợi, số dư giới thiệu, tin tức/tín hiệu/sự kiện, trung tâm hỗ trợ/chat, thống kê lọc theo khoảng ngày, hoặc hai nhà cung cấp biểu đồ riêng. Giai đoạn 0 phải xác minh Swagger/hợp đồng server. Nếu không có endpoint, chỉ dựng bố cục với empty/error state rõ ràng và ghi phụ thuộc dữ liệu; không chép số tiền hoặc nội dung tin tức trong video thành dữ liệu thật. Muốn đạt chức năng hoàn toàn tương đương ở các phần đó cần API hợp lệ tương ứng.

## 3. Kiến trúc app mới

- `exness/lib/app/`: bootstrap, `ProviderScope`, GoRouter, shell năm tab và route/sheet; giữ `com.tradingdemo.exness` để cài song song với MT5.
- `exness/lib/core/theme/`: token màu, font, khoảng cách, bo góc, icon theo video; thiết kế sáng là mặc định cho các màn hình được quay.
- `exness/lib/core/network/` và `core/storage/`: Dio client cho Market và EX V2, xử lý lỗi, device token, request ID, SignalR, hủy subscription.
- `exness/lib/features/`: tách `account`, `trading`, `insights`, `performance`, `profile`, `chart`, `wallet`, `notifications`; mỗi phần có data, domain và presentation khi có dữ liệu/nghiệp vụ.
- Biểu đồ dùng Flutter WebView + TradingView Lightweight Charts theo stack đã yêu cầu; chỉnh style/interaction để khớp bản trong video. Lựa chọn “Exness / TradingView” trong sheet là chế độ hiển thị; không tuyên bố đổi nguồn giá nếu API không có nguồn thứ hai.
- State qua Riverpod, điều hướng qua GoRouter, REST qua Dio, token qua Flutter Secure Storage; dùng model có parse/validation, không lấy giá trị tài chính từ widget làm nguồn chuẩn.

## 4. Thứ tự thực hiện

### Giai đoạn 0 — Chốt hợp đồng và ảnh chuẩn

- [ ] Trích khung hình chuẩn tại 2, 6, 8, 15, 18, 23, 26, 28, 30, 36, 39, 48, 57 và 60 giây; ghi kích thước/safe area/màu/font/spacing/tương tác vào `exness/docs/screens/`.
- [ ] Xác minh endpoint công khai và schema EX V2 bằng tài khoản **demo được cấp quyền**, tạo fixture đã xóa token/thông tin riêng. Xác nhận mã `XAUUSD+` ↔ nhãn `XAU/USD`, BTC/ETH và timezone của lịch sử.
- [ ] Lập bảng từng trường trong video → trường API; đánh dấu chính xác trường thiếu và màn hình cần video bổ sung. Đây là cổng quyết định cho các mục marketing, tin tức, bảo mật hệ thống và chuyển tiền.

### Giai đoạn 1 — Shell và design system

- [ ] Thay màn chào hiện tại bằng shell năm tab, status/safe area, bottom bar, typography, thẻ, divider, icon, loading/empty/error theo khung hình chuẩn. Không sửa `mobile/`.
- [ ] Tạo route và sheet với thao tác Back, vuốt đóng/mở, giữ vị trí cuộn khi chuyển tab.
- [ ] Kiểm tra golden/screenshot ở tỉ lệ video 384 × 848 và viewport Android 360–430 logical px; chạy build, analyze, test và chụp LDPlayer.

### Giai đoạn 2 — Tài khoản và lịch sử

- [ ] Tích hợp đăng nhập/khôi phục phiên, bootstrap và catalog tài khoản; triển khai thẻ tài khoản cùng sheet Thiết lập/Tài khoản quỹ.
- [ ] Làm ba tab Mở/Đang chờ/Đã đóng từ order, position, history; ngày/giờ, tiền tệ, số thập phân và P/L theo dữ liệu server.
- [ ] Bốn thao tác nhanh điều hướng đến các luồng giao dịch/ví của app mới; kiểm thử không gửi lệnh/chuyển tiền trùng khi nhấn nhiều lần.
- [ ] Test contract parser, đổi tài khoản, empty/error/reconnect, cuộn lịch sử; chạy build, analyze, test và so ảnh LDPlayer tại các mốc 2–21s.

### Giai đoạn 3 — Giao dịch, thông tin chuyên sâu, hiệu suất

- [ ] Lấy quote live cho danh sách yêu thích; mini chart từ candle, tìm kiếm/lọc/chỉnh sửa danh sách; chạm mã mở chart đúng symbol API.
- [ ] Dựng các nhóm nội dung của Thông tin chuyên sâu. Chỉ nối tin tức/tín hiệu/sự kiện khi đã xác nhận endpoint; nếu thiếu, dùng empty state, không dựng bài viết giả.
- [ ] Hiệu suất đọc `bootstrap.performance` và dữ liệu lịch sử hỗ trợ lọc; hiển thị trạng thái rỗng đúng video khi không có hoạt động.
- [ ] Test phân luồng symbol, cập nhật quote mà không rebuild toàn trang, bộ lọc và lỗi feed; chạy build, analyze, test và so ảnh 22–29s.

### Giai đoạn 4 — Hồ sơ, ví và cài đặt

- [ ] Dựng danh sách hồ sơ, cuộn, “Hiển thị thêm”, sheet Cài đặt và các toggle có trạng thái thật. Ánh xạ ví/thông báo/settings từ EX V2.
- [ ] Tách rõ trường có nguồn API và trường thiếu (loyalty, referral, hỗ trợ, Face ID); chỉ bật hành động đã có backend/platform implementation.
- [ ] Test lưu/đọc lại cài đặt, logout, bảo vệ token, empty/error và sheet navigation; chạy build, analyze, test và so ảnh 30–44s.

### Giai đoạn 5 — Biểu đồ và luồng liên quan

- [ ] Nạp nến XAUUSD+ M1 qua REST, quote Bid/Ask qua realtime, chuẩn hóa timestamp, cập nhật cây nến hiện tại mà không reload WebView.
- [ ] Dựng nến, vùng nền, trục giá/thời gian, hai nhãn giá, khung thời gian, công cụ và thông báo giờ thị trường; hỗ trợ kéo, pinch zoom, crosshair và đổi timeframe.
- [ ] Sheet Thiết lập gồm tùy chọn biểu đồ, nguồn giá, lựa chọn kiểu hiển thị và truy cập nhanh. Giữ nội dung/animation theo các mốc 56–60s.
- [ ] Test mất/kết nối lại feed, chuyển symbol/timeframe, không trùng nến, zoom và dispose subscription; chạy build, analyze, test và so ảnh 46–64s.

### Giai đoạn 6 — Nghiệm thu

- [ ] Chạy `flutter analyze`, `flutter test`, `flutter build apk --debug` trong `exness/`; `dotnet build Trading.sln` và `dotnet test Trading.sln --no-build` trong `backend/` theo AGENTS.md.
- [ ] Cài APK `com.tradingdemo.exness` cạnh app MT5 trên LDPlayer, đi lại toàn bộ thứ tự 1–64s, chụp ảnh từng mốc và so sánh khung hình đã chuẩn hóa 384 × 848.
- [ ] Kiểm tra thao tác Back, sheet, cuộn, loading/empty/error, 401/403, mất mạng, realtime reconnect và việc số dư/lịch sử khớp server; tổng hợp sai khác còn lại theo từng màn hình.

## 5. Tiêu chí “giống 100%” và phụ thuộc

Mục tiêu nghiệm thu là **toàn bộ màn hình và thao tác thực sự nhìn thấy trong video**: bố cục, nhãn, font, màu, icon, khoảng cách, trạng thái chọn, cuộn, sheet và biểu đồ. So ảnh đã đưa về cùng khung 384 × 848, sửa từng sai khác có thể quan sát; dữ liệu động chỉ cần đúng hợp đồng API và cách hiển thị, không giữ nguyên giá/số dư trong bản quay.

Video là iPhone còn LDPlayer chạy Android, nên phần status bar/Dynamic Island và thanh điều hướng của hệ điều hành chỉ có thể mô phỏng về hình ảnh trong vùng app; hệ điều hành và các hành vi iOS không thể trở thành iOS thật trên máy ảo Android. Tiêu chí so ảnh tập trung vào vùng giao diện do app kiểm soát.

Không thể khẳng định chức năng của màn hình video không mở hoặc giá trị tài khoản Exness thật từ đoạn quay này. Những mục thiếu endpoint ở phần 2 cần nguồn dữ liệu/quyền truy cập bổ sung để đạt hành vi đầy đủ. App mới vẫn là bản demo độc lập và không thay thế app MT5 cũ.
