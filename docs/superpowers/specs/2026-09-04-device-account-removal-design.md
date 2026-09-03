# Device Account Removal Design

## Mục tiêu

Cho phép người dùng gỡ tài khoản giao dịch đang hoạt động khỏi ứng dụng trên
thiết bị hiện tại bằng dòng **Xóa tài khoản** trong trang chi tiết tài khoản.
Tài khoản đã gỡ biến mất khỏi danh sách trên thiết bị, nhưng tài khoản giao
dịch, số dư, lệnh và lịch sử trên máy chủ không bị xóa.

Nếu còn tài khoản khác, ứng dụng tự chuyển sang tài khoản đầu tiên còn lại
trước khi hoàn tất việc gỡ. Nếu không còn tài khoản nào, ứng dụng xóa phiên
thiết bị và trở về màn hình đăng nhập.

## Bối cảnh và giới hạn contract

- Production dùng một `deviceToken` chung cho thiết bị, không lưu token riêng
  cho từng tài khoản.
- `GET /mobile/accounts` là nguồn dữ liệu server-authoritative cho danh sách
  linked accounts; `PUT /mobile/accounts/{accountId}/activate` đổi tài khoản
  đang hoạt động.
- OpenAPI production tại thời điểm thiết kế chỉ có list, link và activate;
  không có endpoint unlink/delete một account khỏi device session.
- Backend EX V2 production được triển khai từ repository riêng, không nằm
  trong workspace này. Không sửa backend demo cục bộ để giả lập endpoint.

Vì vậy tính năng trong phạm vi này là **gỡ cục bộ khỏi ứng dụng trên thiết
bị**, không phải thu hồi liên kết ở server. Một tập account ID đã gỡ được lưu
trong Flutter Secure Storage và được dùng để lọc catalog server trước khi hiển
thị. Giới hạn này phải được giữ rõ trong code và tài liệu; không được mô tả
tính năng như một thao tác xóa hoặc revoke phía máy chủ.

## Trải nghiệm người dùng

### Điểm vào

- Không thêm thao tác vuốt hoặc nhấn giữ trong danh sách tài khoản.
- Người dùng chọn tài khoản để làm nó thành tài khoản hoạt động, mở chi tiết
  tài khoản, cuộn xuống và bấm **Xóa tài khoản**.
- Dòng account trình bày cố định có tên `Delete` ở cuối danh sách được loại bỏ;
  danh sách chỉ chứa tài khoản thật chưa bị gỡ trên thiết bị.

### Xác nhận

Khi bấm **Xóa tài khoản**, ứng dụng hiển thị dialog có:

- tiêu đề `Xóa tài khoản khỏi thiết bị?`;
- nội dung xác nhận tài khoản sẽ chỉ bị gỡ khỏi thiết bị này và dữ liệu trên
  máy chủ vẫn được giữ;
- nút `Hủy`;
- nút destructive `Xóa`.

Trong khi thao tác đang chạy, không cho gửi yêu cầu xóa lần thứ hai. Đóng
dialog bằng `Hủy`, Back hoặc chạm vùng ngoài không thay đổi trạng thái.

### Khi còn tài khoản khác

1. Chọn tài khoản đầu tiên còn lại theo thứ tự catalog hiện tại.
2. Kích hoạt tài khoản đó qua account activation coordinator hiện có.
3. Chỉ khi bootstrap mới được chấp nhận, ghi account ID cũ vào secure removed
   set và làm mới catalog.
4. Đóng trang chi tiết về danh sách tài khoản. Tài khoản mới đứng đầu và tài
   khoản vừa gỡ không còn xuất hiện.

Nếu activate thất bại, không ghi removed set, giữ tài khoản hiện tại, giữ
dialog/screen ở trạng thái có thể thử lại và hiển thị thông báo lỗi an toàn.

### Khi chỉ còn một tài khoản

1. Ghi account ID vào secure removed set.
2. Xóa `deviceToken` khỏi Flutter Secure Storage.
3. Vô hiệu hóa account-scoped state và báo cho `DeviceGate` đọc lại trạng
   thái phiên.
4. `DeviceGate` hiển thị màn hình đăng nhập tài khoản.

Nếu ghi removed set hoặc xóa token thất bại, không báo thành công. Nếu removed
set đã được ghi nhưng bước xóa token thất bại, rollback removed set để tài
khoản không biến mất trong khi phiên vẫn hoạt động.

### Đăng nhập lại

Sau khi login hoặc link và activate thành công một tài khoản đã bị gỡ, ứng
dụng xóa account ID đó khỏi secure removed set. Tài khoản xuất hiện lại như
một linked account bình thường. Password không được lưu.

## Kiến trúc

### Removed account store

Tạo một interface nhỏ trong feature `account_sessions` để đọc, thêm và xóa
account ID đã gỡ. Production implementation dùng `FlutterSecureStorage` và
một khóa có version, ví dụ `ex_v2_removed_account_ids_v1`.

Giá trị được serialize dưới dạng JSON array các stable public account ID:

- loại bỏ chuỗi rỗng và bản ghi trùng;
- đọc dữ liệu lỗi theo hướng an toàn: trả lỗi có kiểm soát, không tự xóa toàn
  bộ state khác trong secure storage;
- không lưu login password, device token, bootstrap hoặc dữ liệu tài chính;
- không log nội dung storage.

Store có thể được thay bằng in-memory fake trong unit/widget tests.

### Catalog filtering

`LinkedTradingAccountsController.build()` đọc removed set rồi mới công bố
catalog. Mọi account có stable account ID trong set bị loại khỏi danh sách
server-returned.

Active bootstrap vẫn là nguồn authority cho account hiện tại. Luồng gỡ tài
khoản có account thay thế phải activate account thay thế trước khi refresh
catalog, nên active account hợp lệ không bị lọc mất. Nếu app bị đóng giữa quá
trình, active bootstrap vẫn được phép hiển thị để người dùng không bị kẹt;
removed set chỉ loại các hàng inactive từ catalog.

Controller cung cấp mutation nhỏ để ghi removed ID và cập nhật state sau khi
thao tác hoàn thành, thay vì để widget chỉnh danh sách trực tiếp.

### Removal coordinator

Tạo controller/coordinator thuộc `account_sessions` làm chủ toàn bộ workflow:

- xác định target từ active bootstrap, không nhận account ID tùy ý từ UI;
- lấy danh sách tài khoản chưa bị gỡ;
- chọn account thay thế đầu tiên khác target;
- chống double-submit;
- tái sử dụng `AccountActivationCoordinator` để giữ atomic publication và
  account switch guard hiện có;
- ghi/rollback removed set;
- xóa global token và phát session-revision signal khi xóa tài khoản cuối;
- invalidate linked catalog và account-scoped providers đúng thời điểm;
- trả kết quả typed để UI phân biệt `switched`, `signedOut` và `failed`.

Widget chỉ mở dialog, gọi coordinator và điều hướng theo kết quả. Widget không
đọc/ghi Secure Storage hoặc tự gọi API.

### Device gate refresh

Thêm một session revision/notifier nhỏ được tăng sau khi global device token
bị xóa. `DeviceGate` lắng nghe revision và chạy lại luồng đọc token hiện có.
Cách này đưa app về trạng thái login trong cùng process mà không cần restart
ứng dụng hoặc điều hướng xuyên qua gate.

### Login/link reconciliation

Sau publication thành công của account/password login và add-account
activation, account ID được bỏ khỏi removed set. Nếu bước này thất bại, UI
không tuyên bố toàn bộ workflow đã hoàn tất; state phải có thể retry mà không
ghi hoặc log credentials.

## Luồng dữ liệu

```text
AccountDetailScreen
  -> confirm dialog
  -> AccountRemovalController.removeActiveAccount()
      -> read visible linked accounts
      -> replacement exists?
          yes -> AccountActivationCoordinator.activate(replacement)
                 -> RemovedAccountStore.add(oldAccountId)
                 -> refresh linked catalog
                 -> result: switched
          no  -> RemovedAccountStore.add(oldAccountId)
                 -> DeviceTokenStore.delete()
                 -> invalidate account state + bump session revision
                 -> result: signedOut
  -> switched: pop to account list
  -> signedOut: DeviceGate shows login
  -> failure: stay on detail and show safe error
```

## Xử lý lỗi và tính nhất quán

- Network, timeout, `409` hoặc `5xx` khi activate: giữ nguyên account và
  removed set.
- `401`/`403`: giữ cơ chế invalidation phiên hiện có; không giả vờ xóa thành
  công.
- `404 account_not_found` khi chọn replacement: refresh catalog và báo lỗi an
  toàn; người dùng có thể thử lại sau khi danh sách mới được tải.
- Identity mismatch hoặc stale bootstrap: không gỡ target.
- Secure Storage write/delete lỗi: rollback phần local có thể rollback và
  hiển thị lỗi chung không chứa secret.
- Hai lần bấm Xóa đồng thời: chỉ request đầu tiên được xử lý.
- Không log password, token, removed set hoặc response chứa dữ liệu nhạy cảm.

## Demo mode

Production feature chỉ thay đổi catalog EX V2. Demo/offline catalog cố định
không bị ghi vào removed store. Widget tests có thể override coordinator để
kiểm tra dialog và điều hướng mà không gọi mạng.

## Kiểm thử

### Store tests

- round-trip nhiều account ID;
- thêm trùng không tạo duplicate;
- bỏ một ID giữ nguyên các ID khác;
- JSON lỗi trả failure có kiểm soát;
- storage không chứa password, token hoặc bootstrap.

### Controller/provider tests

- catalog loại các account ID đã gỡ và vẫn giữ thứ tự server;
- xóa active có account thay thế kích hoạt đúng account đầu tiên rồi mới gỡ
  account cũ;
- activate thất bại không thay đổi removed set;
- double-submit không tạo hai activation;
- xóa account cuối xóa token, invalidate account state và phát revision;
- token-delete thất bại rollback removed set;
- login/link thành công bỏ hidden marker của đúng account.

### Widget tests

- bấm dòng Xóa mở đúng dialog;
- Hủy và Back không gọi controller;
- nút Xóa gọi đúng một lần và chặn double tap;
- kết quả switched đóng detail về account list;
- failure giữ màn hình và hiện safe SnackBar;
- danh sách không còn dòng `Delete` cố định.

### Verification

- `flutter analyze`;
- focused Flutter tests cho account detail, account list, session removal,
  account activation và login/link;
- toàn bộ `flutter test`;
- `flutter build apk --debug`;
- `dotnet build backend/Trading.sln`;
- `dotnet test backend/Trading.sln --no-build`;
- chạy trên emulator, chụp ảnh dialog và danh sách sau khi gỡ;
- smoke test A/B: đang ở A, xóa A, tự chuyển sang B, cold restart không thấy A,
  đăng nhập lại A thì A xuất hiện lại.

## Ngoài phạm vi

- Không xóa TradingAccount hoặc dữ liệu giao dịch trên server.
- Không thêm endpoint production trong backend demo cục bộ.
- Không revoke một account riêng ở server vì contract hiện không hỗ trợ.
- Không thêm swipe-to-delete hoặc long-press menu.
- Không đổi technology stack, base URL hoặc cơ chế account activation.

## Tiêu chí hoàn thành

1. Xóa chỉ được bắt đầu từ dòng **Xóa tài khoản** trong account detail và luôn
   có dialog xác nhận.
2. Với nhiều account, app chuyển sang account đầu tiên còn lại và target biến
   mất khỏi list sau khi activation thành công.
3. Với một account, token cục bộ bị xóa và app trở về login trong cùng process.
4. Target vẫn ẩn sau cold restart và xuất hiện lại sau khi login/link thành
   công.
5. Không có API hoặc database mutation xóa tài khoản, số dư, order, position,
   deal hay history phía server.
6. Không có secret trong log hoặc storage mới.
7. Analyze, tests, builds và emulator visual verification hoàn tất.
