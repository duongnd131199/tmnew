# Accountless Device Onboarding Design

## Mục tiêu

Cho phép một thiết bị có token EX V2 hợp lệ nhưng chưa có `ActiveTradingAccountId` đi vào luồng thêm tài khoản thật. App không được xoá token hoặc chặn toàn bộ giao diện chỉ vì `GET /mobile/bootstrap` trả `409 ACTIVE_ACCOUNT_NOT_CONFIGURED`.

## Nguyên nhân gốc

`DeviceGate` đang dùng `GET /mobile/bootstrap` để xác thực token. Endpoint bootstrap cần tài khoản active, vì vậy thiết bị mới có token đúng vẫn nhận 409. Sau đó gate chặn app, khiến người dùng không thể tới `/accounts/add` để liên kết tài khoản đầu tiên.

## Thiết kế

- `ExV2Repository.status()` gọi `GET /mobile/status`. Đây là endpoint duy nhất dùng để xác thực token lúc kích hoạt.
- `DeviceActivationService` vẫn chuẩn hoá token và chỉ giữ token khi callback status thành công. Token sai hoặc status lỗi không được coi là đã kích hoạt.
- `DeviceGate` phân loại chính xác `ExV2RequestFailure(statusCode: 409, code: ACTIVE_ACCOUNT_NOT_CONFIGURED)` từ bootstrap thành trạng thái onboarding, không gộp với lỗi mạng hoặc lỗi xác thực.
- Trạng thái onboarding hiển thị thông báo thiết bị đã được kích hoạt và nút `Thêm tài khoản`. Nút này mở ứng dụng thật tại route `/accounts/add`.
- 401/403, lỗi mạng, response hỏng và mọi mã 409 khác vẫn hiển thị lỗi bootstrap hiện tại. Không có fallback demo và không tạo broker/server giả.
- Sau khi liên kết/kích hoạt tài khoản thành công, coordinator hiện có publish bootstrap chuẩn; toàn bộ tab tiếp tục dùng dữ liệu account-scoped hiện có.

## Luồng dữ liệu

1. Người dùng nhập device token.
2. App tạm lưu token để transport gắn `X-Device-Token`, gọi `GET /mobile/status`.
3. Status 200: token được giữ và account provider chạy bootstrap.
4. Bootstrap 200: mở app với tài khoản active.
5. Bootstrap 409 + `ACTIVE_ACCOUNT_NOT_CONFIGURED`: hiển thị onboarding; bấm `Thêm tài khoản` mở `/accounts/add`.
6. Broker/server/link endpoints lỗi hoặc chưa triển khai: màn hình hiển thị loading/error/retry thật; không báo liên kết thành công giả.

## Kiểm thử

- Repository test chứng minh status gọi đúng `/ex/v2/api/mobile/status` và gửi device token.
- Widget test chứng minh activation dùng status thay vì bootstrap.
- Widget test chứng minh đúng structured 409 mở onboarding, token vẫn còn và CTA mở broker catalog.
- Widget test chứng minh 409 khác/lỗi mạng vẫn chặn app.
- Chạy focused tests, `flutter analyze`, toàn bộ `flutter test`, `flutter build apk --debug`, sau đó cài và kiểm tra trên thiết bị nếu ADB khả dụng.

## Ngoài phạm vi

Không triển khai server EX V2 trong repository này, không đổi base URL và không giả lập năm linked-account endpoint còn thiếu trên server.
