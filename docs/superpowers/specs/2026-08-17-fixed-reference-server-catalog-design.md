# Thiết kế catalog máy chủ cố định theo video

## Mục tiêu

Màn hình chọn máy chủ của broker `yodo-demo` hiển thị đúng tên, thứ tự, nhịp hàng và selected state trong frame 14–16 của `giaoDienMau/themmoitk.MP4`. Yêu cầu này chủ động thay thế quy tắc tên server động trước đó, nhưng không được làm request gửi server ID giả.

## Bằng chứng từ video

Frame 14 hiển thị từ đầu catalog; frame 16 hiển thị phần catalog sau khi cuộn. Thứ tự quan sát được:

1. `Exness-MT5Real20`
2. `Exness-MT5Real17`
3. `Exness-MT5Real32`
4. `Exness-MT5Trial5`
5. `Exness-MT5Real2`
6. `Exness-MT5Real11`
7. `Exness-MT5Real38`
8. `Exness-MT5Trial`
9. `Exness-MT5Real27`
10. `Exness-MT5Real4`
11. `Exness-MT5Trial2`
12. `Exness-MT5Real18`
13. `Exness-MT5Real25`
14. `Exness-MT5Real43`
15. `Exness-MT5Real35`
16. `Exness-MT5Real28`
17. `Exness-MT5Trial14`
18. `Exness-MT5Real21`
19. `Exness-MT5Real15`
20. `Exness-MT5Real19`
21. `Exness-MT5Trial15`
22. `Exness-MT5Real31`
23. `Exness-MT5Real39`
24. `Exness-MT5Real24`

## Phương án đã xem xét

1. **Khuyến nghị: catalog trình bày cố định, alias trên server thật.** UI dùng 24 tên video; mỗi alias sao chép `id`, `brokerId`, account type và description từ server API thật. Request vì vậy vẫn gửi ID hợp lệ.
2. Thay hoàn toàn API catalog bằng 24 `MobileTradingServer` có ID Exness giả. Giao diện giống video nhưng link account sẽ lỗi vì backend không có các ID này.
3. Sửa backend để tạo 24 server Exness. Vượt phạm vi Flutter và không cần thiết cho yêu cầu giao diện.

Chọn phương án 1.

## Kiến trúc

Tạo `reference_server_catalog.dart` trong presentation widgets. File này chỉ chứa:

- danh sách 24 display name bất biến;
- hàm `referenceServerOptions` nhận catalog API và trả về alias có tên video;
- hàm `referenceDefaultServer` tạo alias hàng đầu cho form;
- hàm selected-state nhận biết alias đang chọn và fallback hàng đầu khi controller còn giữ tên API.

Chỉ áp dụng alias khi `brokerId == 'yodo-demo'` và API trả ít nhất một server. Broker khác tiếp tục hiển thị catalog API bình thường. Nếu API loading, empty hoặc error thì UI giữ đúng trạng thái đó, không tự sinh server.

## Dữ liệu và selection

- Mỗi hàng alias có key duy nhất theo index, không dùng một ID lặp lại làm key.
- Hàng đầu `Exness-MT5Real20` được check mặc định.
- Khi tap một alias, controller nhận `MobileTradingServer` có display name đó nhưng ID/brokerId thật.
- Form hiển thị alias đã chọn.
- `AccountLinkController.submit()` không đổi; request lấy `selectedServer.id`, do đó vẫn gửi `yodo-demo-01`.

## Hình học và style

- Giữ `server-list.top == 124` logical px sau SafeArea, tương đương `y=222` trên LDPlayer.
- Giữ row pitch 56 logical px, divider inset 16, checkmark primary, surface và typography hiện tại.
- Danh sách cuộn bằng `BouncingScrollPhysics`; scrollbar hiển thị theo nội dung dài giống video.

## Test và nghiệm thu

- Test RED xác nhận đủ 24 tên theo đúng thứ tự; trước fix catalog YODO chỉ có `YODO-Demo-01` nên phải fail.
- Test selected state chỉ có một checkmark ở `Exness-MT5Real20` lúc mở.
- Test tap `Exness-MT5Real17` trả về name alias nhưng `id == 'yodo-demo-01'` và `brokerId == 'yodo-demo'`.
- Test controller/request hiện có tiếp tục xác nhận JSON gửi `serverId: yodo-demo-01`.
- Chạy analyze, full Flutter tests, APK build, backend build/test và chụp LDPlayer tại đầu danh sách và sau khi cuộn.
- Không nhập password và không log credential trong smoke UI.
