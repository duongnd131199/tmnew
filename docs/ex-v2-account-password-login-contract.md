# EX V2 Account/Password Mobile Login Contract

## Mục đích

Tài liệu này là contract triển khai cho source backend EX V2 thật. Flutter cần một lần đăng nhập bằng account/password để backend tự tạo device session, link và activate account. Người dùng không nhập device token; token vẫn tồn tại nội bộ để bảo vệ mọi API tài chính sau login.

Không triển khai contract này trong `D:/mt5New/backend`; đó không phải service EX V2 đang phục vụ public base URL.

## Public route

```http
POST https://trochoi.top/ex/v2/api/mobile/auth/login
```

ASP.NET Core route tương ứng sau reverse-proxy rewrite:

```http
POST /api/v2/mobile/auth/login
```

Không tạo URL lặp `/api/v2`, `/ex/v2/api` hoặc thay base URL Flutter.

## Request

Required headers:

```text
X-Installation-Id   UUID ổn định do một app installation sinh, không phải secret
X-Correlation-Id    UUID mới cho operation mới
Idempotency-Key     UUID mới cho operation mới; retry cùng body giữ nguyên key
Content-Type        application/json
```

`X-Device-Token` không được yêu cầu trên duy nhất endpoint login này.

Body có đúng casing:

```json
{
  "brokerId": "yodo-demo",
  "serverId": "yodo-demo-01",
  "login": "100000001",
  "password": "<raw transient input>"
}
```

Validation:

- `brokerId`, `serverId` là stable public IDs; không nhận display name.
- `login` là string numeric sau trim; không chuyển thành JSON number.
- `password` non-empty và được verify nguyên byte/character sequence; không trim, lowercase, normalize, hash ở transport boundary hoặc log.
- Server phải enabled và thuộc broker.
- Chỉ xác thực virtual/demo account đã provision trong EX V2.

## Success response

HTTP `200`:

```json
{
  "deviceToken": "<opaque session token>",
  "account": {
    "id": "account-public-id",
    "brokerId": "yodo-demo",
    "brokerName": "YODO Demo Markets",
    "serverId": "yodo-demo-01",
    "serverName": "YODO-Demo-01",
    "login": "100000001",
    "isActive": true,
    "displayName": "Virtual account",
    "currency": "USD",
    "status": "active"
  },
  "bootstrap": {
    "serverTime": "2026-08-17T00:00:00Z",
    "version": 1,
    "device": {
      "id": "device-public-id",
      "name": "Mobile device"
    },
    "activeAccount": {
      "id": "account-public-id",
      "accountCode": "100000001",
      "name": "Virtual account",
      "currency": "USD",
      "status": "active"
    },
    "summary": {
      "accountId": "account-public-id",
      "currency": "USD",
      "balance": 0,
      "equity": 0,
      "profit": 0,
      "margin": 0,
      "freeMargin": 0,
      "marginLevel": 0,
      "updatedAt": "2026-08-17T00:00:00Z"
    },
    "positions": [],
    "pendingOrders": [],
    "recentDeals": [],
    "wallet": {
      "currency": "USD",
      "availableBalance": 0,
      "lockedBalance": 0,
      "totalBalance": 0
    },
    "performance": {
      "netProfit": 0,
      "grossProfit": 0,
      "grossLoss": 0,
      "floatingProfit": 0,
      "tradingVolume": 0,
      "updatedAt": null,
      "integrityWarnings": 0
    },
    "connection": {
      "marketFeedStatus": "connected",
      "lastMarketTickAt": null
    },
    "integrityWarnings": 0
  }
}
```

`bootstrap` phải được tạo bởi canonical builder đang dùng cho `GET /mobile/bootstrap`, không dùng DTO rút gọn theo example. Bắt buộc:

```text
response.account.id
== response.bootstrap.activeAccount.id
== response.bootstrap.summary.accountId
```

`deviceToken` là opaque, entropy cao, scoped theo device session, có expiry/revocation/rotation và chỉ được trả qua HTTPS. Response không có password, password hash, reconnect grant, token digest hoặc internal IDs.

## Transaction

Trong một SQL Server transaction/idempotent operation:

1. Validate installation ID, correlation và idempotency metadata.
2. Claim idempotency key theo `(InstallationId, Operation, Key)`.
3. Resolve enabled broker/server và credential theo `(ServerId, NormalizedLogin)`.
4. Verify raw password bằng password hasher hiện có; unknown login và wrong password có cùng public behavior.
5. Upsert device installation/session bằng exact installation ID.
6. Upsert device-account link, không tạo duplicate.
7. Activate linked account và update device/account version.
8. Issue hoặc rotate đúng một current device token; persist chỉ non-reversible digest/metadata.
9. Build canonical bootstrap nhìn thấy account vừa activate.
10. Assert ba account IDs bằng nhau.
11. Persist safe audit/idempotency result; commit rồi mới trả response.

Rollback bất kỳ bước nào không được để lại partial device, link, active selection, token, audit side effect hoặc replay result.

## Idempotency

- Cùng installation + key + exact semantic body replay cùng `200` result mà không verify/link/activate/issue lần hai.
- Replay cần re-deliver cùng protected token response của operation, không issue token mới.
- Cùng key nhưng đổi broker/server/login/password trả `409 idempotency_key_reused`.
- Fingerprint phải bao gồm raw password bằng versioned keyed HMAC; không lưu raw canonical body hoặc unkeyed password digest.
- Record hết retention trả structured conflict, không âm thầm xem là operation mới.

## Error contract

Mọi lỗi trả:

```json
{
  "code": "invalid_credentials",
  "message": "Unable to sign in.",
  "correlationId": "safe-correlation-id",
  "errors": null
}
```

Và response header `X-Correlation-Id` phải trùng body.

Minimum mapping:

| HTTP | Code | Ý nghĩa |
|---|---|---|
| 400 | `invalid_request` | Header/body/casing/type sai |
| 422 | `invalid_credentials` | Unknown login hoặc wrong password, cùng message/timing bucket |
| 404 | `broker_not_found` | Broker không khả dụng |
| 404 | `server_not_found` | Server không khả dụng |
| 409 | `idempotency_key_reused` | Key cũ dùng cho body khác |
| 409 | `idempotency_record_expired` | Replay record hết retention |
| 422 | `server_mismatch` | Server không thuộc broker |
| 422 | `account_disabled` | Account/server/link disabled |
| 429 | `rate_limited` | Rate limit; kèm `Retry-After` |
| 500 | `internal_error` | Safe generic message |

Backend dùng cố định HTTP `422` cho `invalid_credentials` để tương thích contract EX V2 hiện tại. Flutter vẫn có thể nhận `401 invalid_credentials` từ bản server cũ trong compatibility window, nhưng OpenAPI và test của endpoint mới chỉ mô tả `422`.

## Security và logging

Không log hoặc persist:

- password hoặc full request body;
- raw device token/token digest;
- Authorization;
- protected idempotency response;
- reconnect grant;
- stack trace trong response.

Safe log fields:

- route/method/status;
- brokerId/serverId;
- masked login;
- password length;
- installation fingerprint không đảo ngược;
- correlationId;
- error code.

Credential verification phải rate-limit theo installation/IP, dùng constant-time primitives/password hasher hiện có và không tạo account-enumeration side channel.

## OpenAPI

Thêm route, required headers, exact request/response schema, examples giả và structured errors. `password` dùng `format: password`, không có example thật. `deviceToken` được đánh dấu opaque, `readOnly` và chỉ xuất hiện trong login success response.

Giữ nguyên các endpoint legacy để app cũ hoạt động trong compatibility window:

- `/mobile/status`
- `/mobile/bootstrap`
- `/mobile/brokers`
- `/mobile/accounts/link`
- `/mobile/accounts/{accountId}/activate`

## Test bắt buộc

1. Credential đúng trả `200`, token, account active và canonical bootstrap.
2. Wrong password/unknown login cùng status/code/message và không rò thông tin.
3. Password có leading/trailing spaces được verify nguyên vẹn.
4. Internal ID không thay login; display names không thay public IDs.
5. Missing/invalid installation/correlation/idempotency headers bị từ chối.
6. Replay cùng key/body không tạo duplicate hoặc rotate token lần hai.
7. Cùng key khác password trả `409` mà không persist password.
8. Concurrent login không tạo hai current token/link/active rows.
9. Transaction failure rollback toàn bộ side effects.
10. Token trả về gọi được `GET /mobile/bootstrap` và authenticated endpoints.
11. Secret leakage scan qua response/log/audit/APM/OpenAPI fixture.
12. Public-ingress E2E chứng minh exact route không bị prefix duplication.

## Public smoke acceptance

Qua `https://trochoi.top/ex/v2/api`, dùng synthetic virtual account và secret store, không in secret:

1. Login trả HTTP 200 và correlation ID.
2. Token response gọi `GET /mobile/accounts` trả HTTP 200 và thấy linked account.
3. `GET /mobile/bootstrap` trả HTTP 200 với ba-way account identity nhất quán.
4. Một authenticated mutation/read smoke xác nhận token scope hoạt động.
5. Wrong credential probe trả structured `invalid_credentials` không rò dữ liệu.

Chỉ deploy Flutter account/password gate sau khi backend contract, OpenAPI, integration tests và public smoke này đều xanh.
