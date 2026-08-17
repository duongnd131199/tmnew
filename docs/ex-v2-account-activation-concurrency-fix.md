# EX V2 account activation `concurrency_conflict` fix

## Mục tiêu

Sửa production EX V2 để thiết bị có hai linked accounts có thể chuyển active account bằng API hiện có, sau đó mọi bootstrap/list/trading/history/wallet read đều resolve theo account mới.

Không sửa Flutter contract, base URL, device-token security hoặc endpoint.

## Lỗi đã tái hiện

Request từ APK mới:

```http
PUT https://trochoi.top/ex/v2/api/mobile/accounts/{publicAccountId}/activate
X-Device-Token: <redacted>
X-Correlation-Id: <new UUID>
Idempotency-Key: <new UUID for this user action>
Content-Type: application/json

{}
```

Response public ingress lặp lại:

```http
HTTP 409
Content-Type: application/json

{
  "code": "concurrency_conflict",
  "message": "The operation conflicted with another account change.",
  "correlationId": "875ec1cd-841f-40c9-9854-490a04425d77"
}
```

Cold restart sau response vẫn trả bootstrap của account cũ. Vì vậy đây không phải trường hợp mutation đã commit nhưng client bỏ lỡ response.

## Contract phải giữ nguyên

- `PUT /api/v2/mobile/accounts/{accountId}/activate`
- Body bắt buộc `{}`.
- Headers bắt buộc: `X-Device-Token`, `X-Correlation-Id`, `Idempotency-Key`.
- `accountId` là immutable public ID lấy từ `GET /mobile/accounts`, không phải login hoặc internal database ID.
- Success HTTP 200 trả `account` và canonical `bootstrap` đầy đủ.
- Ba identity phải bằng nhau: path account ID, `account.id`, `bootstrap.activeAccount.id`, `bootstrap.summary.accountId`.
- Không trả password, password hash, device token hoặc reconnect grant.

## Điều tra nguyên nhân gốc

Theo correlationId ở trên, truy trace transaction activate và ghi nhận an toàn:

- public account ID đã hash/mask;
- device row/version trước transaction;
- active-link row/version trước transaction;
- số attempt và SQL concurrency exception type;
- transaction commit/rollback;
- HTTP status/code/correlationId.

Không log header token, Authorization, request body đầy đủ, credential, reconnect grant hoặc financial bootstrap đầy đủ.

Kiểm tra đặc biệt:

1. Có worker/SignalR/market update đang sửa cùng device-active-account hoặc linked-account row hay không.
2. Activate có dùng row version của account summary đang thay đổi theo tick để bảo vệ device selection hay không. Device selection phải có concurrency boundary riêng, không phụ thuộc version tài chính thay đổi liên tục.
3. Idempotency command có bị giữ trạng thái `in_progress` sau exception/timeout hay không.
4. Transaction có update nhiều row theo thứ tự khác với link/login flow, gây deadlock hoặc optimistic concurrency conflict hay không.
5. Hai request khác key có chạy song song cho cùng device hay không; chúng phải được serialize theo device identity.

## Cách sửa yêu cầu

1. Khóa/serialize account activation theo device session trong transaction, bằng SQL row lock/application lock hoặc optimistic retry có giới hạn trên row chuyên quản lý active selection.
2. Không dùng row version của balance/equity/market summary làm concurrency token cho active-account selection.
3. Sau khi lấy lock, xác thực lại device ownership và linked-account status.
4. Update active account đúng một lần.
5. Build canonical bootstrap trong cùng authority/transaction boundary hoặc ngay sau commit từ active selection vừa commit.
6. Hoàn tất idempotency command bằng HTTP 200 payload canonical. Replay cùng key và cùng semantic request trả lại đúng result đã lưu.
7. Nếu transaction rollback, command không được mắc kẹt ở `in_progress`; request mới với key mới phải có thể thực thi.
8. Concurrent request cho hai account khác nhau phải có deterministic winner; response còn lại được retry/resolve an toàn, không làm trạng thái list/bootstrap bất đồng.

## Test bắt buộc trước deploy

Viết test thất bại trước khi sửa:

1. Device D có linked account A active và account B inactive.
2. `PUT B/activate` với body `{}` trả HTTP 200.
3. Response có bốn account ID canonical đều là B.
4. `GET /mobile/accounts` trả B trước hoặc `isActive=true`, A `isActive=false`.
5. `GET /mobile/bootstrap` trả B.
6. Position/history/wallet/settings reads đều scoped B và không chứa row của A.
7. Replay cùng idempotency key trả cùng HTTP 200 result và không activate lần hai.
8. Hai request đồng thời khác key cho B không trả persistent 409; state cuối chỉ có một active link.
9. Hai request đồng thời cho B và A được serialize; list và bootstrap đồng ý về winner.
10. Forced exception giữa update và command completion rollback sạch; request mới không bị `concurrency_conflict` vĩnh viễn.
11. Foreign device activate public ID nhận 404 theo contract hiện có.
12. Audit/log/idempotency persistence không chứa secret hoặc bootstrap tài chính đầy đủ.

## Public smoke sau deploy

Không đưa secret vào command history hoặc output. Đọc token từ root-only secret store và chỉ in status/code/correlationId/account-ID equality.

Thứ tự smoke:

1. `GET /mobile/accounts` → HTTP 200, lấy hai public account IDs.
2. Activate account inactive → HTTP 200.
3. Assert activate response identity equality.
4. `GET /mobile/accounts` → HTTP 200, account vừa chọn active.
5. `GET /mobile/bootstrap` → HTTP 200, cùng account ID.
6. Kiểm tra một read positions, history và wallet → HTTP 200, cùng scope.
7. Activate lại account ban đầu bằng key mới → HTTP 200 và lặp lại các assert.

Không tuyên bố hoàn thành nếu chỉ clear lock thủ công hoặc restart service. Phải có regression test chứng minh conflict không tái diễn dưới concurrent requests.

