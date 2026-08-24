# Thiết kế sửa luồng liên kết và chuyển tài khoản

## Mục tiêu

Sửa lỗi người dùng nhập đúng mật khẩu nhưng không thể đăng nhập hoặc chuyển sang tài khoản đã lưu. Sau khi một tài khoản được liên kết lại thành công đúng một lần trên thiết bị hiện tại, người dùng phải có thể chuyển qua lại giữa các tài khoản đã liên kết mà không nhập lại mật khẩu.

Thiết kế này sửa phần xác thực và chuyển tài khoản trong `2026-08-24-secure-multi-account-sessions-design.md`. Các yêu cầu về danh sách tài khoản, metadata, logo, Secure Storage và publication nguyên tử vẫn được giữ nguyên, nhưng local per-account token không còn được xem là bằng chứng tài khoản đã liên kết với device token hiện tại.

## Bằng chứng và nguyên nhân gốc

Smoke test trên production đã gọi được `PUT /mobile/accounts/{accountId}/activate`, nhưng server trả `404 account_not_found` cho tài khoản cũ vẫn còn trong registry cục bộ. Theo contract EX V2, lỗi này có nghĩa link không tồn tại trên device hiện tại hoặc thuộc device khác; server cố ý dùng cùng mã lỗi để không làm lộ sự tồn tại của tài khoản.

Luồng form “Dùng tài khoản hiện có” hiện gọi `POST /mobile/auth/login`. Endpoint này tạo hoặc khôi phục ngữ cảnh đăng nhập thiết bị, nhưng không thực hiện nghiệp vụ liên kết trading account vào device hiện tại. Vì vậy app có thể lưu một local session nhưng `activate` vẫn không tìm thấy linked account trên server.

Nguyên nhân gốc là app đang dùng endpoint đăng nhập thiết bị cho nghiệp vụ liên kết tài khoản. Đây là sai ranh giới contract, không phải lỗi nút bấm hay validate mật khẩu.

## Các phương án đã xem xét

### 1. Dùng `link` rồi `activate` theo contract hiện có — chọn

Form tài khoản hiện có gọi `POST /mobile/accounts/link`, lưu reconnect grant theo lựa chọn của người dùng, rồi gọi `PUT /mobile/accounts/{accountId}/activate`. Các lần chuyển tiếp theo chỉ gọi `activate` bằng device token hiện tại.

Ưu điểm: khớp contract production, không cần đổi backend, giữ được yêu cầu chuyển không hỏi mật khẩu và tái sử dụng coordinator publication hiện có.

### 2. Tiếp tục lưu một device token riêng cho từng tài khoản — loại

Phương án này dựa trên giả định mỗi lần account/password login tạo một token có thể đại diện độc lập cho linked account. Production đã chứng minh giả định đó không đủ: local session tồn tại nhưng account vẫn không được liên kết với device context dùng cho `activate`.

### 3. Thêm endpoint backend tiêu thụ reconnect grant — chưa chọn

Đây có thể là hướng mở rộng sau này, nhưng client và public contract hiện chưa có endpoint consumer. Thêm endpoint mới làm tăng phạm vi backend và không cần thiết để sửa lỗi hiện tại.

## Ranh giới xác thực

Ba thao tác phải có trách nhiệm tách biệt:

1. `POST /mobile/auth/login` chỉ phục vụ cổng đăng nhập ban đầu của app, tạo device context và bootstrap ban đầu.
2. `POST /mobile/accounts/link` xác thực broker/server/login/password và liên kết trading account với device context hiện tại.
3. `PUT /mobile/accounts/{accountId}/activate` chuyển active account trong số các account đã liên kết và trả bootstrap đầy đủ.

Không dùng broker/server metadata, token trùng nhau hoặc registry cục bộ để suy đoán rằng account đã được liên kết. Server activation là ranh giới thẩm quyền.

## Luồng thêm hoặc liên kết lại tài khoản

`AccountLinkController.submit()` thực hiện tuần tự trong cùng một operation guard:

1. Validate broker, server, login dạng số và password khác rỗng.
2. Gọi `AccountLinkRepository.link()` với đúng `brokerId`, `serverId`, `login`, password nguyên trạng và `savePassword`.
3. Kiểm tra account server trả về khớp broker, server và login người dùng đã chọn. Nếu sai, dừng và không activate.
4. Nếu `savePassword` bật, lưu reconnect grant vào Secure Storage theo stable account ID. Nếu tắt, xóa grant cũ của account và không persist grant mới.
5. Lưu presentation metadata cho logo/tên server.
6. Gọi `AccountActivationCoordinator.activate()` cho stable account ID vừa link.
7. Chỉ khi activation được authority hiện tại chấp nhận mới báo thành công, đóng form và refresh danh sách account.
8. Luôn xóa password khỏi state sau response xác thực; tuyệt đối không log password, device token hoặc reconnect grant.

Nếu link thành công nhưng activation lỗi mạng/server, linked account vẫn hợp lệ trên server. Controller giữ stable account ID vừa link và cho nút đăng nhập thử lại riêng bước activation, không yêu cầu nhập lại password và không gọi lại `link`. Việc sửa broker, server hoặc login sẽ xóa trạng thái retry này. Active account cũ và bootstrap đang hiển thị không bị thay đổi.

## Luồng chuyển tài khoản

`LinkedTradingAccountsController.activate(accountId)`:

1. Chặn target đang active và thao tác đồng thời như hiện tại.
2. Xác nhận target có trong catalog đã hợp nhất.
3. Gọi `AccountActivationCoordinator.activate()` bằng device token hiện tại cho mọi target khác active, không phân nhánh theo metadata generic hoặc per-account token.
4. Coordinator tiếp tục kiểm tra ba identity: requested account, response account và bootstrap account phải trùng nhau.
5. Chỉ publish bootstrap khi lease/authority còn hợp lệ; response cũ không được ghi đè thao tác mới.
6. Sau thành công, làm mới registry/catalog và giữ nguyên contract trả về cho màn hình Profile.

Local account-session registry chỉ còn là cache giúp hiển thị và prefill. Nó không được tự chuyển device token trước khi server xác nhận account thuộc device context hiện tại.

## Phục hồi khi account chưa liên kết

Thêm một lỗi domain riêng, ví dụ `AccountRelinkRequired`, chứa account metadata an toàn dùng để điều hướng.

Khi activation trả `404` với code chuẩn hóa `account_not_found`:

- giữ nguyên active account và bootstrap;
- không hiển thị snackbar lỗi chung;
- mở form “Dùng tài khoản hiện có” với login, broker và server được prefill khi metadata có thể định tuyến;
- không prefill password;
- submit form theo luồng `link → activate` ở trên.

Chỉ đúng cặp `404 + account_not_found` được chuyển thành relink. Mọi mã 404 khác vẫn là lỗi server thông thường.

Đối với dữ liệu migration rất cũ, chỉ cặp sentinel chính xác `unknown-broker` và `unknown-server` mới được map sang broker/server tham chiếu được cấu hình. Các chuỗi rỗng hoặc nhãn chung khác không được tự suy đoán thành một route hợp lệ.

## Xử lý lỗi

- `link` trả `401` hoặc `invalid_credentials`: giữ form, xóa password và hiển thị thông báo credential an toàn.
- `activate` trả `404 account_not_found`: điều hướng sang relink form như mô tả trên.
- `401/403` tại ranh giới device session: không đánh dấu riêng target account là sai mật khẩu; giữ active state và chuyển về cơ chế đăng nhập thiết bị hiện có.
- `409`, timeout hoặc `5xx`: giữ active account, hiển thị lỗi thử lại và không đổi registry/session.
- Identity mismatch từ link hoặc activation: từ chối publication, không đổi active account và hiển thị lỗi an toàn.
- Secure Storage ghi grant lỗi: không báo hoàn tất. Không persist password để bù cho lỗi grant.
- Operation cũ/stale: không đóng form và không publish bootstrap nếu authority đã bị thay thế.

## Thay đổi thành phần

- `AccountLinkController`: thay account-password login bằng repository `link`, quản lý reconnect grant, presentation và gọi activation coordinator.
- `LinkedTradingAccountsController`: ưu tiên server activation cho mọi account không active; map chính xác `account_not_found` thành relink-required.
- `ProfileScreen`: bắt lỗi relink-required và mở route add-account có prefill; xử lý device-session-expired tách biệt.
- Account session registry/store: tiếp tục cung cấp catalog/cache và migration tương thích, nhưng không quyết định quyền activate dựa trên token hoặc metadata legacy.
- Không thay đổi `AccountLinkRepository`, endpoint backend, route UI hoặc technology stack.

## Tương thích dữ liệu cũ

- Không xóa danh sách account hoặc metadata cũ khỏi Secure Storage.
- Account cũ còn trong registry nhưng chưa link với device hiện tại sẽ được phát hiện bằng `account_not_found` và yêu cầu nhập password đúng một lần.
- Sau `link → activate` thành công, catalog/cache được upsert bằng stable ID và metadata chuẩn từ server; không tạo dòng trùng.
- Các per-account token cũ không được dùng để ghi đè device token hiện tại trong luồng switch. Việc dọn dữ liệu token cũ nằm ngoài phạm vi sửa lỗi này để tránh migration phá hủy dữ liệu.

## Kiểm thử TDD

### Controller và repository interaction

- Form hợp lệ gọi `link`, không gọi `/mobile/auth/login`, sau đó gọi `activate` với account ID server trả về.
- Link request giữ nguyên password và gửi đúng `savePassword`; password không xuất hiện trong persisted model hoặc log.
- `savePassword: true` ghi reconnect grant; `false` xóa grant cũ và không persist grant mới.
- Link identity mismatch không activate và không publish.
- Link sai credential xóa password, giữ form và hiển thị lỗi.
- Link thành công nhưng activation lỗi giữ active account cũ; retry chỉ gọi lại activation và không yêu cầu password.

### Chuyển và phục hồi

- Account khác active luôn thử server activation, kể cả local token trùng active token hoặc metadata không generic.
- Activation thành công publish đúng bootstrap và không yêu cầu password.
- `404 account_not_found` tạo relink-required và route được prefill đúng login/server, password rỗng.
- `401/403`, `409`, `500`, timeout và identity mismatch đều giữ nguyên active account.
- Hai switch đồng thời tuân thủ guard/authority; response cũ không thắng response mới.
- Không còn heuristic generic broker/server quyết định việc thử activation.

### Hồi quy và xác minh

- Chạy focused Flutter tests cho account link, activation, registry, session switch, profile routing và multi-account switching.
- Chạy toàn bộ `flutter test`, `flutter analyze` và build APK theo cấu hình hiện tại.
- Chạy backend build/analyze tương đương và relevant tests theo hướng dẫn repository dù backend không đổi.
- Cài APK lên `emulator-5560` mà không xóa app data.
- Smoke test production: chọn account cũ → nhận relink form → nhập password một lần → link và activate thành công → chuyển qua lại hai account không hỏi password → cold restart vẫn giữ danh sách và chuyển được.

## Tiêu chí hoàn thành

1. Form “Dùng tài khoản hiện có” dùng `link → activate`, không dùng `/mobile/auth/login`.
2. Account chưa thuộc device context được yêu cầu liên kết lại đúng một lần bằng thông báo/route phù hợp.
3. Sau khi link thành công, chuyển qua lại các account đã liên kết không yêu cầu password.
4. Mọi lỗi giữa chừng giữ nguyên active account và bootstrap; không có publication nửa vời.
5. Không lưu hoặc log password; reconnect grant chỉ được persist khi người dùng bật lưu.
6. Focused tests, full tests, analyze, build và production emulator smoke đều đạt trước khi tuyên bố hoàn tất.

## Ngoài phạm vi

- Không thêm endpoint backend mới hoặc grant-consumer API.
- Không thay đổi UI ngoài thông báo/trạng thái cần thiết cho relink và lỗi xác thực.
- Không dọn hàng loạt dữ liệu Secure Storage cũ.
- Không thay đổi market data, chart, trade, wallet, history hoặc notification behavior.
