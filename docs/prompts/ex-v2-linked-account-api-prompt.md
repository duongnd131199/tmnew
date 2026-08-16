# Prompt triển khai API liên kết tài khoản demo EX V2

Bạn là kỹ sư chịu trách nhiệm mã nguồn và quy trình triển khai của dịch vụ ASP.NET Core EX V2 được deploy riêng. Hãy triển khai đầy đủ API liên kết/chuyển tài khoản giao dịch **ảo/demo** theo đặc tả dưới đây, bắt đầu bằng test và kết thúc bằng bằng chứng build, migration, smoke test, deploy và rollback.

Đây là prompt triển khai cho một thay đổi chưa được khẳng định là đã tồn tại. Không được giả định endpoint, bảng dữ liệu, migration hay bản deploy mới đã có sẵn. Hãy kiểm tra mã nguồn thật trước, ghi lại mọi đường dẫn đã phát hiện và chỉ báo cáo hoàn thành sau khi có bằng chứng chạy được.

## 1. Mục tiêu và ranh giới bắt buộc

Tạo catalog broker/server và API để một thiết bị có thể:

1. tìm broker và server demo;
2. xác thực một tài khoản giao dịch ảo đã được cấp sẵn;
3. liên kết tài khoản đó với thiết bị;
4. liệt kê các tài khoản đã liên kết của chính thiết bị;
5. kích hoạt một tài khoản đã liên kết;
6. nhận về một bootstrap EX V2 đầy đủ, nhất quán cho tài khoản vừa kích hoạt;
7. nhận sự kiện thay đổi tài khoản chỉ sau khi transaction kích hoạt đã commit.

Các ràng buộc không được thương lượng:

- Chỉ phục vụ tài khoản ảo/demo thuộc EX V2. Không kết nối tới, đăng nhập vào, giao dịch qua hoặc giả mạo tài khoản Exness/MetaQuotes thật.
- Không sửa `D:/mt5New/backend`. Đó là backend market-data/read-only cục bộ; EX V2 là dịch vụ và mã nguồn tách biệt.
- Không thay stack hiện có: ASP.NET Core, Entity Framework Core, SQL Server và SignalR.
- Phải tái sử dụng device-token resolver, bootstrap builder, password hasher, audit system, correlation/logging pipeline, migration convention, deployment và rollback mechanism hiện có. Không tạo một cơ chế song song nếu mã nguồn đã có cơ chế tương đương.
- Không thay đổi hoặc làm gián đoạn các route legacy `/ex/api/api/*`.
- Không hard-code tài khoản, login, mật khẩu, server, số dư, tên người dùng hay dữ liệu giao dịch xuất hiện trong video tham chiếu.
- Không ghi plaintext password/reconnect grant vào database, log, trace, metric, audit payload hoặc exception. Không đưa credential, grant hay device token thật/reusable vào fixture, snapshot, source, tài liệu hoặc output CI; test chỉ được dùng sentinel giả, không thể dùng ngoài môi trường test.
- Không log toàn bộ request/response body của endpoint link. Các middleware HTTP logging/APM phải redact ít nhất `password`, `reconnectGrant`, `X-Device-Token`, `Idempotency-Key` và mọi Authorization header.
- Dùng `decimal` cho tiền và khối lượng; dùng UTC ISO-8601 cho thời gian; không dùng `float`/`double` trong domain hoặc persistence tài chính.

## 2. Cổng khám phá mã nguồn — phải làm trước khi sửa code

Đọc toàn bộ file chỉ dẫn của repository đích trước, ưu tiên theo thứ tự sau nếu tồn tại:

- `AGENTS.md` và mọi `AGENTS.md` lồng theo thư mục;
- `README.md`;
- tài liệu architecture/application/domain/infrastructure;
- tài liệu security, authentication, device-token, secrets và logging;
- tài liệu OpenAPI/versioning/reverse proxy;
- tài liệu migration/database;
- tài liệu deployment, health check và rollback.

Sau đó tìm và ghi lại đường dẫn thật của các thành phần sau:

- solution `.sln` hoặc `.slnx`;
- API/startup project;
- application/domain/infrastructure projects;
- `DbContext`, migration assembly và migration gần nhất;
- controller/endpoint hiện có của `GET /api/v2/mobile/bootstrap`;
- device-token resolver hiện có;
- bootstrap builder hiện có;
- password hasher hiện có;
- audit writer hiện có;
- SignalR/outbox/event publisher của `ActiveAccountChanged` hoặc event tương đương;
- idempotency và correlation middleware/filter hiện có;
- integration-test project và test fixture SQL Server;
- OpenAPI source/generated artifact;
- manifest/script/pipeline deploy và rollback.

Chỉ các token đường dẫn dưới đây là placeholder hợp lệ trong quá trình làm việc. Thay tất cả bằng đường dẫn thật đã phát hiện trước khi chạy lệnh hoặc đưa vào báo cáo cuối:

```text
<DISCOVERED_EX_V2_SOURCE_ROOT>
<DISCOVERED_SOLUTION_FILE>
<DISCOVERED_API_PROJECT>
<DISCOVERED_APPLICATION_PROJECT>
<DISCOVERED_DOMAIN_PROJECT>
<DISCOVERED_INFRASTRUCTURE_PROJECT>
<DISCOVERED_INTEGRATION_TEST_PROJECT>
<DISCOVERED_DB_CONTEXT>
<DISCOVERED_OPENAPI_FILE>
<DISCOVERED_DEPLOYMENT_DOC_OR_SCRIPT>
<DISCOVERED_ROLLBACK_DOC_OR_SCRIPT>
```

Không để lại `TBD`, `TODO`, “tùy hệ thống”, “xử lý phù hợp”, đường dẫn phỏng đoán hoặc placeholder nào khác trong code, OpenAPI, migration và báo cáo cuối.

Chạy baseline từ source root, sau khi thay placeholder bằng đường dẫn thật:

```bash
dotnet --info
dotnet restore "<DISCOVERED_SOLUTION_FILE>"
dotnet build "<DISCOVERED_SOLUTION_FILE>" -c Release --no-restore
dotnet test "<DISCOVERED_SOLUTION_FILE>" -c Release --no-build --logger "console;verbosity=normal"
```

Nếu không có source thật, baseline không xanh hoặc không xác định được deployment/rollback mechanism, dừng triển khai và báo blocker; không dựng API giả trong `D:/mt5New/backend`.

## 3. Contract route công khai và route ASP.NET Core

Flutter hiện cấu hình REST base URL công khai là:

```text
https://trochoi.top/ex/v2/api
```

Flutter nối các path tương đối `/mobile/...` vào base URL đó. Trong EX V2/OpenAPI, route chuẩn phải nằm dưới `/api/v2`. Reverse proxy hiện hữu chịu trách nhiệm mapping public prefix `/ex/v2/api` tới route ASP.NET Core; phải kiểm tra mapping thật và không được thêm lặp `/api/v2` vào URL phía Flutter.

Triển khai đúng năm route ASP.NET Core sau:

```text
GET  /api/v2/mobile/brokers?query=
GET  /api/v2/mobile/brokers/{brokerId}/servers?query=
GET  /api/v2/mobile/accounts
POST /api/v2/mobile/accounts/link
PUT  /api/v2/mobile/accounts/{accountId}/activate
```

Các request công khai tương ứng mà Flutter tạo ra là:

```text
GET  /ex/v2/api/mobile/brokers?query=
GET  /ex/v2/api/mobile/brokers/{brokerId}/servers?query=
GET  /ex/v2/api/mobile/accounts
POST /ex/v2/api/mobile/accounts/link
PUT  /ex/v2/api/mobile/accounts/{accountId}/activate
```

Không đổi tên route, HTTP method, field JSON hoặc casing. `brokerId`, `serverId` và `accountId` là UUID/GUID được JSON hóa thành string. Path parameter phải được route-decoded đúng một lần và validate là GUID hợp lệ.

## 4. Header, xác thực thiết bị và correlation

Mọi endpoint trong tài liệu này yêu cầu:

```text
X-Device-Token     required; giá trị là secret do thiết bị đang giữ
X-Correlation-Id   required; giá trị là chuỗi correlation khác rỗng
```

Hai mutation còn yêu cầu:

```text
Idempotency-Key    required; khóa ổn định cho đúng một thao tác người dùng
```

Quy tắc bắt buộc:

- Dùng device-token resolver hiện có; không tự parse token, không nhận `deviceId` từ query/body và không cho client chọn device scope.
- Token thiếu/sai/hết hạn/đã revoke trả `401` với error contract ở mục 8. Không phân biệt bằng thông báo có thể giúp dò token.
- `X-Correlation-Id` thiếu, rỗng hoặc vượt giới hạn an toàn của pipeline hiện có trả `400`. Echo giá trị hợp lệ vào response header và error body.
- `Idempotency-Key` thiếu/rỗng trên mutation trả `400`. GET không yêu cầu và không tạo idempotency record.
- Không ghi raw header bí mật vào log. Correlation ID được phép log; device chỉ được log bằng internal device ID hoặc fingerprint không thể đảo ngược theo chuẩn hiện có.
- Authorization được kiểm tra lại bên trong transaction mutation. Một thiết bị chỉ được list/activate account link thuộc chính thiết bị đó.
- Khi `accountId` tồn tại nhưng thuộc thiết bị khác, trả cùng `404 account_not_found` như account không tồn tại để tránh rò rỉ sự tồn tại.

## 5. JSON contract chính xác

Các endpoint list trả **JSON array trực tiếp**, không bọc thêm envelope.

### 5.1 `GET /api/v2/mobile/brokers?query=`

`query` là tùy chọn; trim, tìm không phân biệt hoa thường/diacritics theo collation hiện có trên `name`, `companyName` và mã catalog nội bộ. Query rỗng trả toàn bộ broker đang bật. Giữ thứ tự ổn định theo `displayOrder`, sau đó `name`, sau đó `id`.

Response `200`:

```json
[
  {
    "id": "11111111-1111-4111-8111-111111111111",
    "name": "Demo Markets",
    "companyName": "Demo Markets Ltd",
    "description": "Virtual trading accounts only",
    "logoUrl": null
  }
]
```

`id` và `name` là string khác rỗng. `companyName`, `description`, `logoUrl` là string khác rỗng hoặc `null`; không trả sai kiểu.

### 5.2 `GET /api/v2/mobile/brokers/{brokerId}/servers?query=`

Chỉ trả server đang bật thuộc đúng broker. `query` trim và tìm không phân biệt hoa thường trên `name`, `accountType`, `description`. Giữ thứ tự ổn định theo `displayOrder`, sau đó `name`, sau đó `id`.

Response `200`:

```json
[
  {
    "id": "22222222-2222-4222-8222-222222222222",
    "name": "DemoMarkets-MT5Demo",
    "brokerId": "11111111-1111-4111-8111-111111111111",
    "accountType": "demo",
    "description": "Virtual demo server"
  }
]
```

`id`, `name`, `brokerId` là string khác rỗng. `accountType`, `description` là string khác rỗng hoặc `null`. Broker không tồn tại/không bật trả `404 broker_not_found`.

### 5.3 `GET /api/v2/mobile/accounts`

Chỉ trả link của thiết bị đã resolve. Không trả password, password hash, reconnect grant, grant hash, device token, idempotency payload hoặc internal audit data. Trả account active trước, sau đó `linkedAtUtc` giảm dần, cuối cùng `id` để ổn định. Tối đa một row có `isActive: true`.

Response `200`:

```json
[
  {
    "id": "33333333-3333-4333-8333-333333333333",
    "brokerId": "11111111-1111-4111-8111-111111111111",
    "brokerName": "Demo Markets",
    "serverId": "22222222-2222-4222-8222-222222222222",
    "serverName": "DemoMarkets-MT5Demo",
    "login": "100001",
    "isActive": true,
    "displayName": "Virtual account",
    "currency": "USD",
    "status": "active"
  }
]
```

Các field `id`, `brokerId`, `brokerName`, `serverId`, `serverName`, `login` là string khác rỗng; `isActive` là boolean; `displayName`, `currency`, `status` là string khác rỗng hoặc `null`. `login` là string để không mất số 0 đầu và không được ép thành JSON number.

### 5.4 `POST /api/v2/mobile/accounts/link`

Request body phải đúng năm field, không nhận account ID, executed price hoặc device ID:

```json
{
  "brokerId": "11111111-1111-4111-8111-111111111111",
  "serverId": "22222222-2222-4222-8222-222222222222",
  "login": "100001",
  "password": "transient-user-input",
  "savePassword": true
}
```

Validation:

- từ chối unknown field nếu convention hiện có đã bật strict JSON; tối thiểu không bind hoặc persist unknown field;
- `brokerId`, `serverId` là GUID hợp lệ;
- server phải đang bật và thuộc đúng broker;
- `login` sau trim phải chỉ gồm chữ số; dùng string xuyên suốt;
- `password` phải khác rỗng và không trim/thay đổi trước khi verify;
- `savePassword` là boolean bắt buộc;
- chỉ xác thực account ảo đã provision trong EX V2; không gọi broker thật.

Response `200`, dùng cho cả link mới và link đã tồn tại:

```json
{
  "account": {
    "id": "33333333-3333-4333-8333-333333333333",
    "brokerId": "11111111-1111-4111-8111-111111111111",
    "brokerName": "Demo Markets",
    "serverId": "22222222-2222-4222-8222-222222222222",
    "serverName": "DemoMarkets-MT5Demo",
    "login": "100001",
    "isActive": false,
    "displayName": "Virtual account",
    "currency": "USD",
    "status": "active"
  },
  "reconnectGrant": "opaque-one-time-return-value",
  "alreadyLinked": false
}
```

Quy tắc response:

- `alreadyLinked` là `false` khi tạo link mới, `true` khi đúng account đã liên kết với thiết bị.
- Dù link đã tồn tại, vẫn phải verify lại password và trạng thái account trước khi trả thành công.
- Không tự kích hoạt account trong endpoint link; Flutter gọi endpoint activate ngay sau đó. `isActive` phản ánh trạng thái thật tại thời điểm trả response.
- Tạo một reconnect grant ngẫu nhiên, entropy cao cho mỗi link thành công. Chỉ trả plaintext grant đúng lần response này; database chỉ lưu hash/digest bằng primitive hiện có, cùng device/link scope, purpose, issued-at, expiry và revoked-at.
- Với `savePassword: true`, grant dùng TTL lưu đăng nhập do security configuration hiện có quy định. Với `savePassword: false`, grant dùng TTL phiên/ngắn hạn do cùng security configuration quy định; client chỉ giữ trong memory và server vẫn chỉ lưu hash. Không hard-code TTL trong controller.
- Link response không có field `password`, `passwordHash`, `grantHash` hoặc device token.

### 5.5 `PUT /api/v2/mobile/accounts/{accountId}/activate`

Flutter gửi JSON object rỗng:

```json
{}
```

Response `200` gồm `account` và **bootstrap mobile đầy đủ**:

```json
{
  "account": {
    "id": "33333333-3333-4333-8333-333333333333",
    "brokerId": "11111111-1111-4111-8111-111111111111",
    "brokerName": "Demo Markets",
    "serverId": "22222222-2222-4222-8222-222222222222",
    "serverName": "DemoMarkets-MT5Demo",
    "login": "100001",
    "isActive": true,
    "displayName": "Virtual account",
    "currency": "USD",
    "status": "active"
  },
  "bootstrap": {
    "serverTime": "2026-08-16T08:00:00Z",
    "version": 2,
    "device": {
      "id": "44444444-4444-4444-8444-444444444444",
      "name": "Mobile device"
    },
    "activeAccount": {
      "id": "33333333-3333-4333-8333-333333333333",
      "accountCode": "100001",
      "name": "Virtual account",
      "currency": "USD",
      "status": "active"
    },
    "summary": {
      "accountId": "33333333-3333-4333-8333-333333333333",
      "currency": "USD",
      "balance": 0,
      "equity": 0,
      "profit": 0,
      "margin": 0,
      "freeMargin": 0,
      "marginLevel": 0,
      "updatedAt": "2026-08-16T08:00:00Z"
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

Không tự viết một bootstrap rút gọn theo ví dụ trên. Phải gọi bootstrap builder hiện có của `GET /api/v2/mobile/bootstrap`, bao gồm đầy đủ `serverTime`, `version`, `device`, `activeAccount`, `summary`, `positions`, `pendingOrders`, `recentDeals`, `wallet`, `performance`, `connection`, `integrityWarnings` và mọi field hiện hữu khác mà OpenAPI/server đã quy định. Nếu các array có phần tử, giữ nguyên schema hiện tại của position/order/deal; không đổi casing hoặc bỏ field.

Ba giá trị sau phải bằng nhau tuyệt đối trong mọi response thành công:

```text
response.account.id
response.bootstrap.activeAccount.id
response.bootstrap.summary.accountId
```

Flutter sẽ ném `FormatException` và từ chối chuyển state nếu bất kỳ cặp nào lệch nhau.

## 6. Persistence, hash và migration

Ánh xạ tên entity/table theo convention của source thật, nhưng mô hình phải thể hiện rõ các trách nhiệm sau:

- broker catalog: stable ID/code, display fields, enabled flag, display order, audit timestamps;
- trading-server catalog: broker FK, stable ID/name, account type, description, enabled flag, display order;
- credential của account demo đã provision: trading-account FK, server FK, normalized login, salted password hash và trạng thái;
- device-account link: device FK, trading-account FK, linked timestamp, trạng thái;
- active account của device: dùng field/aggregate hiện có hoặc quan hệ một-active-per-device;
- reconnect grant: device/link scope, unique digest, purpose, issued/expiry/revoked timestamps, không có plaintext;
- idempotency record: device scope, operation/route, key, request fingerprint, status và response an toàn cần replay;
- audit/outbox record theo infrastructure hiện có.

Tạo migration có tên rõ ràng, ví dụ `AddMobileLinkedAccounts`, theo convention thật của repository. Migration tối thiểu phải có các FK/index/constraint sau:

- broker code hoặc normalized stable name unique;
- `(BrokerId, NormalizedServerName)` unique;
- `(ServerId, NormalizedLogin)` unique, nhờ đó cùng login được phép tồn tại trên broker/server khác nhau;
- `(DeviceId, TradingAccountId)` unique;
- reconnect-grant digest unique;
- `(DeviceId, Operation, IdempotencyKey)` unique;
- tối đa một active account cho mỗi device, bằng current active-account FK hiện có hoặc filtered unique index tương đương;
- index phục vụ broker/server filtering và device account listing;
- cascade/restrict behavior rõ ràng để không xóa ngầm trading/audit history.

Dùng password hasher hiện có để tạo/verify salted password hash. Không tự dùng SHA-256 thuần cho password. Reconnect grant là random token entropy cao; lưu digest bằng cơ chế token hashing hiện có hoặc HMAC keyed hash phù hợp với security architecture. Mọi so sánh secret dùng primitive constant-time do framework/security library cung cấp.

Seed/catalog data phải đến từ migration/config/admin source được repository cho phép. Chỉ seed identity demo mà tổ chức được quyền hiển thị; không dùng tên/logo để giả mạo broker thật. Tuyệt đối không seed login/mật khẩu/account/balance lấy từ video.

Sinh migration script để review trước khi apply, sau khi thay các placeholder đường dẫn:

```bash
dotnet ef migrations list --project "<DISCOVERED_INFRASTRUCTURE_PROJECT>" --startup-project "<DISCOVERED_API_PROJECT>" --context "<DISCOVERED_DB_CONTEXT>"
dotnet ef migrations script --idempotent --project "<DISCOVERED_INFRASTRUCTURE_PROJECT>" --startup-project "<DISCOVERED_API_PROJECT>" --context "<DISCOVERED_DB_CONTEXT>" --output linked-accounts-idempotent.sql
```

Review script và xác nhận không có cột plaintext password/grant/token, không drop/rename dữ liệu ngoài scope, index/constraint đúng và rollback strategy tương thích cơ chế deploy hiện hữu. Không commit file script chứa connection string hoặc dữ liệu môi trường.

## 7. Luồng nghiệp vụ, transaction và idempotency

### 7.1 Catalog/list

- Query bằng EF Core projection trực tiếp sang response DTO; không serialize entity có navigation/secret.
- Dùng `AsNoTracking`, cancellation token và query có index.
- Không N+1.
- Device authorization luôn chạy trước khi trả catalog/list.

### 7.2 Link

Trong một transaction SQL Server:

1. resolve và khóa scope device phù hợp;
2. claim idempotency key theo `(DeviceId, Operation, Key)`;
3. fingerprint canonical method + route + body sau khi đã loại password khỏi dữ liệu log; fingerprint có thể bao gồm HMAC của request để phát hiện body khác mà không lưu password;
4. validate broker/server relation và enabled state;
5. tìm credential theo `(ServerId, NormalizedLogin)`;
6. verify password bằng password hasher hiện có; unknown login và wrong password phải có behavior/timing/message tương đương;
7. từ chối account disabled;
8. tạo device-account link hoặc lấy link hiện có, không tạo duplicate;
9. tạo reconnect grant và chỉ persist digest/metadata;
10. ghi audit an toàn và idempotency result;
11. commit rồi mới trả response có plaintext grant một lần.

Hai request đồng thời cùng device/account không được tạo hai link hoặc hai grant hợp lệ ngoài semantics replay. Nếu unique-key race xảy ra, đọc kết quả đã commit và replay đúng response an toàn.

### 7.3 Activate

Trong một transaction SQL Server:

1. resolve device và claim idempotency key;
2. tìm link bằng cả `DeviceId` và `accountId`, khóa row/aggregate cần thiết;
3. kiểm tra account/link/server vẫn enabled;
4. cập nhật active account và version/generation của device theo concurrency convention hiện có;
5. dùng chính bootstrap builder hiện có để tạo snapshot đầy đủ nhìn thấy active account mới trong cùng transaction; nếu build/validation thất bại trước commit thì rollback toàn bộ active change, audit, outbox và idempotency write;
6. assert ba account ID bằng nhau;
7. ghi audit và outbox/account-change intent trong transaction;
8. commit;
9. chỉ sau commit mới publish `ActiveAccountChanged` qua SignalR/event mechanism hiện có. Ưu tiên transactional outbox hiện có; nếu publisher hậu commit lỗi, trạng thái DB không rollback, event phải có retry/observability và không được phát event giả cho account cũ;
10. trả `account + bootstrap` đã chuẩn bị.

Activation của account vốn đã active vẫn trả `200` với account và bootstrap đầy đủ, không tạo side effect lặp. Nếu activation cạnh tranh với mutation account-scoped khác, dùng concurrency/version hiện có để không tạo mixed snapshot; trả `409 concurrency_conflict` khi không thể serialize an toàn.

### 7.4 Idempotency

- Cùng device + operation + key + cùng canonical request phải replay cùng status code và cùng semantic result, không chạy lại password/grant/link/activation side effect.
- Cùng key nhưng khác method/route/body fingerprint trả `409 idempotency_key_reused`.
- Idempotency scope không được dùng chung giữa hai device.
- Không lưu raw password trong idempotency body/response. Nếu link response có reconnect grant, cơ chế replay phải đáp ứng security policy hiện có mà không lưu plaintext; lựa chọn an toàn là bảo vệ response bằng data-protection/key-management hiện hữu với TTL bằng idempotency window, hoặc trả lại cùng grant qua token-vault hiện có. Không được băm rồi giả vờ có thể phục hồi grant.
- Ghi rõ lựa chọn và threat model trong security/implementation report.

## 8. Error contract có cấu trúc

Mọi lỗi `400`, `401`, `404`, `409`, `422` — và lỗi `500` an toàn nếu xảy ra — trả JSON object:

```json
{
  "code": "invalid_credentials",
  "message": "Unable to link this virtual account.",
  "correlationId": "7c36ae4c-f966-46be-b44b-f6e68fc08152",
  "errors": null
}
```

`code`, `message`, `correlationId` là string khác rỗng. `errors` là object field-validation không chứa giá trị input nhạy cảm hoặc `null`. Đồng thời set response header `X-Correlation-Id` bằng cùng giá trị.

Mapping tối thiểu:

| HTTP | `code` | Khi nào |
|---|---|---|
| 400 | `invalid_request` | JSON/field/header/path/query sai định dạng |
| 401 | `device_token_invalid` | device token thiếu, sai, hết hạn hoặc revoked |
| 401 | `invalid_credentials` | login không tồn tại hoặc password sai; không phân biệt hai trường hợp |
| 404 | `broker_not_found` | broker không tồn tại/không được phép thấy |
| 404 | `server_not_found` | server không tồn tại/không được phép thấy |
| 404 | `account_not_found` | link không tồn tại hoặc thuộc device khác |
| 409 | `idempotency_key_reused` | cùng key nhưng request fingerprint khác |
| 409 | `concurrency_conflict` | không thể hoàn tất activation nhất quán do concurrent change |
| 422 | `server_mismatch` | server không thuộc broker đã gửi |
| 422 | `account_disabled` | account/link/server bị disabled |
| 422 | `link_rejected` | domain rule demo từ chối nhưng request hợp lệ cú pháp |
| 500 | `internal_error` | lỗi ngoài dự kiến; message chung, tra cứu bằng correlation ID |

Không đưa login, password, grant, token, hash, connection string, stack trace hoặc trạng thái account của device khác vào error body/log/audit.

## 9. Audit, observability và publication

Ghi audit bằng hệ thống hiện có cho ít nhất:

- link created;
- existing link authenticated;
- link rejected với reason code không nhạy cảm;
- account activated, gồm previous/new internal account ID;
- activation rejected;
- reconnect grant issued/revoked/expired;
- idempotency conflict;
- post-commit publication success/failure.

Audit chứa actor/device internal ID, action, target internal ID, UTC timestamp, correlation ID, outcome/reason code. Không chứa request body, login nếu policy xem là dữ liệu nhạy cảm, password, hash, raw grant hoặc raw device token.

Event `ActiveAccountChanged` chỉ được enqueue/publish sau commit thành công. Payload theo event contract hiện có, tối thiểu đủ để client invalidates bootstrap; không gửi credential/grant. Không publish khi transaction rollback, authorization fail hoặc idempotency replay không tạo thay đổi mới.

## 10. Test-first bắt buộc

Viết test thất bại trước implementation. Dùng SQL Server integration fixture/container tương thích repository; không dùng EF Core InMemory để chứng minh unique constraint, transaction hoặc concurrency.

Tối thiểu phải có các test độc lập sau:

1. broker filtering: trim, case-insensitive, query rỗng, stable ordering, disabled row bị loại;
2. server filtering: scope đúng broker, stable ordering, disabled row bị loại;
3. credentials đúng tạo link, hash được verify và response không có secret field;
4. password sai và login không tồn tại cùng trả `401 invalid_credentials`, không rò thông tin;
5. server thuộc broker khác trả `422 server_mismatch`;
6. account/server/link disabled trả `422 account_disabled` theo endpoint;
7. cùng idempotency key + cùng body replay semantic response và chỉ có một link/grant/audit side effect;
8. cùng idempotency key + khác body trả `409 idempotency_key_reused`;
9. hai submit đồng thời không tạo duplicate;
10. duplicate existing link verify credential và trả `alreadyLinked: true`;
11. device isolation: device B không list link của A và activate ID của A nhận `404`;
12. cùng `login` trên broker/server khác nhau liên kết đúng account tương ứng, không collision toàn cục;
13. activation transaction cập nhật đúng active account/version và chỉ một account active;
14. activate response chứa bootstrap đầy đủ từ existing builder;
15. `account.id == bootstrap.activeAccount.id == bootstrap.summary.accountId`;
16. activation account đã active là idempotent và trả bootstrap đầy đủ;
17. lỗi trước commit ở update/bootstrap/audit/outbox làm rollback active state và không publish event;
18. publisher lỗi sau commit không đảo ngược active state, được retry/quan sát theo cơ chế hiện có;
19. event chỉ xuất hiện sau commit và không xuất hiện trên rollback/replay không-op;
20. migration unique/index/FK behavior trên SQL Server;
21. mọi error `400/401/404/409/422` có `code`, `message`, `correlationId`, header correlation tương ứng;
22. secret leakage test quét response, structured logs, audit payload, exception và OpenAPI examples để đảm bảo không có plaintext password/grant/token/hash;
23. authorization test cho mọi route, kể cả catalog;
24. cancellation token và timeout không để transaction/lock treo.

Test contract HTTP phải assert đúng method, route `/api/v2/mobile/...`, query, JSON casing, empty `{}` của activate và các header bắt buộc. Thêm regression test so sánh shape bootstrap activate với shape bootstrap canonical hiện có, không copy một DTO rút gọn vào test.

Chạy focused test trước, rồi toàn bộ solution sau khi thay đường dẫn thật:

```bash
dotnet test "<DISCOVERED_INTEGRATION_TEST_PROJECT>" -c Release --filter "FullyQualifiedName~MobileAccount" --logger "console;verbosity=detailed"
dotnet build "<DISCOVERED_SOLUTION_FILE>" -c Release --no-restore
dotnet test "<DISCOVERED_SOLUTION_FILE>" -c Release --no-build --logger "console;verbosity=normal"
```

Không báo test xanh nếu command timeout, bị skip ngoài dự kiến, dùng database khác SQL Server cho integration behavior hoặc chỉ chạy test mock controller.

## 11. OpenAPI và compatibility

Cập nhật OpenAPI source/generated artifact thật tại `<DISCOVERED_OPENAPI_FILE>`:

- đủ năm route, query/path/header parameter;
- request/response schema và example đúng casing nêu trên;
- `X-Device-Token`, `X-Correlation-Id`, mutation `Idempotency-Key` là required;
- success code `200`;
- structured error schema cho `400/401/404/409/422/500`;
- `password` chỉ xuất hiện trong link request, format `password`, không có example thật;
- `reconnectGrant` chỉ xuất hiện ở link response, nullable/opaque, không có example reusable;
- linked-account DTO không có secret/hash;
- activate bootstrap reference đúng canonical mobile bootstrap schema hiện có;
- mô tả rõ virtual/demo-only và device isolation.

Generate/validate OpenAPI bằng command hiện có của repository. Diff route cũ để chứng minh không thay hoặc xóa `/ex/api/api/*` và không phá các endpoint EX V2 hiện hữu.

## 12. Security review trước deploy

Tự review và ghi bằng chứng:

- HTTPS bắt buộc tại ingress; không cho password qua HTTP;
- request-body logging tắt/redact cho link;
- rate limit theo device/IP cho credential verification nhưng không làm đổi error contract;
- chống user/account enumeration;
- password hasher có salt/work factor theo chuẩn hiện có;
- grant random, hashed, scoped, expiring, revocable và có cleanup;
- idempotency không lưu plaintext secret;
- EF query không trả secret entity;
- authorization nằm trước data disclosure và được recheck trong mutation transaction;
- SQL injection không thể xảy ra qua query/login;
- catalog URL/logo được validate theo policy hiện có;
- audit và SignalR payload không có secret;
- secrets lấy từ secret manager/environment của deployment hiện hữu, không commit `.env` thật.

## 13. Staging smoke test và deploy

Không dùng credential thật hoặc credential từ video. Tạo/dùng fixture tài khoản **virtual staging** qua provisioning mechanism hợp lệ của EX V2. Cấp secrets qua secret store của CI/runtime; không ghi literal vào shell history, tài liệu hay artifact.

Trước deploy, capture:

- commit SHA/image digest;
- migration list và idempotent SQL review;
- health/readiness hiện tại;
- baseline legacy smoke cho `/ex/api/api/*` theo tài liệu hiện có;
- backup/restore checkpoint theo deployment policy.

Deploy bằng đúng `<DISCOVERED_DEPLOYMENT_DOC_OR_SCRIPT>`. Không tự nghĩ ra `docker compose`, systemd, Kubernetes hay SSH flow mới nếu repo đã có cơ chế chuẩn. Apply migration theo cơ chế deploy hiện có, bảo đảm multi-instance compatibility và rollback window.

Smoke staging qua public ingress với secrets trong environment. Ví dụ GET an toàn; không dùng `-v` và không in token:

```bash
set -euo pipefail
: "${EXV2_STAGING_BASE_URL:?required}"
: "${EXV2_STAGING_DEVICE_TOKEN:?required}"
CORRELATION_ID="$(uuidgen)"
curl --fail-with-body --silent --show-error \
  -H "X-Device-Token: ${EXV2_STAGING_DEVICE_TOKEN}" \
  -H "X-Correlation-Id: ${CORRELATION_ID}" \
  "${EXV2_STAGING_BASE_URL}/mobile/brokers?query=" | jq 'map({id,name})'
```

Với link/activate smoke, tạo JSON bằng tool lấy secret từ environment/stdin, pipe thẳng vào `curl --data-binary @-`, lưu response vào file tạm có quyền hạn chế, chỉ assert các field không nhạy cảm và xóa file sau test. Không in password, reconnect grant hoặc device token. Smoke phải chứng minh:

- filter broker/server hoạt động;
- link virtual staging account thành công;
- replay cùng idempotency key không tạo duplicate;
- list chỉ thấy link của device;
- activate trả bootstrap đầy đủ và ba account ID trùng;
- SignalR client của test nhận invalidation/account-change sau commit;
- restart service không mất link/active selection;
- legacy `/ex/api/api/*` vẫn có baseline tương đương.

Thực hiện rollback rehearsal bằng đúng `<DISCOVERED_ROLLBACK_DOC_OR_SCRIPT>` hoặc môi trường rehearsal được quy định. Ghi bằng chứng rollback app version và chiến lược database tương thích; không chạy destructive down-migration trên production nếu policy cấm. Sau rollback, health và legacy smoke phải xanh.

## 14. Definition of Done / acceptance checklist

Chỉ đánh dấu hoàn thành khi tất cả mục sau có bằng chứng:

- [ ] Đã đọc và liệt kê AGENTS/README/architecture/security/deployment docs của source EX V2 thật.
- [ ] Không có thay đổi nào trong `D:/mt5New/backend`.
- [ ] Baseline và final build/test của solution EX V2 xanh.
- [ ] Năm route `/api/v2/mobile/...` tồn tại đúng method/path và public proxy tạo đúng `/ex/v2/api/mobile/...` mà Flutter đang gọi.
- [ ] Mọi route yêu cầu `X-Device-Token`, `X-Correlation-Id`; mutations yêu cầu `Idempotency-Key`.
- [ ] Broker/server catalog filter ổn định và không chứa hard-coded video account data.
- [ ] Link request đúng `brokerId`, `serverId`, `login`, `password`, `savePassword`.
- [ ] List/link/activate response đúng field/casing Flutter model đang parse.
- [ ] Activate nhận body `{}` và trả `account + bootstrap` canonical đầy đủ.
- [ ] Ba account ID trong activate response luôn giống nhau.
- [ ] Password dùng existing salted hasher; plaintext không persist/log.
- [ ] Reconnect grants hashed, scoped, expiring, revocable; plaintext chỉ trả ở boundary cho phép.
- [ ] Unique constraints cho catalog, credential natural key, device link, grant digest và idempotency key đã được kiểm chứng trên SQL Server.
- [ ] Device isolation và authorization pass cho list/activate, kể cả foreign ID.
- [ ] Link/activate transaction, concurrent request, replay và rollback tests xanh.
- [ ] `ActiveAccountChanged` chỉ publish sau commit; failure/retry có bằng chứng.
- [ ] Structured `400/401/404/409/422/500` có correlation ID và không có secret.
- [ ] OpenAPI đã update/validate và legacy `/ex/api/api/*` không đổi.
- [ ] Migration script đã review, deploy staging thành công, smoke test qua public ingress xanh.
- [ ] Có commit/image/migration/health/SignalR/legacy/rollback evidence.
- [ ] Không kết nối hoặc giả mạo tài khoản Exness/MetaQuotes thật.

## 15. Báo cáo cuối phải nộp

Tạo một implementation report trong repository EX V2, theo convention docs hiện có, gồm:

1. status: implemented / blocked; tuyệt đối không ghi implemented nếu chưa deploy/verify;
2. source root, solution/project/test/OpenAPI/deploy/rollback paths đã phát hiện;
3. commit SHA và danh sách file thay đổi;
4. tóm tắt schema, constraints và migration;
5. bảng route + request/response/error;
6. security decisions cho password, reconnect grant, idempotency và redaction;
7. transaction/concurrency/outbox flow;
8. TDD RED/GREEN evidence và exact command/output counts;
9. migration review và OpenAPI diff evidence;
10. staging smoke evidence, không chép secret;
11. deployment evidence: version/image digest, health, migration state;
12. rollback rehearsal/evidence;
13. legacy `/ex/api/api/*` regression evidence;
14. unresolved concerns và follow-up có owner rõ ràng.

Trước khi kết thúc, quét source, migration, test, OpenAPI, report và log artifact để chắc chắn không có credential/token/grant thật; chạy `git diff --check`; kiểm tra `git status`; chỉ commit đúng phạm vi EX V2 đã review.
