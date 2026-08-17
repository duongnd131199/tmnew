# Thiết kế khớp video cho màn hình chọn máy chủ

## Mục tiêu

Làm cho khung hình chọn máy chủ trong Flutter khớp frame 14 của `giaoDienMau/themmoitk.MP4`, trong khi danh sách, ID, tên và trạng thái chọn vẫn đến từ EX V2 API thật.

## Bằng chứng và nguyên nhân

- Frame tham chiếu có kích thước 576×1280; nền danh sách bắt đầu tại `y=222`.
- Ảnh APK trên LDPlayer có chiều cao 1280; nền danh sách bắt đầu tại `y=253`.
- Toolbar, hàng server và các metric còn lại được render với scale 1.5. Sai lệch 31 px vật lý tương đương khoảng 21 logical px.
- `TradingServerScreen` đang thêm spacer 64 logical px sau toolbar. Frame video yêu cầu 43 logical px. Spacer 64 là nguyên nhân trực tiếp làm toàn bộ danh sách lệch xuống.

## Phương án

1. **Khuyến nghị: sửa spacer riêng của màn Máy chủ từ 64 thành 43.** Thay đổi nhỏ nhất, không ảnh hưởng Brokers hoặc form và khớp số đo thực tế.
2. Tăng/giảm chiều cao toolbar dùng chung. Phương án này làm hỏng màn Brokers vốn đã khớp video.
3. Dịch ListView bằng transform hoặc margin âm. Phương án này khó test, dễ sai hit-test/scroll và không cần thiết.

Chọn phương án 1.

## Thiết kế khung hình

- `AccountLinkToolbar`: giữ nguyên cao 81 logical px, Back tại top 37 và title tại top 49.
- Khoảng thở sau toolbar: 43 logical px.
- Top của `server-list`: 124 logical px tính từ đầu vùng SafeArea (`81 + 43`).
- Hàng server: giữ 56 logical px, lề ngang 16, divider 0.6 và checkmark 24.
- Nền, typography và màu selected tiếp tục dùng design token hiện tại; không lấy màu nén từ video làm màu sản phẩm.
- Danh sách có bao nhiêu hàng phụ thuộc hoàn toàn vào API. Không thêm Exness/server giả để lấp đầy màn hình.

## Dữ liệu và hành vi

- Tiếp tục gọi `AccountLinkRepository.servers(brokerId)`.
- Server đang chọn hiển thị checkmark; tap một hàng cập nhật controller, callback và pop về form.
- Loading, empty, error và retry giữ nguyên logic thật.
- Không thay backend, URL, request credential hoặc device-token contract.

## Kiểm thử và nghiệm thu

- Widget test ở width 360, 390 và 430 phải xác nhận `server-list.top == 124` logical px.
- Test hàng server xác nhận pitch 56, divider, selected checkmark, scroll và callback/pop.
- Test catalog thật giả lập bằng YODO phải chỉ hiển thị dữ liệu repository, không có Exness/MetaQuotes.
- Chạy `flutter analyze`, `flutter test`, `flutter build apk --debug`, `dotnet build Trading.sln --no-restore` và `dotnet test Trading.sln --no-build`.
- Cài APK bằng ADB lên `MT5-Dev`, chụp lại màn Máy chủ và đo nền danh sách. Mục tiêu là `y=221–222` trên ảnh cao 1280, cho phép 1 px do rasterization.

## Giới hạn chính xác

"Giống 100%" được áp dụng cho bố cục, nhịp hàng, typography, màu semantic, icon và hành vi trong khung màn hình. Nội dung không thể giống danh sách Exness trong video khi API thật trả về YODO và chỉ một server; bị cấm làm giả phần dữ liệu này.
