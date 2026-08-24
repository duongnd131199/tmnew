# Secure Multi-Account Sessions Design

## Mục tiêu

Khôi phục danh sách các tài khoản đã đăng nhập trong màn hình **Cài đặt → Tài khoản**, hiển thị đúng thông tin và logo broker, đồng thời cho phép chuyển giữa các tài khoản đã lưu mà không phải nhập lại mật khẩu.

Người dùng chấp nhận đăng nhập lại từng tài khoản cũ đúng một lần sau khi cài bản mới. Từ lần đăng nhập đó trở đi, app lưu phiên riêng của tài khoản trong vùng lưu trữ bảo mật và có thể chuyển tài khoản trực tiếp.

## Hiện trạng và nguyên nhân gốc

- App hiện chỉ lưu một `deviceToken` toàn cục. Mỗi lần đăng nhập mới ghi đè token của tài khoản trước.
- Endpoint production `GET /mobile/accounts` hiện trả danh sách rỗng cho thiết bị đã kiểm tra, nên app không thể dựng lại các tài khoản trước đây từ server.
- Token đã bị ghi đè không thể khôi phục an toàn từ dữ liệu hiện có. App không được tạo tài khoản giả hoặc lưu mật khẩu để bù cho giới hạn này.
- Phần trình bày logo MetaQuotes và cache metadata đã có, nhưng không thể tự tạo ra danh sách tài khoản thật khi nguồn API rỗng.

## Phương án được chọn

Sử dụng mô hình kết hợp:

1. Lưu một phiên mã hóa riêng cho từng tài khoản đã đăng nhập thành công trên thiết bị.
2. Hợp nhất các phiên cục bộ với danh sách linked accounts từ server khi endpoint trả dữ liệu.
3. Dùng phiên cục bộ để chuyển nhanh tài khoản; tiếp tục hỗ trợ luồng activation hiện có cho tài khoản chỉ có ở phía server.

Phương án này hoạt động với backend production hiện tại và vẫn tương thích nếu `/mobile/accounts` được sửa để trở thành nguồn dữ liệu đầy đủ trong tương lai.

## Mô hình dữ liệu

Tạo một kho phiên tài khoản trong `flutter_secure_storage`. Mỗi bản ghi chứa tối thiểu:

- stable account ID;
- login và thông tin hiển thị cần cho danh sách tài khoản;
- broker ID/name, server và currency/mode nếu API cung cấp;
- opaque device token của chính tài khoản đó;
- trạng thái phiên hợp lệ hoặc cần đăng nhập lại;
- thời điểm cập nhật để giải quyết bản ghi trùng lặp một cách xác định.

Kho phiên không lưu password, Authorization header, reconnect grant không cần thiết, bootstrap tài chính đầy đủ hoặc dữ liệu giao dịch nhạy cảm. Dữ liệu metadata dùng cho UI và token phải nằm trong Secure Storage; không ghi token ra log.

Một account ID chỉ có một bản ghi. Đăng nhập lại cùng tài khoản cập nhật token và metadata trên đúng bản ghi thay vì tạo dòng trùng.

## Thành phần và trách nhiệm

### Secure account session store

Chịu trách nhiệm đọc, ghi, upsert, đánh dấu hết hạn và xóa phiên. Store cung cấp interface nhỏ để controller không phụ thuộc định dạng JSON hay khóa Secure Storage.

### Account session registry/controller

Hợp nhất ba nguồn theo stable account ID:

1. tài khoản active từ bootstrap;
2. các phiên bảo mật đã lưu trên máy;
3. linked accounts từ `/mobile/accounts` khi có dữ liệu.

Thứ tự hiển thị là tài khoản active trước, các tài khoản còn lại theo thứ tự ổn định. Metadata mới và cụ thể hơn được ưu tiên; dữ liệu server rỗng không được xóa các phiên cục bộ hợp lệ.

### Login integration

Sau khi account/password login trả kết quả hợp lệ:

1. xác thực identity giữa account và bootstrap như luồng hiện tại;
2. upsert phiên chứa token mới và metadata;
3. đặt token mới làm active token;
4. publish bootstrap bằng cơ chế `authoritativeAccountSwitch` hiện có.

Nếu bước lưu phiên thất bại, app không công bố trạng thái nửa vời. Người dùng nhận lỗi phù hợp và phiên active trước đó vẫn được giữ nguyên.

### Account switch coordinator

Khi người dùng chọn một tài khoản có phiên cục bộ:

1. chặn thao tác chuyển trùng hoặc đồng thời;
2. giữ snapshot của active token và account state hiện tại;
3. dùng token đích để gọi bootstrap mà chưa công bố token đó ra toàn app;
4. kiểm tra account ID của response, bootstrap và tài khoản được chọn phải trùng nhau;
5. sau khi tất cả kiểm tra thành công, thay active token và publish toàn bộ bootstrap một cách nguyên tử;
6. nếu bất kỳ bước nào lỗi, khôi phục token/state cũ và không làm thay đổi tài khoản đang hoạt động.

Khi tài khoản chỉ tồn tại ở linked-account server list và chưa có phiên cục bộ, app giữ luồng activation hiện có. Sau khi server trả token hoặc phiên có thể sử dụng, phiên đó được upsert vào registry nếu contract hỗ trợ. Không giả định endpoint trả token khi contract không có trường này.

## Trạng thái UI và logo

- Tab Tài khoản hiển thị hợp nhất các tài khoản thật đã biết; không seed hoặc hard-code tài khoản mẫu.
- Tài khoản active đứng đầu và giữ bố cục/theme trắng đã được triển khai.
- Logo được chọn từ broker/server metadata thông qua resolver dùng chung. MetaQuotes và Exness không dùng icon placeholder khi metadata nhận dạng được broker.
- Khi metadata logo thiếu, UI dùng fallback trung tính hiện có, không hiển thị ảnh lỗi.
- Phiên hết hạn vẫn giữ dòng tài khoản và metadata/logo; khi người dùng chọn, app mở luồng đăng nhập lại với login/server đã biết nhưng không tự điền password.
- Đăng nhập lại thành công cập nhật đúng phiên rồi chuyển vào tài khoản đó.

## Xử lý lỗi và an toàn dữ liệu

- Token không hợp lệ hoặc hết hạn: đánh dấu phiên cần đăng nhập lại, giữ metadata của dòng tài khoản và giữ nguyên active account hiện tại.
- Network timeout hoặc lỗi server: không đánh dấu token hết hạn nếu không có tín hiệu xác thực rõ ràng; hiển thị lỗi thử lại và rollback.
- Identity mismatch: từ chối bootstrap, không đổi token, không publish state và ghi log chẩn đoán đã loại bỏ dữ liệu bí mật.
- Secure Storage hỏng hoặc decode lỗi: cô lập bản ghi lỗi khi có thể; không xóa hàng loạt phiên hợp lệ.
- Hai thao tác switch đồng thời: operation authority hiện có quyết định thao tác mới nhất; response cũ không được ghi đè active account mới.
- `/mobile/accounts` trả rỗng: giữ nguyên registry cục bộ.
- Không log password, device token, Authorization header, reconnect grant hoặc toàn bộ response chứa dữ liệu nhạy cảm.

## Di chuyển dữ liệu

- Lần chạy đầu sau nâng cấp, nếu app có active bootstrap và active device token hợp lệ, tạo một phiên cho tài khoản active hiện tại.
- Các tài khoản cũ đã bị ghi đè token không thể tự phục hồi. Người dùng đăng nhập lại từng tài khoản đúng một lần để thêm vào registry.
- Cache danh sách metadata hiện có có thể được dùng để làm giàu tên/logo, nhưng không được xem là một phiên có thể chuyển nếu không có token hợp lệ.
- Migration phải idempotent: khởi động lại nhiều lần không tạo bản ghi trùng hoặc thay đổi token mới bằng dữ liệu cũ.

## Kiểm thử

### Unit và provider tests

- Upsert hai tài khoản tạo hai phiên độc lập; đăng nhập lại một tài khoản chỉ cập nhật đúng phiên đó.
- Store serialize/deserialize metadata và token nhưng không chứa password.
- Migration tạo phiên cho active account đúng một lần.
- Merge active/local/server loại bỏ trùng theo account ID, đặt active lên đầu và không xóa local sessions khi server trả rỗng.
- Broker resolver và widgets hiển thị đúng logo MetaQuotes/Exness, với fallback không bị lỗi ảnh.
- Token đích hợp lệ chuyển toàn bộ bootstrap/account-scoped state sang đúng tài khoản.
- Token hết hạn mở trạng thái đăng nhập lại và giữ active account cũ.
- Network failure và identity mismatch rollback token, presentation và toàn bộ account state.
- Response switch cũ không ghi đè thao tác switch mới hơn.
- Không có log chẩn đoán tạm hoặc secret trong đường dẫn thực thi.

### Verification

- Chạy focused tests cho login, session store, account list, logo và switching.
- Chạy toàn bộ `flutter test` và ghi rõ mọi failure đã tồn tại ngoài phạm vi nếu có.
- Chạy `flutter analyze`.
- Build APK release/debug theo quy trình hiện tại.
- Cài APK lên `emulator-5560` mà không xóa application data.
- Smoke test: đăng nhập hai tài khoản, đóng/mở app, kiểm tra đủ hai dòng và logo, chuyển qua lại không nhập mật khẩu; mô phỏng token lỗi để kiểm tra luồng đăng nhập lại.

## Phạm vi không thay đổi

- Không thay đổi technology stack, base URL hoặc contract backend production.
- Không sửa chức năng đặt lệnh, dữ liệu thị trường, wallet, positions, orders hay history ngoài việc thay toàn bộ state đúng khi chuyển account.
- Không lưu password và không tạo dữ liệu tài khoản giả.
- Không sửa bố cục màn hình Tài khoản ngoài phần cần thiết để hiển thị trạng thái đăng nhập lại; theme trắng và hình học hiện tại được giữ nguyên.
- Không sửa local backend để giả làm dịch vụ EX V2 production.

## Tiêu chí hoàn thành

1. Sau khi đăng nhập lại hai hoặc nhiều tài khoản mỗi tài khoản một lần, tất cả vẫn xuất hiện sau cold restart.
2. Logo và metadata của từng tài khoản hiển thị đúng khi có dữ liệu nhận dạng broker.
3. Chuyển giữa các phiên hợp lệ không yêu cầu mật khẩu và toàn bộ dữ liệu account-scoped thuộc đúng tài khoản mới.
4. Phiên lỗi không làm mất hoặc thay đổi active account; người dùng có thể đăng nhập lại đúng tài khoản.
5. Password và token không xuất hiện trong log hoặc storage không mã hóa.
6. Analyze, relevant tests và APK build hoàn tất; APK mới được cài lên emulator để người dùng kiểm tra.
