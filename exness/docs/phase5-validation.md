# Phase 5 — biểu đồ so với video

Ngày kiểm tra: 20/09/2026. Máy: LDPlayer 9, 660 × 1434 px, Android; video chuẩn 384 × 848 px. APK: `build/app/outputs/flutter-apk/app-debug.apk`, SHA-256 `38C7B72C09D82412846A87003B71DB7FEF1022D7445C3F77B8DF8BE25BA4EBDB`.

## Bằng chứng hình ảnh

- Video: [48 giây](reference-frames/48s.png), [54 giây](reference-frames/54s.png), [58 giây](reference-frames/58s.png).
- LDPlayer: [XAU/USD M1](screenshots/phase5-chart-ldplayer.png), [sheet Thiết lập](screenshots/phase5-chart-settings-ldplayer.png).

Sau khi đưa ảnh LDPlayer về cùng chiều rộng 384 px, tay nắm, toolbar, chip mã, vùng nến hồng, thang giá trắng, hai nhãn Bid/Ask, hàng công cụ và đỉnh sheet nằm gần các mốc đo ở video. Mật độ lưới giá được chỉnh về khoảng 2,0 điểm vàng như video. Khoảng cách nến đã chỉnh để cây nến cuối nằm khoảng x≈215–220 trên vùng vẽ x=0–328. Ảnh vẫn khác nhãn thời gian và một số nét biểu tượng; giá/số dư trong video là snapshot lịch sử, không dùng làm hằng số trong app.

## Kiểm tra hành vi

- REST nạp nến XAUUSD+ M1; SignalR/REST hiển thị Bid/Ask. Nến được sort và loại trùng timestamp; quote cũ không đẩy nến lùi thời gian. JavaScript cập nhật series mà không reload WebView.
- Trên LDPlayer đã mở chart từ tab Giao dịch, kéo biểu đồ sang nến cũ và reset về nến mới, đổi khung 1m → 5m, đổi mã XAU/USD → BTC, mở/đóng sheet và chọn các mục điều khiển. Pinch zoom được bật trong Lightweight Charts, chưa có phép đo đa chạm tự động trên LDPlayer.
- `flutter analyze --no-pub`: không có issue. `flutter test --no-pub`: 56/56 qua. `flutter build apk --debug --no-pub`: thành công. `node --check assets/chart/chart.js`: thành công.
- `dotnet build Trading.sln --nologo`: 0 warning/error. `dotnet test Trading.sln --no-build --nologo`: 17/17 qua.

## Phần chưa thể xác nhận giống 100%

- LDPlayer chưa đăng nhập tài khoản demo EX V2 được cấp quyền. Số dư, lịch sử lệnh và các màn hình có dữ liệu tài khoản trong video chưa thể đối chiếu bằng dữ liệu thật của phiên đó.
- API thị trường hiện không cung cấp giờ mở cửa kế tiếp hoặc phân trang nến quá khứ. Nút thông báo giờ mở cửa ở trạng thái không khả dụng; không dùng mốc 21/9 · 05:01 của bản ghi làm lịch hiện tại.
- Feed API chưa cung cấp tin tức, tín hiệu, sự kiện, loyalty/referral như khung hình video. App hiển thị trạng thái thiếu dữ liệu ở các mục này. Lựa chọn Exness/TradingView trong sheet đổi kiểu hiển thị, không đổi nguồn giá.
- Video chạy iOS còn bản kiểm tra chạy Android. Status bar/Dynamic Island là mô phỏng trong vùng app; font/hệ biểu tượng và thao tác hệ điều hành không thể giống iOS ở mức pixel.
