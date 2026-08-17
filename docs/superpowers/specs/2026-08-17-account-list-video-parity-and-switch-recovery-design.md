# Account List Video Parity and Switch Recovery Design

## Mục tiêu

Khớp màn hình tài khoản và phần đầu tab Cài đặt với các mốc 0, 4, 8, 72 và 76 giây của `giaoDienMau/themmoitk.MP4`, đồng thời bảo đảm mỗi lần chuyển tài khoản thành công chỉ công bố dữ liệu canonical của đúng tài khoản được chọn.

## Bằng chứng hiện trạng

- Video dài 77,23 giây, kích thước 576 x 1280, gần 30 fps.
- Tài khoản active đứng đầu, dùng nền xám đậm, tên màu xanh, broker mark màu vàng, ba dòng nội dung và chevron.
- Tài khoản inactive đứng dưới, nền đen, tên trắng, metadata xám và không có chevron.
- Tab Cài đặt hiển thị tên, công ty, `login - server` và access point; không có chữ `Unavailable`.
- Flutter sau cold start chỉ có bootstrap lõi. `ExV2AccountProfileMapper` không nhận lại broker/server metadata nên tự điền `Unavailable`, dù `GET /mobile/accounts` đã có broker/server của cùng account.
- Trên public ingress, một thao tác activate đúng account ID hiện trả HTTP 409, code `concurrency_conflict`. Cold restart sau lỗi vẫn trả tài khoản cũ, chứng minh server chưa đổi active account.

## Thiết kế được chọn

### Ghép metadata theo account ID

`demoAccountsProvider` phải tìm `LinkedTradingAccount` có `id` bằng `bootstrap.activeAccount.id`. Profile của tài khoản active dùng dữ liệu tài chính từ bootstrap và dùng broker/server presentation từ linked account. Việc ghép chỉ diễn ra khi ID bằng nhau; không được ghép theo login, vị trí trong danh sách hoặc display name.

`ExV2AccountPresentation` được mở rộng bằng access-point presentation tùy chọn. Khi API không cung cấp access point, UI dùng nhãn presentation trung tính `Access Point #1`; nhãn này không tham gia request, account identity hoặc dữ liệu tài chính.

### Broker mark và bố cục

Thêm brand `yodo` cho broker ID/name chứa `yodo`. Brand này dùng ô vuông vàng với wordmark `yodo`, giữ đúng kích thước 31 logical pixels và hình học của broker mark trong video. Không gắn nhãn Exness cho tài khoản YODO.

Màn hình tài khoản giữ:

- toolbar tròn back/add hiện có;
- row cao và khoảng cách hiện có đã được kiểm tra theo video;
- active row nền xám, tên xanh, metadata trắng, chevron;
- inactive row nền đen, tên trắng, metadata xám;
- cùng account name, broker mark, server/currency/mode presentation cho các tài khoản cùng broker; login là trường nhận dạng thay đổi theo account.

Không bịa balance cho inactive account. Khi contract list chưa có balance, dòng cuối chỉ hiển thị `USD, Hedge` thay vì `Unavailable`, dấu gạch giả hoặc `0.00` giả. Active account tiếp tục hiển thị balance canonical từ bootstrap.

### Chuyển tài khoản

Flutter chỉ chuyển state sau khi activate trả bootstrap có ba identity trùng nhau: requested account ID, response account ID và bootstrap account/summary ID. Sau success, bootstrap thay toàn bộ positions, orders, history, wallet, notifications và settings của account cũ.

HTTP 409 `concurrency_conflict` không được biến thành optimistic success và không được tự tạo số liệu client. Backend phải serialize account activation và trả canonical bootstrap của account mới. Tài liệu backend đi kèm phải yêu cầu regression test cho hai linked accounts, concurrent requests, idempotency và rollback.

## Error handling

- Activate lỗi: giữ nguyên account cũ và hiển thị message/code/correlationId đã sanitize.
- Linked-account metadata lỗi: giữ bootstrap hiện tại; không hiển thị secret.
- Metadata thiếu: dùng presentation trung tính, không dùng chuỗi `Unavailable` trên UI.
- Không log password, device token, Authorization, reconnectGrant hoặc toàn bộ body.

## Kiểm thử

- Mapper nhận broker/server của linked account đúng active ID sau cold start.
- Không ghép metadata của account khác dù login/display name giống nhau.
- YODO render broker mark vàng 31 x 31 và không render Exness wordmark.
- Settings không còn `Unavailable` và vẫn giữ thứ tự name/company/login-server/access point.
- Account list active/inactive khớp màu, chevron và ba dòng trong video.
- Inactive account thiếu balance không hiển thị số dư giả.
- Activate success thay toàn bộ account-scoped state; activate 409 giữ account cũ.
- Chạy focused tests, `flutter analyze`, full `flutter test`, APK build, backend build/test và chụp LDPlayer.

## Phạm vi

- Không đổi base URL, endpoint, device-token security hoặc technology stack.
- Không hard-code login, password, balance, position hoặc history từ video.
- Không giả mạo broker Exness cho dữ liệu YODO.
- Không sửa local backend market-data project để giả làm EX V2 production.

