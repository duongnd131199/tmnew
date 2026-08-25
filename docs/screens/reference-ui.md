# Reference UI

## Reference

- Thư mục ảnh/video: `giaoDienMau`.
- Ảnh tĩnh: 9 ảnh JPEG, kích thước 590 × 1280.
- Video: 4 MP4, kích thước 384 × 848, 30 fps.
- Thiết bị kiểm tra: LDPlayer-1, 590 × 1280, 240 dpi.

## Visual foundations

- Nền ứng dụng: đen tuyệt đối.
- Surface nổi: xám đen, border xám mảnh.
- Màu nhấn: xanh iOS cho trạng thái tăng/được chọn.
- Màu giảm/cảnh báo lệnh: đỏ.
- Font: họ sans-serif condensed, số dùng tabular figures.
- App content được bố trí dưới safe area; system status bar không được giả lập
  trong Flutter.

## Shared navigation

- Capsule nổi cách mép ngang khoảng 19 logical pixels.
- Năm tab: Giá, Biểu đồ, Giao dịch, Lịch sử, Cài đặt.
- Tab chọn có nền xám tròn; icon và label chuyển xanh.
- Phần dưới capsule dành khoảng trống cho bottom safe area.

## Giá

- Header gồm menu tròn, tiêu đề căn giữa, sửa và tìm kiếm.
- Quote row hiển thị thay đổi, symbol, thời gian, spread, Bid/Ask, Low/High.
- Giá dùng ba cấp cỡ chữ để nhấn mạnh pip và fractional pip.
- Trạng thái mẫu gồm danh sách 1, 2 và 4 symbol; thêm/xóa/sắp xếp symbol.
- Nút danh sách bên trái chuyển qua lại giữa danh sách chi tiết và bảng cột.
- Ở bảng cột, nút quản lý mở màn hình Cột; ở danh sách chi tiết, nút này mở
  màn hình sửa symbol.
- Màn hình sửa giữ bottom navigation, không cho chọn/xóa symbol đầu tiên, và
  mở rộng nút quản lý thành cụm xóa + cột khi có symbol được chọn.
- Màn hình tìm kiếm tự focus ô nhập; nút X lớn đóng màn hình, nút X nhỏ xóa
  truy vấn. Khi bàn phím đóng, bottom navigation xuất hiện lại.
- Kết quả tìm kiếm toàn cục được nhóm theo `Nasdaq|Stock`, `Nasdaq|ETF`,
  `Metals`, `Forex`, `Indexes`; chạm cả dòng hoặc vòng tròn đều thêm symbol.
- Số lượng đã chọn trong Forex, Metals, Indexes và Nasdaq cập nhật theo
  watchlist hiện tại.

## Biểu đồ

- Hai trạng thái toolbar: công cụ biểu đồ và danh sách timeframe.
- Khi toolbar công cụ hoạt động, one-click trading nằm ngay bên dưới.
- Nút đỏ/xanh ở góc phải toolbar bật/tắt one-click trading; nhấn giữ mở
  trình tạo lệnh chờ nâng cao.
- Khi danh sách timeframe hoạt động, chart bắt đầu ngay dưới toolbar.
- Chart có nền đen, grid tối, candle teal/đỏ, price axis bên phải và time axis
  phía dưới.
- Position, đường Bid hiện tại và nhãn giá được vẽ trực tiếp trên chart; đường
  Ask không bật trong video mẫu.
- Feed demo chạy liên tục cả ngoài giờ thị trường. Mỗi tick cập nhật đồng bộ
  SELL/BUY, đường Bid, nến cuối và lợi nhuận; trục tham chiếu không tự căn lại
  theo từng tick để chuyển động giá vẫn nhìn thấy được.
- XAUUSD dùng chuỗi tham chiếu cho M1/M5/M15/M30/D1 và chuỗi tuần/tháng có biên
  độ tương ứng; AUDNOK M1 giữ nhịp nến, thang 0.00165 và mốc giờ của ảnh mẫu.
- Tất cả timeframe H1/H4/W1/MN và AUDNOK M5+ phải tiếp tục hiện nến thật, không
  được co thành đường ngang hoặc các chấm rời.
- Tap một đường pending order mở thanh thao tác đáy gồm pill loại lệnh/volume,
  Stop Loss, Take Profit và nút thu gọn.
- Tap vùng khác của chart không được mở thanh pending order. Tap pill sửa giá;
  kéo mũi tên của pill sang phải xác nhận, hiển thị `Hoàn tất` trong 1,6 giây
  rồi thu thanh thao tác nhưng vẫn giữ đường lệnh trên chart.

## Giao dịch

- Header chỉ hiển thị tổng profit/loss ở giữa và nút thêm bên phải.
- Account metrics căn hai phía, không dùng dotted leader.
- Section header đen-xám, position row gồm hai dòng và profit bên phải.
- Nút thêm mở form lệnh thị trường bình thường, không gắn hành động đóng position.
- Vuốt position sang trái mở ba action `…`, sửa và đóng.
- Nút sửa mở màn Stop Loss/Take Profit của đúng ticket.
- Nút đóng mở form lệnh có thanh cam chứa ticket và P/L; không đóng ngay tại danh sách.
- Tap position mở action sheet; nút `…` và long press mở dialog hành động giữa màn hình.

## Lịch sử

- Segmented control ba tab: Lệnh có trạng thái, Các lệnh, Các giao dịch.
- Nút sắp xếp bên trái và chọn khoảng thời gian bên phải.
- Bộ lọc khoảng thời gian cho phép lọc tiếp theo symbol và giữ lựa chọn khi mở lại.
- Mỗi tab có nội dung và phần tổng kết riêng theo video mẫu.

## Cài đặt

- Các mục được gom trong ba card bo góc.
- Mỗi row có icon vuông màu, title, subtitle tùy chọn và chevron.
- Card đầu chứa thông tin tài khoản demo.
- Toàn bộ account row và các row có chevron đều phải điều hướng tới màn hình
  tương ứng, không để nút chỉ có hiệu ứng chạm.

## States

- Loading: dùng progress nhỏ với nền vẫn giữ nguyên bố cục.
- Empty: text secondary căn giữa.
- Error/offline: màu đỏ, không thay đổi chiều cao layout.
- Success: nội dung chính theo các màn hình mẫu.

## Interactions

- Tap tab: đổi branch, giữ state của từng branch.
- Tap symbol: mở menu thao tác.
- Tap timeframe: mở/đóng thanh timeframe.
- Tap Buy/Sell: gửi một lệnh demo và hiển thị màn hình hoàn tất.
- Tap history segment: đổi nội dung tại chỗ.

## Assumptions

- Status bar trong ảnh là iOS; bản Android chỉ đặt status bar hệ thống thành
  màu đen với icon sáng, không giả mạo status bar iOS.
- Giá và thời gian trong ảnh/video thay đổi theo tick; layout, typography và
  trạng thái màu là chuẩn so sánh, còn giá trị realtime được phép biến đổi.
