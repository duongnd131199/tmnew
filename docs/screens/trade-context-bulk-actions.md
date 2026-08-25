# Hành động hàng loạt theo vị thế

## Phạm vi đối chiếu

- Nguồn: `giaoDienMau/giaodientrang.MP4`, đoạn 22,6–32,0 giây.
- Viewport chuẩn: 384 × 848 logical px.
- Entry point: tab Giao dịch → chạm một vị thế đang mở → `Hoạt động hàng loạt...`.
- Exit an toàn: `Hủy`, barrier hoặc Back; không thay đổi vị thế.
- Menu hàng loạt ở dấu ba chấm của tiêu đề và menu lệnh chờ không thuộc thay đổi này.

## Chuỗi modal

Action sheet của vị thế phải đóng hoàn toàn trước khi dialog theo vị thế được mở. Dialog không được xếp chồng lên bottom sheet và luôn hiển thị ticket của vị thế đã chọn.

Thứ tự nội dung:

1. `Hoạt động hàng loạt`.
2. `#<ticket> <side lowercase> <volume> <symbol> <open price>`.
3. `Đóng Tất Cả Lệnh Có Trạng Thái`.
4. `Đóng Các Lệnh Có Trạng Thái Đang Có Lời`.
5. `Đóng <Buy|Sell> Lệnh có trạng thái`.
6. `Đóng <symbol> Lệnh có trạng thái`.
7. `Đóng <symbol> <Buy|Sell> Lệnh có trạng thái`.
8. `Hủy`.

## Quy tắc nghiệp vụ

| Hành động | Tập vị thế được đóng |
|---|---|
| Tất cả | Mọi vị thế đang mở |
| Đang có lời | `profit > 0`; vị thế hòa vốn không được chọn |
| Cùng phía | Cùng BUY/SELL sau khi chuẩn hóa chữ hoa/thường |
| Cùng symbol | Symbol khớp nguyên chuỗi, kể cả hậu tố như `+` |
| Cùng symbol và phía | Đồng thời thỏa hai điều kiện trên |

Controller chụp danh sách ID tại thời điểm người dùng bấm rồi gọi lại luồng `closePosition` hiện có cho từng ID. Vì vậy demo, EX V2, lịch sử, số dư, optimistic state và reconciliation vẫn đi qua cơ chế sẵn có; widget không tự sửa danh sách vị thế.

## Hình học và màu

- Dialog tham chiếu gần x=16–371, y=238–638 trên canvas chuẩn.
- Action pill cao khoảng 44 px, cách nhau khoảng 8 px, bo tròn dạng pill.
- Dùng `sheetSurface`, `sheetActionSurface`, `textPrimary`, `textSecondary` và `destructive` của design system.
- Ticket, giá, P/L, status bar và rasterization font hệ điều hành là dữ liệu động/khác nền tảng, không dùng để quyết định pixel parity.

## Bảo vệ hồi quy

- Menu dấu ba chấm trên tiêu đề vẫn có đúng ba mục: tất cả, có lời và đang lỗ.
- Pending-order actions, Đóng trạng thái, Sửa trạng thái, Giao dịch, Depth of Market, Biểu đồ và Close By không đổi route hay semantics.
- Thao tác visual trên tài khoản thiết bị chỉ mở rồi bấm `Hủy`; năm mutation được kiểm chứng bằng fixture tự động.

