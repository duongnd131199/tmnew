# Account List

## Reference

- File ảnh: `iconMau/anhmau/1111111111115.jpg`
- Kích thước: 588 × 1280
- Thiết bị kiểm tra: iPhone 17 Simulator

## Layout

- Thanh tiêu đề có nút quay lại, tiêu đề `Tài khoản` và nút thêm.
- Tài khoản đang hoạt động đứng đầu; các tài khoản còn lại giữ thứ tự hiện có.
- Mọi hàng tài khoản có nền trắng; tài khoản đang hoạt động được nhận biết bằng chữ xanh, đậm và dấu mũi tên.

## Remove Account From This Device

- Danh sách chỉ hiển thị tài khoản thật chưa bị gỡ khỏi thiết bị.
- Mở tài khoản đang hoạt động, cuộn xuống và chạm `Xóa tài khoản` để mở xác nhận.
- Thao tác chỉ gỡ phiên khỏi thiết bị; dữ liệu tài khoản trên máy chủ vẫn được giữ.
- Nếu còn tài khoản khác, ứng dụng tự chuyển sang tài khoản đầu tiên còn lại.
- Nếu không còn tài khoản nào, ứng dụng xóa phiên thiết bị và trở về đăng nhập.

## States

- Loading: không hiển thị dữ liệu trình bày giả trong khi danh sách tài khoản máy chủ chưa sẵn sàng.
- Empty: không hiển thị hàng tài khoản nào.
- Error: giữ trạng thái lỗi hiện có và không thêm hàng tài khoản giả.
- Success: chỉ hiển thị tài khoản thật chưa bị gỡ khỏi thiết bị.

## Interactions

- Chạm tài khoản đang hoạt động mở chi tiết tài khoản.
- Chạm tài khoản khác thực hiện luồng chuyển tài khoản hiện có.
- Trong chi tiết tài khoản, chạm `Xóa tài khoản` mở hộp thoại xác nhận gỡ khỏi thiết bị.

## Assumptions

- Production API chưa có endpoint unlink/delete riêng; trạng thái gỡ được lưu cục bộ trong Secure Storage.
