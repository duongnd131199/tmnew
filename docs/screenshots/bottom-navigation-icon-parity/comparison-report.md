# Báo cáo đối chiếu icon thanh điều hướng dưới

## Nguồn và phương pháp

- Video chuẩn: `giaoDienMau/giaodientrang.MP4`, 384 x 848, các trạng thái tại 0,0 s, 12,0 s, 20,0 s và 36,0 s.
- Chuẩn đo hình học: raster Flutter 384 x 848, ngưỡng luminance `< 160`, đo nửa khoảng `[left, top, right, bottom)`.
- Runtime: APK debug mới cài bằng `adb install -r` trên `emulator-5560`, không xóa app data; màn hình hiện tại 590 x 1280 ở density 1,5 (xấp xỉ 393 x 853 logical px).
- Giới hạn hợp lý: không so byte-for-byte trực tiếp với MP4 H.264 vì codec và anti-aliasing Android tạo nhiễu biên. Contract khóa kích thước/vị trí phần mực nhìn thấy, topology, màu semantic và golden Flutter.

## Sai lệch đã sửa

| Icon | App trước sửa | Video chuẩn | App sau sửa | Kết quả hình học |
|---|---:|---:|---:|---|
| Giá | 20 x 17, top y=786 | 18 x 16, top y=790 | 18 x 16, top y=790 | Khớp đúng bound |
| Biểu đồ | 14 x 18, top y=786 | 13 x 16, top y=790 | 13 x 16, top y=790 | Khớp đúng bound |
| Giao dịch | 18 x 19, top y=785 | 19 x 18, top y=789 | 19 x 18, top y=789 | Khớp đúng bound |
| Lịch sử | 20 x 20, top y=785 | 20 x 18, top y=789 | 20 x 18, top y=789 | Khớp đúng bound |

| Thuộc tính | Trước sửa | Video chuẩn / sau sửa |
|---|---:|---:|
| Nền capsule | `#FDFDFD` | `#FDFDFD` |
| Nền tab đang chọn | `#E6F2FC` | `#E8E8E8` |
| Mực icon không chọn | `#3C3C43` | `#303030` |
| Viền capsule | 0,7 px `#D9D9DE` | Không có viền |
| Trade dương / âm | Xanh / đỏ | Giữ nguyên xanh / đỏ |

Không đổi các path Canvas bên trong icon. Chỉ hiệu chỉnh baseline và transform của bốn icon, vì topology ban đầu đã đúng với mẫu: hai mũi tên Giá, hai nến Biểu đồ, khung xu hướng Giao dịch và vòng cung/kim Lịch sử.

## Bằng chứng runtime

- `quotes-selected.png`
- `chart-selected.png`
- `trade-selected.png`
- `history-selected.png`

Trên viewport runtime 393 logical px, capsule co giãn đúng, bốn icon không bị cắt và năm tab vẫn bấm được. Test responsive khóa thêm các width 360, 384, 393 và 430.

## Bằng chứng tự động

- `bottom_navigation_icon_parity_test.dart`: 5 contract gồm palette/viền, bound chính xác, Trade xanh/đỏ, 4 golden và responsive/hit target.
- Focused navigation regression: 26/26 pass.
- Full Flutter suite: 560/560 pass.
- `flutter analyze`: không có issue.
- APK debug: build thành công.
- Backend build: 0 warning, 0 error; backend tests 17/17 pass.

