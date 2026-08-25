# Close Position Buttons Design

## Goal

Trong ticket đóng position, cả `Sell by Market`, `Buy by Market` và thanh cam
`Đóng #...` đều đóng đúng position đang chọn trên EX V2. Không nút nào được mở
một position đối ứng.

## Behavior

- Ticket tạo lệnh mới giữ nguyên hành vi BUY/SELL hiện tại.
- Ticket có `closePositionId` chuyển cả hai callback BUY/SELL sang cùng
  `_closePosition(position)`.
- `submitting` khóa cả ba vùng bấm ngay từ lần nhấn đầu tiên.
- Thành công chỉ được hiển thị sau khi server bootstrap xác nhận position đã
  biến mất và close deal đã được tải về.
- Lỗi API giữ ticket mở và hiển thị snackbar hiện có.
- Không đổi màu, chữ, kích thước hoặc bố cục.

## Verification

- Widget test chứng minh nhấn SELL trong ticket đóng làm position biến mất.
- Widget test chứng minh nhấn BUY trong ticket đóng làm position biến mất.
- Test hiện có tiếp tục chứng minh close deal và giá khớp đến từ server.
- Chạy analyze, toàn bộ Flutter test, build APK và kiểm tra trên LDPlayer.

