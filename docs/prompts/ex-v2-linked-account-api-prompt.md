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

Sau đó tìm, đọc implementation/test và ghi lại đường dẫn thật cùng behavior đã kiểm chứng của các thành phần sau:

- solution `.sln` hoặc `.slnx`;
- API/startup project;
- application/domain/infrastructure projects;
- `DbContext`, migration assembly và migration gần nhất;
- controller/endpoint hiện có của `GET /api/v2/mobile/bootstrap`;
- device-token resolver hiện có;
- reconnect-grant consumer/reconnect boundary, data-protection/key-management và secret-key rotation hiện có;
- bootstrap builder hiện có;
- password hasher hiện có;
- audit writer hiện có;
- SignalR/outbox/event publisher của `ActiveAccountChanged` hoặc event tương đương;
- idempotency và correlation middleware/filter hiện có;
- integration-test project và test fixture SQL Server;
- OpenAPI source/generated artifact;
- toàn bộ public-ingress chain trước Kestrel (CDN/WAF/load balancer/Nginx hoặc reverse proxy tương đương), raw-path/rewrite/escaped-separator configuration và ASP.NET Core routing behavior;
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

Cũng phải dừng và báo blocker nếu không tìm thấy hoặc không thể xác lập behavior bằng source/test cho **bất kỳ primitive bắt buộc hiện hữu nào**: device-token resolver, reconnect-grant consumer/reconnect boundary, data-protection/key-management và key rotation, canonical bootstrap builder, password hasher, audit writer, correlation pipeline, idempotency mechanism/key store, transaction boundary, transactional outbox và outbox dispatcher, SignalR/event transport, OpenAPI generation, migration mechanism, deploy và rollback. Không tự chế hasher, token resolver, grant consumer, encryption vault, audit, idempotency, event bus hay deployment flow song song để lấp khoảng trống. Báo chính xác primitive nào thiếu, các path đã tìm và bằng chứng search/baseline.

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

Không đổi tên route, HTTP method, field JSON hoặc casing. Ở HTTP boundary, `brokerId`, `serverId` và `accountId` là **opaque string khác rỗng**. Flutter giữ nguyên string và gọi `Uri.encodeComponent` cho path segment, nên ID logic `broker/one` được gửi thành `broker%2Fone`. Server chỉ được nhận ID chứa `/` theo nhánh A của cổng encoded-slash dưới đây; nếu ingress không chứng minh được behavior đó thì phải dùng nhánh B với public ID segment-safe. Không được ngầm thay `/` bằng `_`, decode hai lần hoặc để JSON trả một ID nhưng route lookup đòi ID khác.

Chỉ được thêm OpenAPI `format: uuid` và `Guid.TryParse` sau khi source entity, bootstrap/OpenAPI hiện hữu và integration fixtures của EX V2 cùng chứng minh **toàn bộ** ID tương ứng là GUID; phải ghi bằng chứng đó trong implementation report và có compatibility test. Nếu chưa đủ bằng chứng, giữ `type: string`, không reject ID chỉ vì không phải GUID. Các UUID-like value trong ví dụ dưới đây chỉ là dữ liệu minh họa không thật, không phải ràng buộc kiểu.

### 3.1 Cổng encoded slash qua public ingress

Trước khi chốt schema ID hoặc triển khai route, trace request qua **đúng public staging ingress** có topology/config tương đương production: CDN/WAF/load balancer/reverse proxy, rewrite từ `/ex/v2/api` sang `/api/v2`, Kestrel/ASP.NET Core routing và model binding. Không dùng direct Kestrel port hoặc `WebApplicationFactory` làm bằng chứng duy nhất.

Phải chọn và tài liệu hóa đúng một trong hai nhánh; không để runtime tự rơi qua lại:

**Nhánh A — giữ opaque ID có `/`, chỉ khi E2E probe xanh:**

- provision synthetic staging broker ID `broker/one` và linked-account ID `account/one` bằng fixture/provisioning hợp lệ;
- gọi qua public ingress với `--path-as-is` tới `GET /ex/v2/api/mobile/brokers/broker%2Fone/servers?query=` và `PUT /ex/v2/api/mobile/accounts/account%2Fone/activate`;
- chứng minh raw ingress path chứa `%2F`, proxy không reject/normalize thành separator route, và ASP.NET route value sau **đúng một lần decode** bằng chính xác `broker/one` hoặc `account/one`;
- response server/account ID phải bằng logical ID ban đầu; activate vẫn giữ ba-way account-ID equality;
- `%252F` không được decode lần hai thành `/`; raw `/`, invalid percent encoding, encoded backslash `%5C`, dot-segment và alternate casing `%2f` phải có behavior được test/tài liệu hóa, không resolve sang identity khác;
- authorization chạy sau khi resolve canonical identity bằng exact match và vẫn scope theo device. Encoded/double-encoded variant không được bypass foreign-device `404` hoặc map sang row khác;
- chỉ enable/giữ escaped-separator behavior ở đúng route/scope cần thiết sau security review; không bật permissive global proxy normalization nếu có thể ảnh hưởng route legacy.

**Nhánh B — bắt buộc nếu bất kỳ ingress layer reject, split, normalize hoặc không chứng minh được `%2F`:**

- thêm immutable `PublicId` segment-safe cho broker, server và linked account, unique/indexed, sinh bằng UUID hoặc CSPRNG base64url không padding; chỉ cho phép `[A-Za-z0-9_-]`, không chứa `/`, `%`, `?`, `#`, `\` hoặc dot-segment;
- không biến đổi lossy internal ID (`Replace`, lowercase, slugify) để tạo public ID; lưu mapping một-một rõ ràng và backfill bằng migration reviewable;
- expose public ID trong **các field hiện có**, không thêm một parallel field mà Flutter không đọc: broker `id`; server `id`/`brokerId`; linked account `id`/`brokerId`/`serverId`; link/activate `account`; canonical `/mobile/bootstrap` `activeAccount.id` và `summary.accountId`;
- link request dùng public `brokerId`/`serverId` nhận từ catalog; activate path dùng public `accountId` nhận từ list/link. Sau device authorization, server map exact public ID sang internal key; không fallback thử internal ID và không accept hai namespace mơ hồ;
- giữ `account.id == bootstrap.activeAccount.id == bootstrap.summary.accountId` bằng cùng public account ID; internal IDs không rò ra mobile JSON/log/error;
- update migration, projections, bootstrap builder, OpenAPI, tests và staging fixtures atomically. Một app nhận catalog/list trước deploy không được bị mismatch route sau deploy; dùng deployment compatibility/rollback mechanism hiện có.

Nếu không chạy được public-ingress probe nhánh A và cũng không thể triển khai/verify nhánh B nhất quán, dừng task ở trạng thái blocked. Không tuyên bố hỗ trợ slash ID dựa trên unit/in-process test.

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
- `brokerId`, `serverId` là opaque string khác rỗng; chỉ validate GUID khi đã đạt cổng bằng chứng ở mục 3;
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
  "reconnectGrant": "opaque-non-reusable-example",
  "alreadyLinked": false
}
```

Quy tắc response:

- `alreadyLinked` là `false` khi tạo link mới, `true` khi đúng account đã liên kết với thiết bị.
- Dù link đã tồn tại, vẫn phải verify lại password và trạng thái account trước khi trả thành công.
- Không tự kích hoạt account trong endpoint link; Flutter gọi endpoint activate ngay sau đó. `isActive` phản ánh trạng thái thật tại thời điểm trả response.
- Mỗi **idempotency operation link đã commit** phát hành đúng một reconnect grant ngẫu nhiên, entropy cao. Request replay đã xác thực trong idempotency window được phép nhận lại **chính grant của operation đó** từ replay payload đã được bảo vệ; replay không phát hành grant mới và không tạo thêm audit side effect nghiệp vụ.
- Một link authentication thành công dùng idempotency key mới là một operation mới: trong cùng transaction, revoke grant live trước đó rồi tạo grant thay thế. Sau commit chỉ được có một grant current, chưa revoke cho `(DeviceId, DeviceAccountLinkId, Purpose)`. Không cố ý cho phép nhiều live grant.
- Database chính chỉ lưu digest không thể đảo ngược cùng device/link/purpose, issued-at, expiry, revoked-at và replacement metadata. Plaintext chỉ tồn tại tạm ở response boundary hoặc trong idempotency replay payload được mã hóa/xác thực bằng data-protection/key-management hiện có; không lưu plaintext hoặc reversible value trong grant table.
- Với `savePassword: true`, grant dùng TTL lưu đăng nhập do security configuration hiện có quy định. Với `savePassword: false`, grant dùng TTL phiên/ngắn hạn do cùng security configuration quy định; client chỉ giữ trong memory và server vẫn chỉ lưu hash. Không hard-code TTL trong controller.
- Link success luôn có `reconnectGrant` là opaque string khác rỗng, không nullable. Link response không có field `password`, `passwordHash`, `grantHash` hoặc device token.

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
- reconnect grant: device/link scope, unique non-reversible digest, purpose, issued/expiry/revoked timestamps, replacement relation/current marker, không có plaintext;
- idempotency record: device scope, operation/route, key, fingerprint version/key ID/digest, status, expiry và response replay đã được data-protect; không có raw request/password/grant;
- audit/outbox record theo infrastructure hiện có.

Tạo migration có tên rõ ràng, ví dụ `AddMobileLinkedAccounts`, theo convention thật của repository. Migration tối thiểu phải có các FK/index/constraint sau:

- broker code hoặc normalized stable name unique;
- `(BrokerId, NormalizedServerName)` unique;
- `(ServerId, NormalizedLogin)` unique, nhờ đó cùng login được phép tồn tại trên broker/server khác nhau;
- `(DeviceId, TradingAccountId)` unique;
- reconnect-grant digest unique;
- constraint/current pointer bảo đảm tối đa một grant current chưa revoke trên `(DeviceId, DeviceAccountLinkId, Purpose)`; transaction revoke–replace phải chịu concurrency lock;
- `(DeviceId, Operation, IdempotencyKey)` unique;
- tối đa một active account cho mỗi device, bằng current active-account FK hiện có hoặc filtered unique index tương đương;
- index phục vụ broker/server filtering và device account listing;
- cascade/restrict behavior rõ ràng để không xóa ngầm trading/audit history.

Dùng password hasher hiện có để tạo/verify salted password hash. Không tự dùng SHA-256 thuần cho password. Reconnect grant là random token entropy cao; lưu digest bằng cơ chế token hashing hiện có hoặc keyed HMAC phù hợp với security architecture. Mọi so sánh secret dùng primitive constant-time do framework/security library cung cấp. Consumer boundary hiện có phải resolve grant bằng đủ device + link + purpose, kiểm tra digest, current marker, expiry và revoked-at; không chỉ tìm theo digest.

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
3. tạo fingerprint bắt buộc theo canonical algorithm ở mục 7.4; fingerprint phải phân biệt request chỉ khác password mà không lưu/log password;
4. validate broker/server relation và enabled state;
5. tìm credential theo `(ServerId, NormalizedLogin)`;
6. verify password bằng password hasher hiện có; unknown login và wrong password phải có behavior/timing/message tương đương;
7. từ chối account disabled;
8. tạo device-account link hoặc lấy link hiện có, không tạo duplicate;
9. revoke grant current trước đó và tạo đúng một grant thay thế; chỉ persist digest/metadata trong grant table;
10. data-protect response replay chứa chính grant vừa phát hành, gắn TTL bằng idempotency window; ghi idempotency result và audit `grant_issued`/`grant_replaced` an toàn;
11. commit rồi mới trả response; replay hợp lệ có thể tái phát cùng protected grant nhưng không phát hành grant mới.

Hai request đồng thời cùng device/account không được tạo hai link hoặc hai grant current hợp lệ ngoài semantics replay. Nếu unique-key race xảy ra, đọc kết quả đã commit, unprotect replay payload và trả đúng semantic response; không chạy lại verify/issue/revoke. Operation mới cạnh tranh phải serialize trên grant scope để revoke–replace atomically.

### 7.3 Activate

Trong một transaction SQL Server:

1. resolve device và claim idempotency key;
2. tìm link bằng cả `DeviceId` và `accountId`, khóa row/aggregate cần thiết;
3. kiểm tra account/link/server vẫn enabled;
4. cập nhật active account và version/generation của device theo concurrency convention hiện có;
5. dùng chính bootstrap builder hiện có để tạo snapshot đầy đủ nhìn thấy active account mới trong cùng transaction; nếu build/validation thất bại trước commit thì rollback toàn bộ active change, audit, outbox và idempotency write;
6. assert ba account ID bằng nhau;
7. persist audit và đúng một outbox `ActiveAccountChanged` intent trong transaction;
8. commit;
9. chỉ sau commit, **outbox dispatcher là publisher authoritative duy nhất** được dispatch `ActiveAccountChanged` ra SignalR/event mechanism hiện có. Controller/service không direct-publish thêm lần thứ hai. Nếu dispatch lỗi, trạng thái DB không rollback; cùng outbox message được retry/dedupe theo cơ chế hiện có và không phát event giả cho account cũ;
10. trả `account + bootstrap` đã chuẩn bị.

Activation của account vốn đã active vẫn trả `200` với account và bootstrap đầy đủ, không tạo side effect lặp. Nếu activation cạnh tranh với mutation account-scoped khác, dùng concurrency/version hiện có để không tạo mixed snapshot; trả `409 concurrency_conflict` khi không thể serialize an toàn.

### 7.4 Idempotency

- Cùng device + operation + key + cùng canonical request phải replay cùng status code và cùng semantic result, không chạy lại password/grant/link/activation side effect. Với link, replay trong idempotency window tái phát chính protected grant của operation đã commit.
- Cùng key nhưng khác method/route/body fingerprint — kể cả chỉ khác `password` — trả `409 idempotency_key_reused`.
- Idempotency scope không được dùng chung giữa hai device.
- Dùng **một canonical fingerprint versioned bắt buộc** cho từng mutation. Version đầu phải canonicalize bằng length-prefixed UTF-8, không nối chuỗi mơ hồ: HTTP method chuẩn hóa, route template, route ID sau route-decode, `brokerId`, `serverId`, `login` sau rule trim, raw password bytes không trim, `savePassword`, và mọi semantic field hiện tại/tương lai. Activate bao gồm method, route template, decoded `accountId` và empty object semantics.
- Tính `HMAC-SHA-256` trên toàn bộ canonical byte sequence bằng deployment-managed idempotency fingerprint key; lưu `FingerprintVersion`, key ID và digest, không lưu canonical bytes. Cấm unkeyed hash hoặc reversible encryption của password để làm fingerprint. Key lấy từ secret manager, hỗ trợ rotation theo key ID; compare digest constant-time.
- Link replay payload phải được encrypt + authenticate bằng data-protection/key-management hiện hữu và expire cùng idempotency window. Chỉ replay handler được unprotect để trả lại chính grant; không ghi payload đã unprotect vào log/audit. Khi replay record hết hạn, không được âm thầm chạy cùng key như operation mới: trả structured conflict yêu cầu client tạo user action/idempotency key mới theo policy đã ghi trong OpenAPI.
- Ghi rõ canonicalization version, key rotation, replay retention và threat model trong security/implementation report.

## 8. Error contract có cấu trúc

Mọi lỗi `400`, `401`, `404`, `409`, `422`, `429` — và lỗi `500` an toàn nếu xảy ra — trả JSON object:

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
| 409 | `idempotency_record_expired` | replay dùng key đã hết retention; client phải tạo user action/key mới |
| 409 | `concurrency_conflict` | không thể hoàn tất activation nhất quán do concurrent change |
| 422 | `server_mismatch` | server không thuộc broker đã gửi |
| 422 | `account_disabled` | account/link/server bị disabled |
| 422 | `link_rejected` | domain rule demo từ chối nhưng request hợp lệ cú pháp |
| 429 | `rate_limited` | credential-verification limit đạt ngưỡng; trả `Retry-After`, không đổi thông điệp theo login tồn tại/không tồn tại |
| 500 | `internal_error` | lỗi ngoài dự kiến; message chung, tra cứu bằng correlation ID |

Không đưa login, password, grant, token, hash, connection string, stack trace hoặc trạng thái account của device khác vào error body/log/audit.

## 9. Audit, observability và publication

Ghi audit bằng hệ thống hiện có cho ít nhất:

- link created;
- existing link authenticated;
- link rejected với reason code không nhạy cảm;
- account activated, gồm previous/new internal account ID;
- activation rejected;
- reconnect grant issued/replaced/revoked/expired và authenticated replay delivered;
- idempotency conflict;
- post-commit publication success/failure.

Audit chứa actor/device internal ID, action, target internal ID, UTC timestamp, correlation ID, outcome/reason code. Không chứa request body, login nếu policy xem là dữ liệu nhạy cảm, password, hash, raw grant hoặc raw device token.

Outbox intent `ActiveAccountChanged` được **persist atomically bên trong activation transaction**. Chỉ sau commit, outbox dispatcher hiện có mới dispatch ra SignalR/event transport. Dispatcher là publisher authoritative duy nhất; controller/service không direct-publish, nhờ đó không double-publish từ hai đường. Payload theo event contract hiện có, tối thiểu đủ để client invalidate bootstrap; không gửi credential/grant. Transaction rollback không để lại outbox row; authorization failure và idempotency replay/no-op không tạo outbox intent mới. Retry có message ID/dedupe và metric theo convention hiện có.

### 9.1 Cleanup grant bắt buộc

Khám phá và tái sử dụng token-cleanup owner hiện có. Nếu repository không có generic cleanup scheduler nhưng có worker host chuẩn, thêm một bounded `BackgroundService` vào **worker host hiện có**, không tạo service/deployment mới. Owner duy nhất là EX V2 worker/token-cleanup component; API request path không tự xóa hàng loạt.

Quy tắc cleanup chính xác:

- chạy mỗi 60 phút, interval lấy từ strongly typed configuration nhưng default và production value phải được tài liệu hóa;
- dùng distributed lock/single-runner hiện có để tránh nhiều instance cleanup trùng nhau;
- mỗi batch tối đa 1.000 row, có cancellation token và transaction ngắn;
- xóa grant đã expired hoặc revoked **quá 30 ngày**; audit records giữ theo audit-retention policy hiện có và không bị job này xóa;
- idempotency replay payload được xóa theo idempotency retention đã tài liệu hóa, nhưng không trước khi replay window kết thúc;
- emit tối thiểu `exv2_reconnect_grant_cleanup_deleted_total`, `exv2_reconnect_grant_cleanup_failure_total` và `exv2_reconnect_grant_cleanup_last_success_timestamp_seconds` (hoặc tên đã tồn tại được mapping rõ trong report), không gắn device/login/grant label;
- có integration test với clock giả chứng minh row chưa đến hạn được giữ, row quá retention được xóa theo batch, lỗi job không xóa audit và metric success/failure đúng.

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
21. mọi error `400/401/404/409/422/429` có `code`, `message`, `correlationId`, header correlation tương ứng; `429` có thêm `Retry-After`;
22. secret leakage test quét response, structured logs, audit payload, exception và OpenAPI examples để đảm bảo không có plaintext password/grant/token/hash;
23. authorization test cho mọi route, kể cả catalog;
24. cancellation token và timeout không để transaction/lock treo;
25. ID HTTP boundary nhận opaque non-empty string; in-process routing test chứng minh exact match, không silent normalization/double-decode; chỉ chạy GUID-only test nếu cổng evidence mục 3 chứng minh contract GUID;
26. idempotency fingerprint khác khi chỉ `password` thay đổi và trả `409 idempotency_key_reused`; test xác nhận chỉ lưu version/key ID/keyed digest, không raw canonical request hoặc unkeyed password digest;
27. cùng `Idempotency-Key` trên hai device tạo hai scope độc lập, không replay/collision chéo device;
28. grant table chỉ lưu non-reversible digest + device/link/purpose/issued/expiry/revoked/replacement metadata; không có plaintext/reversible grant;
29. qua existing grant consumer boundary: grant đúng scope/current/chưa hết hạn/chưa revoke được chấp nhận; sai device, sai link, sai purpose, expired, revoked và replaced grant đều bị từ chối cùng safe contract;
30. operation link mới atomically revoke–replace grant cũ, để đúng một current grant; concurrent replacement không để lại hai current grant;
31. authenticated idempotency replay trong window trả cùng protected grant và không issue/revoke/audit nghiệp vụ lần hai; replay hết hạn trả `409 idempotency_record_expired`;
32. thiếu, sai, hết hạn và revoked `X-Device-Token` đều trả `401 device_token_invalid` trên **từng route trong năm route**, không chạy query/mutation side effect;
33. credential-verification rate limit được test theo device/IP: đạt ngưỡng trả structured `429 rate_limited` + `Retry-After`, wrong/unknown login không làm khác status/message/timing bucket và không ghi secret;
34. outbox row tồn tại atomically với activation commit, không tồn tại sau rollback; chỉ authoritative dispatcher phát, retry không tạo intent mới hoặc đường direct-publish thứ hai;
35. grant cleanup test với clock giả chứng minh owner/cadence/batch/30-day retention, audit preservation và ba metric không có high-cardinality/secret label;
36. public-staging-ingress E2E test dùng broker `broker/one` và account `account/one`: Flutter-compatible `%2F` path đi qua toàn bộ proxy/Kestrel chain, route-decode đúng một lần, response giữ nguyên logical identity và activate giữ ba-way account-ID equality;
37. security E2E test chứng minh `%252F`, raw slash, invalid percent encoding, `%5C`, dot-segment, casing variant và foreign-device request không double-decode, alias sang row khác hoặc bypass authorization;
38. nếu nhánh A thất bại, migration/projection/contract test của nhánh B chứng minh mọi catalog/list/link/activate/bootstrap ID đều dùng cùng immutable segment-safe public mapping, internal slash ID không được nhận ở public route và rollback compatibility xanh.

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
- structured error schema cho `400/401/404/409/422/429/500`, gồm `Retry-After` cho `429`;
- `password` chỉ xuất hiện trong link request, format `password`, không có example thật;
- `reconnectGrant` là required non-null opaque string chỉ ở link success response; mô tả rõ cùng protected value có thể được re-deliver khi authenticated idempotency replay trong window, không issue grant mới;
- linked-account DTO không có secret/hash;
- các ID HTTP là opaque non-empty `type: string`; chỉ thêm `format: uuid` cho loại ID đã có evidence và compatibility test theo mục 3;
- OpenAPI phải phản ánh **duy nhất nhánh ID đã chọn**. Nhánh A dùng logical example `broker/one` và `account/one`, đồng thời mô tả wire path `broker%2Fone`/`account%2Fone` cùng exactly-once decode. Nhánh B dùng segment-safe examples và regex/pattern `[A-Za-z0-9_-]+`; không trộn internal slash ID vào public example;
- mô tả rõ không double-decode, không silent normalize và foreign-ID lookup vẫn trả `404` sau device-scoped authorization;
- mô tả versioned keyed-HMAC fingerprint, password-only conflict, device scope, replay expiry và atomic grant revoke–replace mà không công bố key/digest;
- activate bootstrap reference đúng canonical mobile bootstrap schema hiện có;
- mô tả rõ virtual/demo-only và device isolation.

Generate/validate OpenAPI bằng command hiện có của repository. Diff route cũ để chứng minh không thay hoặc xóa `/ex/api/api/*` và không phá các endpoint EX V2 hiện hữu.

## 12. Security review trước deploy

Tự review và ghi bằng chứng:

- HTTPS bắt buộc tại ingress; không cho password qua HTTP;
- request-body logging tắt/redact cho link;
- rate limit theo device/IP cho credential verification; dùng structured `429 rate_limited` + `Retry-After` giống nhau cho wrong/unknown login và không tạo enumeration side channel;
- chống user/account enumeration;
- password hasher có salt/work factor theo chuẩn hiện có;
- grant random, hashed, scoped, expiring, revocable, atomic revoke–replace, protected replay và có cleanup owner/cadence/retention/test/metrics ở mục 9.1;
- idempotency không lưu plaintext secret;
- EF query không trả secret entity;
- authorization nằm trước data disclosure và được recheck trong mutation transaction;
- encoded separator/double-encoding không làm thay đổi identity, route selection hoặc bypass device authorization; ingress rule chỉ áp dụng đúng route đã review và không làm yếu route legacy;
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

### 13.1 Public-ingress encoded-slash staging gate

Trước production deploy, chạy test với synthetic fixtures `broker/one` và `account/one` qua **public staging base**, không qua loopback/direct Kestrel. Dùng `--path-as-is` để curl không tự normalize URL. Ví dụ chỉ in các field identity không nhạy cảm:

```bash
set -euo pipefail
: "${EXV2_STAGING_BASE_URL:?required}"
: "${EXV2_STAGING_DEVICE_TOKEN:?required}"

CORRELATION_ID="$(uuidgen)"
curl --path-as-is --fail-with-body --silent --show-error \
  -H "X-Device-Token: ${EXV2_STAGING_DEVICE_TOKEN}" \
  -H "X-Correlation-Id: ${CORRELATION_ID}" \
  "${EXV2_STAGING_BASE_URL}/mobile/brokers/broker%2Fone/servers?query=" \
  | jq 'map({id,brokerId,name})'

CORRELATION_ID="$(uuidgen)"
IDEMPOTENCY_KEY="$(uuidgen)"
curl --path-as-is --fail-with-body --silent --show-error \
  -X PUT \
  -H "Content-Type: application/json" \
  -H "X-Device-Token: ${EXV2_STAGING_DEVICE_TOKEN}" \
  -H "X-Correlation-Id: ${CORRELATION_ID}" \
  -H "Idempotency-Key: ${IDEMPOTENCY_KEY}" \
  --data-binary '{}' \
  "${EXV2_STAGING_BASE_URL}/mobile/accounts/account%2Fone/activate" \
  | jq '{accountId:.account.id,activeAccountId:.bootstrap.activeAccount.id,summaryAccountId:.bootstrap.summary.accountId}'
```

Test phải assert server response thuộc `broker/one`, và ba account ID đều đúng `account/one`. Đồng thời chạy negative probes `%252F`, raw slash, invalid encoding, `%5C`, dot-segment và foreign-device token; chúng không được resolve thành fixture slash ID hoặc vượt device scope. Thu thập bằng chứng từ ingress access log an toàn/raw-target diagnostics và application route-value assertion mà không log token.

Nếu bất kỳ positive probe nào bị proxy/WAF/Kestrel reject, split hoặc normalize, **không sửa client và không tuyên bố nhánh A pass**. Chọn nhánh B, triển khai public ID segment-safe nhất quán, rồi smoke lại bằng ID lấy trực tiếp từ broker/account JSON. Assert ID match regex, link/activate chấp nhận đúng ID đó, bootstrap dùng cùng account ID, internal `broker/one`/`account/one` không được accept như public alias, và foreign-device authorization vẫn `404`. Ghi lại failure evidence nhánh A và success evidence nhánh B trong report/OpenAPI.

Thực hiện rollback rehearsal bằng đúng `<DISCOVERED_ROLLBACK_DOC_OR_SCRIPT>` hoặc môi trường rehearsal được quy định. Ghi bằng chứng rollback app version và chiến lược database tương thích; không chạy destructive down-migration trên production nếu policy cấm. Sau rollback, health và legacy smoke phải xanh.

## 14. Definition of Done / acceptance checklist

Chỉ đánh dấu hoàn thành khi tất cả mục sau có bằng chứng:

- [ ] Đã đọc và liệt kê AGENTS/README/architecture/security/deployment docs của source EX V2 thật.
- [ ] Đã tìm được và chứng minh behavior của mọi existing primitive bắt buộc; nếu thiếu bất kỳ primitive nào thì task dừng ở trạng thái blocked, không có implementation song song.
- [ ] Không có thay đổi nào trong `D:/mt5New/backend`.
- [ ] Baseline và final build/test của solution EX V2 xanh.
- [ ] Năm route `/api/v2/mobile/...` tồn tại đúng method/path và public proxy tạo đúng `/ex/v2/api/mobile/...` mà Flutter đang gọi.
- [ ] Mọi route yêu cầu `X-Device-Token`, `X-Correlation-Id`; mutations yêu cầu `Idempotency-Key`.
- [ ] Broker/server catalog filter ổn định và không chứa hard-coded video account data.
- [ ] Link request đúng `brokerId`, `serverId`, `login`, `password`, `savePassword`.
- [ ] List/link/activate response đúng field/casing Flutter model đang parse.
- [ ] ID tại HTTP boundary là opaque non-empty string; GUID-only validation chỉ tồn tại khi report có source/OpenAPI/fixture evidence tương ứng.
- [ ] Đã chọn đúng một ID strategy: nhánh A có public-ingress `%2F` E2E proof qua actual proxy/Kestrel, hoặc nhánh B dùng immutable segment-safe public IDs nhất quán trong catalog/list/link/activate/canonical bootstrap.
- [ ] Exactly-once decode và negative `%252F`/raw slash/invalid encoding/`%5C`/dot-segment/foreign-device tests chứng minh không normalization mismatch, alias hoặc authorization bypass.
- [ ] Activate nhận body `{}` và trả `account + bootstrap` canonical đầy đủ.
- [ ] Ba account ID trong activate response luôn giống nhau.
- [ ] Password dùng existing salted hasher; plaintext không persist/log.
- [ ] Mỗi committed link operation issue đúng một reconnect grant; authenticated replay trả cùng protected grant, operation mới atomically revoke–replace grant cũ và chỉ còn một current grant.
- [ ] Grant table chỉ có non-reversible digest + scope/TTL/revocation/replacement metadata; existing consumer boundary đã test valid/wrong-scope/expired/revoked/replaced grant.
- [ ] Versioned canonical idempotency fingerprint dùng keyed HMAC trên toàn bộ semantic request, gồm raw password; password-only change trả `409` và không có raw/unkeyed password digest.
- [ ] Unique constraints cho catalog, credential natural key, device link, grant digest và idempotency key đã được kiểm chứng trên SQL Server.
- [ ] Device isolation và authorization pass cho list/activate, kể cả foreign ID.
- [ ] Cùng idempotency key được scope độc lập giữa hai device; missing/invalid/expired/revoked device token đã test trên cả năm route.
- [ ] Credential rate limit pass integration test và giữ structured/no-enumeration contract.
- [ ] Link/activate transaction, concurrent request, replay và rollback tests xanh.
- [ ] Activation persist outbox intent trong transaction; authoritative outbox dispatcher duy nhất publish `ActiveAccountChanged` sau commit, không có direct double-publish; failure/retry có bằng chứng.
- [ ] Grant cleanup có owner, cadence 60 phút, batch 1.000, retention 30 ngày, integration test và metrics không chứa secret/high-cardinality label.
- [ ] Structured `400/401/404/409/422/429/500` có correlation ID và không có secret; `429` có `Retry-After`.
- [ ] OpenAPI chỉ mô tả strategy ID đã chọn, có đúng logical/wire examples, và legacy `/ex/api/api/*` không đổi.
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
6. security decisions cho password, reconnect grant issue/replay/revoke–replace, versioned keyed-HMAC idempotency fingerprint/key rotation và redaction;
7. transaction/concurrency/outbox flow, chứng minh outbox dispatcher là authoritative publisher duy nhất;
8. TDD RED/GREEN evidence và exact command/output counts;
9. migration review và OpenAPI diff evidence;
10. staging smoke evidence, không chép secret;
11. deployment evidence: version/image digest, health, migration state;
12. rollback rehearsal/evidence;
13. legacy `/ex/api/api/*` regression evidence;
14. ID-type evidence: opaque string compatibility, hoặc source/OpenAPI/fixture evidence nếu đã dùng GUID validation;
15. public-ingress chain/config và encoded-slash decision evidence: nhánh A positive/negative raw-path + exactly-once decode/authorization probes, hoặc nhánh A failure và nhánh B segment-safe mapping/compatibility proof;
16. cleanup owner/cadence/batch/retention/test/metric evidence;
17. unresolved concerns và follow-up có owner rõ ràng.

Trước khi kết thúc, quét source, migration, test, OpenAPI, report và log artifact để chắc chắn không có credential/token/grant thật; chạy `git diff --check`; kiểm tra `git status`; chỉ commit đúng phạm vi EX V2 đã review.
