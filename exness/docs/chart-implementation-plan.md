# Kế hoạch triển khai biểu đồ theo video

1. Chuẩn hóa nến theo timestamp UTC: sort, loại trùng, gộp quote mới vào đúng bucket timeframe; kiểm thử timestamp cũ, bucket mới và đổi khung.
2. Đóng gói TradingView Lightweight Charts bản đã ghim vào asset offline, tạo một WebView và bridge lệnh `setData`/`update`/Bid/Ask. Dùng một lần khởi tạo cho mỗi lần mở chart; giữ zoom khi quote đổi.
3. Lắp giao diện Flutter quanh chart theo tọa độ đo từ 54s, sheet theo 58s. Điều khiển khung, mã, giá mua/bán, nhà cung cấp hiển thị và reset chart phải hoạt động; thông tin chưa có API ở trạng thái giải thích được.
4. Chạy test, analyze, build, cài APK trên LDPlayer, chụp và đối chiếu với các frame 46–64s. Kiểm tra toàn bộ UI còn lại ở các frame chính, ghi rõ sai khác nào cần phiên demo hoặc API.
