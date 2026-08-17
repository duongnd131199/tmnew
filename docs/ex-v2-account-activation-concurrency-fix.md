# EX V2: sửa `concurrency_conflict` khi chuyển tài khoản

## Trạng thái xác minh ngày 2026-08-17

Flutter đã gọi đúng thao tác chuyển tài khoản từ danh sách:

```http
PUT https://trochoi.top/ex/v2/api/mobile/accounts/{publicAccountId}/activate
X-Device-Token: <redacted>
X-Correlation-Id: <UUID mới>
Idempotency-Key: <UUID mới cho thao tác người dùng>
Content-Type: application/json

{}
```

Public ingress vẫn trả:

```http
HTTP 409

{
  "code": "concurrency_conflict",
  "message": "The operation conflicted with another account change.",
  "correlationId": "fbc56444-147c-4c67-96cd-a6d131931137"
}
```

Sau lỗi, `GET /mobile/bootstrap` và màn hình vẫn giữ account cũ. Điều này chứng minh mutation chưa commit; không được sửa Flutter bằng cách đổi account cục bộ.

Repository backend EX V2 production không có trong workspace `D:\mt5New`. Kết nối SSH `root@trochoi.top:22` từ máy này timeout, vì vậy patch backend phải được thực hiện bởi Codex chạy trực tiếp trên server/repository production.

## Contract phải giữ nguyên

- Route: `PUT /api/v2/mobile/accounts/{accountId}/activate`.
- Body: `{}`.
- Headers: `X-Device-Token`, `X-Correlation-Id`, `Idempotency-Key`.
- `accountId` là immutable public ID từ `GET /mobile/accounts`, không phải login hoặc internal database ID.
- HTTP 200 trả `{ account, bootstrap }` canonical.
- `account.id`, `bootstrap.activeAccount.id` và `bootstrap.summary.accountId` phải bằng path account ID.
- Không trả hoặc log password, password hash, device token, Authorization hay reconnectGrant.

## Test RED bắt buộc trên server

Tạo device D có linked account A active và B inactive. Gọi activate B rồi assert:

1. HTTP 200, không phải persistent 409.
2. Ba identity trong response đều là B.
3. `GET /mobile/accounts`: B `isActive=true`, A `isActive=false`.
4. `GET /mobile/bootstrap`: active account là B.
5. Positions, history, wallet và settings đều scoped B, không chứa dữ liệu A.
6. Replay cùng idempotency key trả cùng HTTP 200 result, không chạy mutation lần hai.
7. Hai request khác key cho cùng device được serialize và chỉ có một active link cuối cùng.
8. Forced rollback không để command kẹt `in_progress`.

Chạy test trước khi sửa và lưu bằng chứng RED với status/code/correlationId; không ghi token hoặc payload tài chính đầy đủ.

## Sửa transaction

Tìm handler và exception mapping bằng:

```bash
rg -n "mobile/accounts|activate|concurrency_conflict|DbUpdateConcurrencyException" .
```

Trong activation handler:

1. Bắt đầu transaction và serialize theo device/session selection row bằng row lock, application lock hoặc optimistic retry có giới hạn.
2. Sau khi có lock, đọc lại device ownership, linked-account status và active selection.
3. Không dùng row-version của balance/equity/market summary làm concurrency boundary cho active-account selection.
4. Tắt A và bật B đúng một lần trong cùng transaction.
5. Hoàn tất idempotency command cùng kết quả canonical; rollback phải giải phóng trạng thái `in_progress`.
6. Commit rồi tạo canonical bootstrap từ selection vừa commit, hoặc tạo trong cùng authority boundary bảo đảm đọc đúng B.
7. Chỉ map `DbUpdateConcurrencyException` thành 409 sau khi retry có giới hạn thực sự thất bại; không biến mọi update bình thường thành persistent 409.

## Deploy an toàn

1. Backup source/binary/config và database theo quy trình EX V2 hiện có.
2. Build release và chạy toàn bộ unit/integration/SQL Server tests.
3. Deploy chỉ EX V2 và restart chỉ `ex-v2-api.service`.
4. Không restart hoặc sửa `ex-api.service` legacy.
5. Kiểm tra health, journal error-priority và public Swagger sau deploy.

## Public smoke bắt buộc

Đọc token từ root-only secret store và không đưa token vào command output/history.

1. `GET /mobile/accounts` → HTTP 200; chọn một public account ID inactive.
2. `PUT .../{accountId}/activate` body `{}` → HTTP 200.
3. Assert response identity equality.
4. `GET /mobile/accounts` → HTTP 200, account vừa chọn active.
5. `GET /mobile/bootstrap` → HTTP 200, cùng account ID.
6. Positions/history/wallet/settings → HTTP 200 và cùng scope.
7. Activate ngược về account ban đầu với key mới → HTTP 200 và lặp lại các assert.

Không tuyên bố hoàn thành nếu chỉ restart service, xóa command lock thủ công hoặc sửa UI. Bằng chứng hoàn thành phải có test regression và status HTTP 200 thực tế qua public ingress.
