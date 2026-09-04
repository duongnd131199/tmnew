# Account List

## Reference

- File ảnh: `iconMau/anhmau/1111111111115.jpg`
- Kích thước: 588 × 1280
- Thiết bị kiểm tra: iPhone 17 Simulator

## Layout

- Thanh tiêu đề có nút quay lại, tiêu đề `Tài khoản` và nút thêm.
- Tài khoản đang hoạt động đứng đầu; các tài khoản còn lại giữ thứ tự hiện có.
- Khối tài khoản mặc định `Delete` luôn đứng cuối danh sách.
- Mọi hàng tài khoản có nền trắng; tài khoản đang hoạt động được nhận biết bằng chữ xanh, đậm và dấu mũi tên.

## Fixed Delete Account

- Tên: `Delete`
- Đăng nhập và máy chủ: `28210230 - VantageMarkets-Live 19`
- Số dư: `0.00 USD, Hedge`
- Nhận diện: Vantage
- Đây là khối trình bày mặc định, luôn hiển thị và không phản hồi thao tác chạm.

## Remove Account From This Device

- Các tài khoản thật đã bị gỡ khỏi thiết bị không còn xuất hiện; khối `Delete` mặc định vẫn được giữ.
- Mở tài khoản đang hoạt động, cuộn xuống và chạm `Xóa tài khoản` để mở xác nhận.
- Thao tác chỉ gỡ phiên khỏi thiết bị; dữ liệu tài khoản trên máy chủ vẫn được giữ.
- Nếu còn tài khoản khác, ứng dụng tự chuyển sang tài khoản đầu tiên còn lại.
- Nếu không còn tài khoản nào, ứng dụng xóa phiên thiết bị và trở về đăng nhập.

## States

- Loading: khối `Delete` mặc định vẫn hiển thị trong khi danh sách máy chủ chưa sẵn sàng.
- Empty: chỉ hiển thị khối `Delete` mặc định.
- Error: giữ trạng thái lỗi hiện có và vẫn giữ khối `Delete` khi màn hình được dựng.
- Success: hiển thị tài khoản thật chưa bị gỡ, sau đó là khối `Delete` mặc định.

## Interactions

- Chạm tài khoản đang hoạt động mở chi tiết tài khoản.
- Chạm tài khoản khác thực hiện luồng chuyển tài khoản hiện có.
- Chạm khối `Delete` mặc định không thực hiện hành động.
- Trong chi tiết tài khoản, chạm `Xóa tài khoản` mở hộp thoại xác nhận gỡ khỏi thiết bị.

## Assumptions

- Production API chưa có endpoint unlink/delete riêng; trạng thái gỡ được lưu cục bộ trong Secure Storage.
- Khối `Delete` là dữ liệu trình bày cố định theo ảnh mẫu, không phải tài khoản từ API.
