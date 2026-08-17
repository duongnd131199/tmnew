# New Account Video Parity Design

## Mục tiêu

Làm cho toàn bộ luồng thêm tài khoản trên Flutter bám sát giao diện và hành vi trong `giaoDienMau/themmoitk.MP4`, đồng thời tiếp tục hiển thị dữ liệu thật do EX V2 API cung cấp. Không thêm broker, server, tài khoản, số dư hoặc trạng thái giả chỉ để giống nội dung cụ thể trong video.

## Phạm vi

Luồng được nghiệm thu theo thứ tự:

1. Từ màn hình Cài đặt mở danh sách Tài khoản.
2. Nhấn nút dấu cộng để mở danh sách Brokers.
3. Chọn một broker thật từ API.
4. Hiển thị form dùng tài khoản hiện có.
5. Mở danh sách Máy chủ và chọn server thật từ API.
6. Quay lại form mà không làm mất login hoặc password vừa nhập.
7. Gửi thông tin đăng nhập bằng contract hiện tại.
8. Chờ link, activate và bootstrap hoàn tất trước khi chuyển sang Trade.

Không thay đổi backend, base URL, model request, auth header, device-token contract hoặc quy tắc bảo mật credential.

## Kết quả điều tra

Video dài 77,23 giây, kích thước 576 x 1280. Các frame chính cho thấy:

- Danh sách Tài khoản dùng toolbar ba vùng: Back, tiêu đề giữa và nút cộng.
- Danh sách Brokers dùng toolbar ba vùng: Back, `Brokers` và QR.
- Danh sách Máy chủ dùng Back bên trái, `Máy chủ` ở giữa và danh sách server nền surface.
- Form broker có header Back + broker mark + broker name, tiếp theo là hai nhóm đăng ký và sử dụng tài khoản hiện có.
- Search bar broker neo gần đáy nhưng di chuyển an toàn khi bàn phím mở.
- Nút Đăng nhập nằm gần đáy, vô hiệu hóa cho đến khi form hợp lệ.

Luồng thật trên LDPlayer tái hiện lỗi nhất quán: `_BrokerToolbar` và toolbar Máy chủ chỉ khai báo chiều cao. Khi chúng nằm trong `Column`, `Stack` lấy chiều rộng nội tại từ tiêu đề thay vì chiều rộng màn hình. Vì vậy Back và QR bị dồn vào giữa, che tiêu đề. Test hiện có chỉ kiểm tra widget tồn tại, chưa kiểm tra hình học nên không phát hiện lỗi.

## Phương án được chọn

Dùng một toolbar account-link full-width dùng chung và hiệu chỉnh toàn bộ frame của luồng dựa trên video. Đây là phương án cân bằng giữa độ chính xác hình ảnh, responsive và khả năng bảo trì.

Không chọn sửa riêng hai nút vì các sai lệch spacing sẽ tiếp tục không được kiểm soát. Không hard-code theo 576 x 1280 vì ứng dụng phải hoạt động ở 360–430 logical pixels và trên LDPlayer hiện tại.

## Kiến trúc giao diện

### Toolbar dùng chung

Tạo một widget account-link toolbar chịu trách nhiệm duy nhất cho:

- chiều rộng `double.infinity`;
- chiều cao theo design token/metric của luồng;
- vùng trái có hit target tròn 43 logical pixels;
- tiêu đề căn giữa độc lập với chiều rộng vùng trái/phải;
- vùng phải tùy chọn cho QR;
- SafeArea do screen cha quản lý.

`BrokerListScreen` và `TradingServerScreen` dùng cùng widget này. Form broker tiếp tục dùng header riêng vì có broker mark và tên động, nhưng dùng chung metric nút Back.

### Danh sách broker

- Dữ liệu lấy từ `AccountLinkRepository.brokers()`.
- Mỗi hàng hiển thị mark được suy ra từ broker thật, tên, company name nếu có và nút info.
- Không thêm Exness hoặc MetaQuotes nếu API không trả về.
- Search tại chỗ phản hồi ngay; request server vẫn debounce và chống stale response như hiện tại.
- Search field giữ ở đáy khi không có bàn phím, đồng thời không bị bàn phím che.

### Form tài khoản hiện có

- Header hiển thị broker thật đã chọn.
- Server đầu tiên từ API có thể tiếp tục được chọn mặc định theo hành vi hiện tại.
- Login dùng bàn phím số; password giữ nguyên từng ký tự và obscure trên giao diện.
- Chuyển sang danh sách server rồi quay lại phải giữ nguyên login/password trong controller.
- Save password, forgot password, loading, disabled và error state giữ contract hiện tại.
- Không log password, token, authorization, reconnect grant hoặc request body.

### Danh sách máy chủ

- Dữ liệu lấy từ `AccountLinkRepository.servers(brokerId)`.
- Toolbar full-width và tiêu đề không bị Back che.
- Hàng server có chiều cao ổn định, divider và check mark cho server đang chọn.
- Chọn server pop đúng một route và trả selection về form.

### Hoàn tất đăng nhập

Request và activation không thay đổi. UI chỉ chuyển sang `/trade` sau khi link, activation và bootstrap publication hoàn tất. Lỗi vẫn ở form, giữ login/server/save-password và xóa password khi error policy hiện tại yêu cầu.

## Responsive và hình học

- Hỗ trợ chiều rộng 360, 390, 412 và 430 logical pixels.
- Back phải nằm trong vùng trái, QR trong vùng phải; hai vùng không được giao với vùng tiêu đề.
- Tiêu đề phải có tâm ngang trùng tâm màn hình với sai số tối đa 1 logical pixel.
- Không overflow khi text scale mặc định và broker name dài; tên broker dùng ellipsis.
- Keyboard không che trường đang focus hoặc nút hành động cần thiết.
- Không dùng tọa độ physical pixel của video làm giá trị layout trực tiếp.

## Trạng thái dữ liệu

- Loading: spinner ở vùng nội dung, toolbar vẫn ổn định.
- Empty: thông báo không tìm thấy broker/server, không chèn fixture.
- Error: thông báo an toàn và nút Thử lại gọi API thật.
- Success: dữ liệu hiển thị đúng ID/name do API cung cấp.
- Stale response: không được thay kết quả query hoặc broker selection mới hơn.

## Kiểm thử

### Widget tests

- Toolbar Brokers chiếm toàn bộ chiều rộng và ba vùng không chồng nhau.
- Toolbar Máy chủ chiếm toàn bộ chiều rộng và Back không che tiêu đề.
- Kiểm tra hình học trên 360, 390 và 430 logical pixels.
- Broker/server render đúng dữ liệu repository động; không dựa vào tên Exness cụ thể để chứng minh layout.
- Chọn broker, nhập login/password, đổi server và quay lại vẫn giữ field.
- Search, loading, empty, error/retry và keyboard inset không bị hồi quy.
- Login chỉ điều hướng sau activation/bootstrap.

### Manual video comparison

Chụp LDPlayer tại các mốc tương ứng: danh sách Tài khoản, Brokers, form, Máy chủ, form có dữ liệu và màn hình sau đăng nhập. So sánh vị trí toolbar, row pitch, section header, search field, keyboard behavior và bottom action với các frame đã trích từ video.

Không gửi credential hoặc thực hiện link account thật trong quá trình kiểm tra hình ảnh nếu không có thông tin đăng nhập do người dùng nhập trực tiếp trên thiết bị.

## Tiêu chí hoàn thành

- Không còn toolbar bị co vào giữa hoặc chồng nút lên tiêu đề.
- Toàn bộ luồng có bố cục, thứ tự, trạng thái và chuyển trang bám video.
- Tất cả nội dung nghiệp vụ đến từ API thật.
- Test mới được chứng minh RED trước khi sửa và GREEN sau khi sửa.
- `flutter analyze`, `flutter test`, `flutter build apk --debug`, backend build và test liên quan đều thành công theo hướng dẫn repository.
- APK cuối được cài lên LDPlayer và có ảnh đối chiếu.
