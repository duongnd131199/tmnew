# Account List

## Reference

- File ảnh: `iconMau/anhmau/1111111111115.jpg`
- Kích thước: 588 × 1280
- Thiết bị kiểm tra: iPhone 17 Simulator

## Layout

- Thanh tiêu đề có nút quay lại, tiêu đề `Tài khoản` và nút thêm.
- Tài khoản đang hoạt động đứng đầu; các tài khoản còn lại giữ thứ tự hiện có.
- Hàng `Delete` cố định đứng cuối danh sách.
- Mọi hàng tài khoản có nền trắng; tài khoản đang hoạt động được nhận biết bằng chữ xanh, đậm và dấu mũi tên.

## Fixed Delete Account

- Tên: `Delete`
- Đăng nhập và máy chủ: `28210230 - VantageMarkets-Live 19`
- Số dư: `0.00 USD, Hedge`
- Nhận diện: Vantage
- Hàng chỉ dùng để hiển thị và không phản hồi thao tác chạm.

## States

- Loading: vẫn hiển thị hàng `Delete` trong khi danh sách tài khoản máy chủ chưa sẵn sàng.
- Empty: chỉ hiển thị hàng `Delete`.
- Error: giữ trạng thái lỗi hiện có và vẫn hiển thị hàng `Delete` nếu màn hình danh sách được dựng.
- Success: hiển thị tài khoản thật, sau đó là hàng `Delete`.

## Interactions

- Chạm tài khoản đang hoạt động mở chi tiết tài khoản.
- Chạm tài khoản khác thực hiện luồng chuyển tài khoản hiện có.
- Chạm `Delete` không thực hiện hành động.

## Assumptions

- Hàng `Delete` là dữ liệu trình bày cố định theo ảnh mẫu, không phải tài khoản giao dịch từ API.
