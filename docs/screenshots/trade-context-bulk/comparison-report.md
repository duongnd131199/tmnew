# Báo cáo đối chiếu hành động hàng loạt theo vị thế

## Bằng chứng

- Video tham chiếu: `giaoDienMau/giaodientrang.MP4`, frame 23,4 giây cho action sheet và 29,0 giây cho dialog.
- Thiết bị: LDPlayer `emulator-5560`; APK debug cài bằng `adb install -r`, không xóa app data.
- Viewport chụp: 576 × 1272 physical px, tương đương chính xác 384 × 848 logical px ở hệ số 1,5.
- Ảnh: `position-actions-final.png` và `bulk-actions-final.png` trong cùng thư mục.

## Kết quả

| Hạng mục | Video | APK | Kết quả |
|---|---|---|---|
| Chuỗi modal | Sheet đóng rồi dialog mở | Đúng; không có modal chồng | Đạt |
| Copy và thứ tự | 5 action destructive + Hủy | Đúng đủ và đúng thứ tự | Đạt |
| Dữ liệu động | Ticket/side/volume/symbol/open price | Đúng vị thế BTCUSD BUY đã chọn; UUID dài tự scale-down một dòng nên vẫn giữ đủ symbol và giá mở | Đạt |
| Biên ngang | x≈16–371 | x≈16–372 logical px | Sai số ≤1 px |
| Pill | cao≈43–44, gap≈8 | cao≈44, gap≈8 logical px | Đạt |
| Màu/radius/barrier | nền trắng xám, chữ đỏ, pill tròn, nền dim | Cùng semantic token và cấu trúc | Đạt |
| Thoát an toàn | Hủy về Trade | Đúng, không đóng lệnh | Đạt |

Golden 384 × 848 khóa biên dialog x≈16–372 và y≈238–638. Ảnh Android thiết bị có baseline dọc khác nhẹ do safe area và font `sans-serif-condensed` native; vùng này được loại khỏi pixel-perfect cross-platform theo contract. Không có sai copy, thiếu action, sai thứ tự hoặc sai target semantics.

Không action đóng nào được bấm thủ công trên tài khoản đang đăng nhập. Semantics của cả năm scope được xác nhận bằng controller test, UI-flow test và server-dispatch regression.
