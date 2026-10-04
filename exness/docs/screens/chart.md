# Biểu đồ XAU/USD — đối chiếu video 46–64 giây

Nguồn: `IMG_1265.MP4`, khung 384 × 848. Ảnh chuẩn: `docs/reference-frames/54s.png` và `58s.png`.

## Màn hình chính

- Vùng ứng dụng bắt đầu dưới status bar iPhone ở y≈54; tay nắm xám ở y≈66. Hàng điều khiển y≈75–114: One-click bên trái, viên số dư giữa, chuông và bánh răng bên phải.
- Biểu đồ nến từ y≈114 đến 650. Vùng vẽ x=0–328, nền RGB (248,234,234), thang giá x=328–384 nền trắng. Nến lên xanh, nến xuống đỏ; lưới xám mảnh; giá vàng có ba chữ số thập phân. Chip `XAU/USD` ở góc trên trái. Bid/Ask là hai đường ngang chấm và nhãn đỏ/xanh ở thang giá.
- Trục thời gian y≈650–681; hàng công cụ `1m`, kiểu nến, `ƒx` y≈681–730. Dòng thông báo mở cửa thị trường và nút gạt ở y≈730–800; phần dưới để trắng.
- Kéo ngang, pinch zoom, crosshair, nút đưa biểu đồ về vùng giá mới nhất. Thay khung thời gian và mã mà không tạo lại WebView. Dữ liệu đến từ Market REST và SignalR; giá/số dư không sao chép từ video.

## Sheet Thiết lập (58 giây)

- Sheet trắng phủ từ y≈201, góc trên bo tròn, X bên trái, tiêu đề giữa. Phần sau có lớp phủ tối.
- `Tùy chọn biểu đồ`: thẻ viền hai hàng `Hiển thị trên biểu đồ` (phụ đề), `Nguồn giá` (mặc định `Giá mua`).
- `Nhà cung cấp biểu đồ`: thẻ viền `Exness` chọn và `TradingView`; đây là lựa chọn kiểu hiển thị trong cùng thư viện biểu đồ, không đổi feed giá.
- Chú thích tùy chọn áp dụng cho mọi công cụ/tài khoản; `Truy cập nhanh`: Máy tính giao dịch, Phân tích, Thông số kỹ thuật. Các mục không có nguồn dữ liệu hoặc hành động được giải thích rõ, không giả lập kết quả.

## Trạng thái và phụ thuộc

- REST tải nến gần nhất, SignalR cập nhật quote; cảnh báo khi kết nối lại hoặc dữ liệu cũ. Nếu không có nến, hiện trạng thái trống/lỗi và nút tải lại.
- API chưa có tham số phân trang nến quá khứ và chưa có giờ mở cửa tiếp theo; không hiển thị giờ 21/9 05:01 đã ghi trong video như thông tin hiện tại. Nút thông báo giờ mở cửa chỉ bật khi có lịch thật.
- Số dư dùng bootstrap EX V2 nếu có phiên; khi chưa đăng nhập hiển thị trạng thái đăng nhập. Một số tính năng trong sheet chỉ có bố cục vì API chưa cung cấp tương ứng.
