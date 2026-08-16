# Device Gate Bootstrap Timeout Design

## Mục tiêu

Không để ứng dụng bị chặn vô thời hạn ở spinner khi secure token read hoặc account bootstrap không hoàn tất. Người dùng phải nhận được trạng thái lỗi có thể thử lại, trong khi token hợp lệ vẫn được giữ nguyên và thiết bị chưa có tài khoản vẫn đi vào luồng thêm tài khoản thật.

## Bằng chứng và nguyên nhân

- APK hiện tại trên LDPlayer `MT5-Dev` hiển thị spinner bootstrap liên tục nhiều phút.
- Public ingress `https://trochoi.top/ex/v2/api` phản hồi request không có token trong khoảng một giây, nên health/ingress không bị treo toàn cục.
- `DeviceGate` trả `_AccountBootstrapLoading` không giới hạn thời gian khi đọc secure token hoặc khi `exV2AccountProvider` còn `AsyncLoading`.
- Dio có connect/send/receive timeout 15 giây, nhưng secure token read diễn ra trước request và không nằm trong timeout của Dio. Gate cũng không có watchdog cho toàn bộ bootstrap lifecycle.
- Vì `DeviceGate` bọc toàn bộ `TradingApp`, spinner vô hạn chặn cả tab Cài đặt, màn Tài khoản và route `/accounts/add`.

Nguyên nhân ứng dụng không vào được là thiếu một terminal failure state cho bootstrap bị treo. Nguyên nhân hạ tầng cụ thể của lần secure read/request bị treo có thể thay đổi, nhưng không được phép làm UI loading vô hạn.

## Thiết kế

### Startup và bootstrap watchdog

- `DeviceGate` nhận `startupTimeout`, mặc định 20 giây và có thể rút ngắn trong widget test.
- Giai đoạn đọc secure token được bọc timeout. Nếu hết thời gian hoặc ném lỗi, gate hiển thị `device-token-read-error` với nút `Thử lại`.
- Sau khi xác nhận có token, gate khởi động bootstrap watchdog. Nếu provider vẫn loading khi timeout hết, gate hiển thị `account-bootstrap-timeout` với nút `Thử lại`.
- Khi provider chuyển sang data hoặc error, watchdog được hủy.
- Retry reset timeout state, khởi động watchdog mới và invalidate `exV2AccountProvider` đúng một lần.

### Chính sách token và lỗi

- Timeout, lỗi mạng, lỗi parse và bootstrap 5xx không xóa device token.
- Chỉ luồng activation qua `/mobile/status` quyết định token nhập mới có hợp lệ hay không.
- Structured `409 ACTIVE_ACCOUNT_NOT_CONFIGURED` tiếp tục hiển thị onboarding và CTA mở `/accounts/add`.
- Mọi 409 khác và lỗi khác vẫn fail closed.
- Không mở app shell hoặc dữ liệu demo khi account-scoped bootstrap chưa thành công.

### Nút thêm tài khoản

- Giữ route production `/accounts/add` cho dấu `+` tại màn Tài khoản và dòng `Tài khoản mới` tại Cài đặt.
- Thêm regression dùng router thật để chứng minh dấu `+` mở broker discovery cả sau một bootstrap retry thành công.
- Không chuyển thẳng tới form credential khi chưa chọn broker và server từ catalog production.

## Kiểm thử

- Widget test: token read không hoàn tất phải chuyển từ loading sang `device-token-read-error` sau timeout; Retry thực hiện lần đọc mới.
- Widget test: account provider không hoàn tất phải chuyển sang `account-bootstrap-timeout`; token không bị xóa.
- Widget test: Retry bootstrap thành công mở app shell, sau đó dấu `+` tại màn Tài khoản mở `/accounts/add`.
- Regression: exact accountless 409 vẫn giữ token và mở CTA; 409 khác vẫn fail closed.
- Chạy focused tests, `flutter analyze --no-pub`, full `flutter test --no-pub --concurrency=1`, `flutter build apk --debug --no-pub`, backend build/test theo `AGENTS.md`, rồi cài APK lên `MT5-Dev` và kiểm tra ảnh màn hình.

## Ngoài phạm vi

- Không xóa app data hoặc token để che lỗi.
- Không tạo broker, server, tài khoản hoặc credential giả trên production.
- Không đổi API base URL, stack công nghệ hoặc backend EX V2.
- Không sửa các module giao dịch không liên quan.
