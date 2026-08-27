# Reference UI

## Reference

- Bộ parity cuối: 7 ảnh progressive JPEG trong `iconMau/anhmau`, mỗi ảnh
  590 × 1280 physical pixels; không có ảnh gốc lossless.
- Candidate được render từ production widgets ở viewport
  393.3333333333 × 853.3333333333 logical pixels, DPR 1.5 và text scale 1.0.
- Bản tích hợp cuối chạy trên iPhone 17 đang mở sẵn; không mở simulator thứ hai.

## Visual foundations

- Nền ứng dụng và surface chính: trắng theo bảy ảnh parity.
- Surface được chọn và section dùng các mức xám semantic đã khóa trong design
  system.
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
- Shadow production dùng alpha `0x0D`, blur 30, spread
  `9.6666666667` và offset `(0, 4)` logical pixels.

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
- XAUUSD M1 production dùng 10 logical pixels navigation overlap. BUY tag theo
  side của position; annotation và X-axis đã căn chuẩn; axis/subtitle dùng
  `#404040`; plot boundary ở physical x=507 và plot blue là `#3985E9`.
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
- Section strip dùng `#F8F8F8`. Nút thêm 42.6667 logical pixels, không border,
  với circular shadow alpha `0x19`, blur 30 và offset `(0, 4)`.
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
- Scrollbar bounds là `[581,177,5,687]`, `[581,474,5,688]` và
  `[581,525,5,637]` cho Orders, Orders Summary và Deals. Bốn selected-segment
  interior được audit như static surface, không phải text.

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

- Status bar là nội dung hệ điều hành; clock/carrier/signal/battery là typed
  dynamic/OS evidence, không phải pixel do app kiểm soát.
- Giá và thời gian trong ảnh/video thay đổi theo tick; layout, typography và
  trạng thái màu là chuẩn so sánh, còn giá trị realtime được phép biến đổi.

## Trạng thái triển khai 2026-08-27

- Final independent QA không còn phát hiện mismatch ổn định do app kiểm soát về
  font, size, weight, letter-spacing, color hoặc block spacing; principal static
  glyph bounds nằm trong một physical pixel. Prices toolbar/row pitch/symbol/
  metadata/Bid-Ask/L-H đều được khóa bằng regression tests.
- Comparator strict vẫn exit 1: 64 PASS, 186 FAIL và 30 typed SKIP trên 280
  rows. Tất cả mismatch ổn định có evidence nhất quán đã được sửa; phần còn lại
  là progressive-JPEG/non-invertible evidence, broad/dependent residual hoặc
  typed dynamic/OS evidence. Không tuyên bố mathematical/raw-pixel 100%.
- App cuối chạy trong iPhone 17 simulator
  `5AD1B6AA-5814-4EAA-A573-4B9C561BABA4`, bundle
  `com.tradingdemo.tradingMobile`, persistent Flutter session `11742`; không mở
  simulator thứ hai.
