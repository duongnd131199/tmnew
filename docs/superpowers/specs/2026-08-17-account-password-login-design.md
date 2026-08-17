# Account/Password Login Design

## Mục tiêu

Đơn giản hóa onboarding EX V2 để người dùng chỉ nhập Login và Mật khẩu như luồng trong video. Broker, server, installation identity, correlation, idempotency và session token đều được app xử lý ngầm. Credential đúng phải liên kết, kích hoạt tài khoản và mở thẳng màn hình Trade bằng canonical bootstrap của backend.

Thiết kế không gửi password trong các request sau đăng nhập và không bỏ cơ chế session ở tầng bảo mật. Device token trở thành chi tiết nội bộ, không còn là dữ liệu người dùng phải nhập hoặc quản lý.

## Ranh giới source

- Flutter được sửa trong `D:/mt5New/mobile`.
- Backend local `D:/mt5New/backend` không phải source EX V2 phục vụ `https://trochoi.top/ex/v2/api` và không được sửa để giả lập endpoint.
- Đội backend EX V2 triển khai contract tại `docs/ex-v2-account-password-login-contract.md` trong source/deployment thật của EX V2.
- Không đổi base URL, Flutter/Riverpod/GoRouter/Dio/Secure Storage, ASP.NET Core/EF Core/SQL Server hay SignalR.

## Trải nghiệm người dùng

### Lần mở app chưa có session

App hiển thị một màn hình đăng nhập tối giản theo visual language của video:

- broker mark/tên YODO ở header;
- ô `Đăng nhập` dùng bàn phím số;
- ô `Mật khẩu` che ký tự;
- nút `Đăng nhập` cố định phía dưới;
- loading ngay trên nút trong khi submit;
- lỗi credential ngắn gọn và correlation ID an toàn.

Không hiển thị ô device token, broker catalog, server selector, đăng ký tài khoản thật/demo, lưu mật khẩu, quên mật khẩu hoặc các bước activate thủ công trong primary login flow.

### Session đã tồn tại

Nếu secure storage có session token hợp lệ, app tiếp tục bootstrap như hiện tại và không hỏi lại credential. Token bị revoke/hết hạn đưa người dùng về màn hình Login + Mật khẩu, không đưa về device-token gate.

### Đăng nhập thành công

App lưu token nội bộ chỉ sau khi response được parse đầy đủ và ba account identity trong account/bootstrap khớp nhau. Sau đó app publish canonical bootstrap, xóa password khỏi controller/state, reset account-scoped navigation và mở `/trade`.

## Kiến trúc Flutter

### Cấu hình login target

Stable IDs `yodo-demo` và `yodo-demo-01` nằm trong typed EX V2 login configuration, không nằm rải rác trong widget. Widget chỉ hiển thị metadata an toàn. Sau này có thể thay config bằng remote catalog mà không đổi form/controller.

### Installation identity

App sinh một UUID installation ID một lần và lưu trong secure storage. Đây không phải secret và không hiển thị cho người dùng. Login request dùng installation ID để backend scope idempotency, rate limit và upsert device session mà không cần device token đầu vào.

### Repository và controller

Một repository method mới gọi `POST /mobile/auth/login`. Controller:

1. validate numeric login và non-empty password;
2. chụp đúng giá trị controller tại thời điểm submit;
3. tạo correlation ID và idempotency key mới cho user action mới;
4. gửi raw password không trim/hash/lowercase/normalize;
5. chặn double tap trong khi request đang chạy;
6. parse `deviceToken + account + bootstrap`;
7. persist token rồi publish bootstrap;
8. xóa password ở mọi success và invalid-credential result.

Không ghi password, token, request body hoặc response body vào log. Safe diagnostics chỉ gồm URL, method/status, target IDs, masked login, password length, correlation ID và error code.

### Device gate migration

`DeviceGate` trở thành session gate:

- token hợp lệ: bootstrap và mở app;
- không có token: hiển thị account/password login;
- token invalid/revoked: xóa token và trở về account/password login;
- timeout/network: giữ error/retry, không xóa token trừ khi backend xác nhận token invalid.

Legacy token-entry widget không còn nằm trong production navigation. Không có fallback tự động gửi credential tới endpoint khác vì có thể tạo duplicate session/link side effects.

## Contract backend tóm tắt

Endpoint mới không yêu cầu `X-Device-Token`:

```http
POST /mobile/auth/login
X-Installation-Id: <UUID>
X-Correlation-Id: <UUID>
Idempotency-Key: <UUID>
Content-Type: application/json
```

```json
{
  "brokerId": "yodo-demo",
  "serverId": "yodo-demo-01",
  "login": "100000001",
  "password": "<raw transient input>"
}
```

Success `200` trả opaque `deviceToken`, linked account và canonical bootstrap. Backend verify credential, upsert device/link, activate account, rotate session token và build bootstrap trong một transaction/idempotent operation.

Các endpoint còn lại tiếp tục yêu cầu `X-Device-Token`. Password không bao giờ được persist, echo hoặc dùng lại sau login.

## Error handling

- `400 invalid_request`: form/header sai định dạng.
- `401/422 invalid_credentials`: login không tồn tại hoặc password sai; UI dùng cùng một thông báo để tránh enumeration.
- `409 idempotency_key_reused`: user action mới tạo metadata mới; transport retry của cùng action giữ nguyên metadata/body.
- `422 account_disabled` hoặc `server_mismatch`: hiển thị code và correlation ID, không rơi về mock data.
- `429 rate_limited`: khóa submit theo `Retry-After` nếu hợp lệ.
- `500/internal/network`: giữ login, xóa password chỉ khi policy yêu cầu nhập lại, cho phép retry bằng cùng operation metadata khi request outcome chưa xác định.

Mọi error display lọc code/correlation theo allowlist ký tự và giới hạn chiều dài. Không hiển thị stack trace, token, credential hoặc backend detail nhạy cảm.

## Tính nhất quán và retry

- Một user tap tạo đúng một operation metadata pair.
- Double tap khi đang submit không tạo request thứ hai.
- Retry transport cho request chưa biết outcome giữ nguyên idempotency key, correlation ID và body.
- Người dùng sửa login/password hoặc chủ động submit lại sau response xác định tạo key mới.
- Token chỉ được lưu sau success response hợp lệ; parse/bootstrap mismatch không làm app chuyển session.
- Backend success phải đảm bảo `account.id == bootstrap.activeAccount.id == bootstrap.summary.accountId`.

## Kiểm thử Flutter

Test phải được viết và chạy RED trước implementation:

- session thiếu hiển thị form Login + Mật khẩu, không hiển thị token input;
- controller-to-HTTP giữ nguyên password sentinel có khoảng trắng;
- request dùng app login, YODO stable IDs và exact public URL;
- login request có installation/correlation/idempotency headers nhưng không có device-token header;
- response 200 lưu token, publish canonical bootstrap và vào Trade;
- invalid credential xóa password, giữ login và hiển thị safe code/correlation ID;
- double tap chỉ tạo một request;
- user action mới tạo idempotency key mới;
- token invalid trở về login form;
- source/log/test artifacts không chứa reusable credential/token.

Sau GREEN chạy focused tests, `flutter analyze`, toàn bộ `flutter test` và `flutter build apk --debug`.

## Kiểm thử backend bắt buộc

- correct/wrong/unknown credential và disabled account;
- broker/server relation;
- transaction link + activate + token issue + canonical bootstrap;
- idempotent replay, changed-body conflict và concurrent login;
- installation isolation và token rotation/revocation;
- rate limit/no-enumeration behavior;
- secret redaction trong HTTP logging/APM/audit/exception;
- public-ingress E2E login, bootstrap và một authenticated request kế tiếp.

## Rollout

1. Backend deploy endpoint mới và OpenAPI trước.
2. Public-ingress smoke bằng synthetic virtual account chứng minh login 200 và token dùng được cho bootstrap.
3. Flutter release bật account/password session gate.
4. Giữ endpoint token/link legacy trong một compatibility window cho app cũ nhưng không hiển thị trong app mới.
5. Theo dõi `invalid_credentials`, rate-limit và login success theo low-cardinality metrics; không gắn login/token labels.

## Tiêu chí nghiệm thu

- Người dùng mới chỉ cần nhập đúng Login + Mật khẩu để vào Trade.
- Không có token/broker/server interaction trong primary UI.
- Credential đúng tạo hoặc reuse đúng device link, activate account và trả canonical bootstrap trong một thao tác.
- Credential sai không làm lộ account existence.
- Password và reusable token không xuất hiện trong log, analytics, source, test fixture, screenshot hoặc error.
- Flutter analyze/test/build và backend build/test/public smoke đều xanh trước khi tuyên bố hoàn tất.

## Ngoài phạm vi

- Kết nối broker thật hoặc giao dịch tiền thật.
- Gửi password trong mọi API request.
- Bỏ session authentication khỏi các endpoint tài chính sau login.
- Sửa backend demo local để giả endpoint EX V2.
- Hard-code password, device token, account balance hoặc dữ liệu video.
