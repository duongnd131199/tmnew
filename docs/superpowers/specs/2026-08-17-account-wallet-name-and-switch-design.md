# Thiết kế map tên ví và chuyển tài khoản EX V2

## Mục tiêu

Mỗi tài khoản liên kết hiển thị đúng tên ví/tài khoản của chính nó và thao tác chạm tài khoản khác phải chuyển toàn bộ dữ liệu sang tài khoản đó sau khi backend trả canonical bootstrap thành công.

## Nguyên nhân đã xác minh

- Flutter đang truyền `active.name` vào `_mapLinkedAccount`, nên các tài khoản không hoạt động bị mất `LinkedTradingAccount.displayName` riêng.
- Trên public ingress, thao tác chạm tài khoản khác đã gọi endpoint activate nhưng nhận HTTP 409 `concurrency_conflict`; correlationId kiểm tra an toàn là `fbc56444-147c-4c67-96cd-a6d131931137`.
- Flutter hiện không giả lập chuyển trạng thái khi activate thất bại. Đây là hành vi đúng vì nếu đổi UI cục bộ thì số dư, ví, lệnh và lịch sử có thể thuộc tài khoản cũ.

## Thiết kế

### Tên ví/tài khoản

- Tài khoản đang hoạt động lấy tên từ `bootstrap.activeAccount.name`.
- Tài khoản chưa hoạt động lấy `LinkedTradingAccount.displayName` của chính tài khoản đó khi có giá trị.
- Chỉ fallback về tên tài khoản đang hoạt động khi backend không cung cấp `displayName`, để không hiển thị `Unavailable` hoặc tên kỹ thuật.
- Tên server trình bày tiếp tục lấy từ presentation store theo `accountId`; `brokerId` và `serverId` kỹ thuật không thay đổi.

### Chuyển tài khoản

- Chạm tài khoản không hoạt động gọi đúng `PUT /mobile/accounts/{accountId}/activate` với body `{}` và metadata UUID của thao tác.
- Backend phải cập nhật active link bằng một transaction nhất quán, không để EF Core tạo xung đột concurrency giữa thao tác bỏ active cũ và bật active mới.
- Response thành công phải chứa account được chọn và bootstrap có cùng `account.id`/`summary.accountId`.
- Flutter chỉ publish bootstrap khi ba định danh khớp. Publication thay thế nguyên tử account, summary, positions, pending orders, deals, wallet và các nhánh dữ liệu account-scoped.
- Sau thành công, danh sách tài khoản được làm mới và màn danh sách đóng về màn trước.
- Nếu backend trả lỗi, tài khoản cũ vẫn active và UI hiển thị `code`/`correlationId` an toàn.

## Phạm vi backend

- Chỉ sửa luồng activate EX V2 và test liên quan.
- Không đổi base URL, auth/device-token contract hoặc API route.
- Không sửa hay restart legacy `ex-api.service`.

## Kiểm thử bắt buộc

- Widget/provider test chứng minh mỗi tài khoản dùng `displayName` riêng.
- Test chạm B gọi activate đúng account ID.
- Test HTTP 200 publish toàn bộ bootstrap B, gồm wallet, positions và history, không còn dữ liệu A.
- Test HTTP 409 giữ A active và hiển thị lỗi an toàn.
- Backend test tái hiện activate A → B không còn `concurrency_conflict`, response bootstrap thuộc B.
- Chạy `flutter analyze`, `flutter test`, build APK đúng flavor hiện tại, build/test backend và smoke test public ingress.

## An toàn

- Không log password, device token, Authorization, request body đầy đủ hoặc reconnectGrant.
- Chỉ ghi nhận method, URL, status, account ID đã che khi cần, correlationId và error code.
