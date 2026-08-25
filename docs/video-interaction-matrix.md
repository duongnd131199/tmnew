# Ma trận tương tác video mẫu

Tài liệu này ghi lại hành vi có thể quan sát trực tiếp từ bốn video trong
`giaoDienMau`. Giá realtime và thời điểm tick được phép thay đổi; điều hướng,
trạng thái, vùng bấm và kết quả thao tác phải giữ nguyên.

## IMG_0848.MP4

| Khu vực | Thao tác | Kết quả cần có |
|---|---|---|
| Giá | Chuyển chế độ danh sách/cột | Đổi layout và giữ watchlist |
| Giá | Mở sửa, chọn, xóa symbol | Symbol đầu không thể xóa; danh sách cập nhật |
| Giá | Tìm kiếm và thêm symbol | Kết quả theo nhóm; số lượng nhóm cập nhật |
| Giá | Tap symbol | Mở menu chart, lệnh, thuộc tính, DOM và thống kê |
| Biểu đồ | Tap timeframe | Mở/đóng dải timeframe và đổi dữ liệu chart |
| Biểu đồ | Kéo, pinch, crosshair | Pan, zoom và đo trên chart |
| Biểu đồ | Tap nút đỏ/xanh | Bật/tắt one-click trading |
| Biểu đồ | Indicators/Objects | Mở màn hình tương ứng; thêm/xóa mục có hiệu lực |
| Biểu đồ | Tap đúng đường lệnh chờ | Mở thanh chỉnh Buy Limit, SL, TP |
| Biểu đồ | Tap ngoài đường lệnh chờ | Không mở thanh lệnh |
| Biểu đồ | Kéo pill Buy Limit | Hiện trạng thái xanh `Hoàn tất`, tự thu sau 1,6 giây |
| Giao dịch | Tap nút cộng | Mở form lệnh mới |
| Giao dịch | Tap/vuốt/nhấn giữ position | Mở action sheet, action vuốt hoặc dialog đúng ticket |
| Giao dịch | Sửa/đóng position | Form mang đúng ticket; đóng không xảy ra ngay từ list |
| Lịch sử | Chuyển ba tab | Nội dung và tổng kết đổi tại chỗ |
| Cài đặt | Cuộn và tap row | Cuộn trơn; account/chevron điều hướng được |

## IMG_0880.MP4

| Khu vực | Thao tác | Kết quả cần có |
|---|---|---|
| Giá | Chuyển sang bảng compact | Hiện layout cột |
| Giá | Mở màn hình Cột | Cho phép quản lý cột hiển thị |
| Tìm kiếm | Nhập `u`, `us` | Lọc kết quả ngay khi nhập |
| Tìm kiếm | Thêm nhóm USA | Symbol xuất hiện trong watchlist |
| Sửa symbol | Chọn/xóa USA | Watchlist và số đếm nhóm cập nhật |

## IMG_0881.MP4

| Khu vực | Thao tác | Kết quả cần có |
|---|---|---|
| Biểu đồ | Pan/zoom ở M1 | Candle và trục dịch chuyển/tỷ lệ cùng nhau |
| Biểu đồ | Chọn M5/M15/M30/D1 | Dữ liệu, nhãn và timeframe đang chọn cập nhật |
| Biểu đồ | Chọn H1/H4/W1/MN | Nến vẫn có đủ biên độ; không bị ép thành đường ngang hoặc các chấm rời |
| Biểu đồ | Mở AUDNOK M1 | Dải giá 0.00165, nhãn 16:48–19:12 và nhịp giảm bám ảnh mẫu |
| Biểu đồ | Đổi AUDNOK sang M5+ | Mỗi timeframe có nến dày, trục giá hợp lệ và không lệch khỏi giá hiện tại |
| Biểu đồ | Bật/tắt one-click nhiều lần | Panel xuất hiện/biến mất ổn định |
| Biểu đồ | Chờ tick giá | SELL/BUY, đường Bid, nến cuối và P/L cùng cập nhật khoảng 850 ms; feed demo không đóng băng cuối tuần |
| Biểu đồ | Objects/Indicators | Các nút công cụ tạo nội dung thật |
| Biểu đồ | Crosshair | Hiện đường dóng và giá/thời gian tương ứng |

## IMG_0882.MP4

| Khu vực | Thao tác | Kết quả cần có |
|---|---|---|
| Giao dịch | Tap account tick/nút cộng | Mở đúng account action/form lệnh mới |
| Giao dịch | Vuốt position | Hiện `…`, sửa và đóng |
| Giao dịch | Tap `…`/nhấn giữ | Dialog hành động chứa đúng ticket |
| Giao dịch | Tap sửa | Mở form SL/TP đúng ticket |
| Giao dịch | Tap đóng | Mở close form có thanh cam, ticket và P/L |
| Form lệnh | Chuyển Buy/Sell và gửi | Đổi phía lệnh, gửi và hiển thị hoàn tất |
| Lịch sử | Ba segment, khoảng thời gian, symbol | Lọc đúng và giữ lựa chọn khi mở lại |
| Cài đặt | Cuộn danh sách | Hiển thị đầy đủ các nhóm và row |

## Kiểm thử tự động liên quan

- `test/chart_controls_test.dart`: toolbar, one-click, timeframe, symbol info và objects.
- `test/video_interactions_test.dart`: form lệnh, thao tác position, hit target
  đường lệnh chờ, SL/TP và kéo xác nhận.
- `test/video_button_coverage_test.dart`: tab/filter Lịch sử và điều hướng Cài đặt.
- `test/section_functionality_test.dart`: Thuộc tính symbol, DOM và Thống kê thị
  trường có dữ liệu và thao tác thật.

## Ảnh đối chiếu cuối

- `docs/screenshots/final-chart-audnok-video-layout.png`: AUDNOK M1 ở đúng trạng
  thái toolbar timeframe của ảnh mẫu.
- `docs/screenshots/live-chart-tick-1.png` và `live-chart-tick-2.png`: hai khung
  cách nhau bốn giây xác nhận giá, đường Bid và P/L đang chạy.
- `docs/screenshots/final-chart-audnok-m5.png`: kiểm tra không còn lỗi nến rời/co
  khi đổi timeframe.
- `docs/screenshots/final-chart-w1.png` và `final-chart-mn.png`: kiểm tra các
  timeframe dài vẫn giữ biên độ nến.
- `docs/screenshots/final-chart-indicators.png` và `final-chart-objects.png`:
  vị trí card, icon và khoảng cách đã đối chiếu theo IMG_0881.
- `docs/screenshots/final-order-overlay.png`: panel lệnh trượt từ phải, giữ dải
  nội dung Giao dịch bên trái và bottom navigation đúng trạng thái đỏ.

## giaodientrang.MP4 — hành động hàng loạt theo vị thế

| Khu vực | Thao tác | Kết quả cần có |
|---|---|---|
| Giao dịch | Chạm một position đang mở | Mở action sheet đúng ticket, side, volume, symbol, giá và P/L |
| Action sheet position | Chạm `Hoạt động hàng loạt...` | Sheet đóng hoàn toàn rồi mở dialog theo position với đúng năm scope: tất cả, có lời, cùng phía, cùng symbol, cùng symbol + phía |

Video chỉ quan sát luồng mở và `Hủy`; không chứng minh mutation phía server. Việc chọn đúng tập vị thế và dispatch EX V2 được kiểm chứng bằng fixture tự động, không bằng thao tác đóng lệnh trên tài khoản thiết bị.
