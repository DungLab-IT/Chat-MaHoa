# Lan Secure Messenger

Ứng dụng nhắn tin E2EE trong mạng LAN, chạy trên Android, iOS, macOS, Windows và Web. Local Relay Server chỉ định tuyến payload WebSocket; việc mã hóa và giải mã diễn ra ở hai client.

## Giai đoạn 7: Vận hành và kiểm thử thực tế

### 1. Chuẩn bị môi trường trên Mac

Cần có:

- Flutter SDK stable
- Node.js và npm
- Xcode nếu chạy macOS/iOS
- Android Studio và một thiết bị/Android Emulator nếu chạy Android
- Chrome nếu chạy Flutter Web

Kiểm tra nhanh:

```bash
flutter doctor
node --version
npm --version
flutter devices
```

### 2. Chạy Local Relay Server

Mở một cửa sổ terminal riêng tại thư mục project:

```bash
cd /Volumes/KIOXIA_G2/Projects/ATBM/server
npm install
npm start
```

Server mặc định lắng nghe trên mọi interface tại cổng `48485`:

```text
LAN Secure Messenger relay listening on ws://0.0.0.0:48485
```

Giữ cửa sổ terminal này mở trong suốt quá trình kiểm thử. Dừng server bằng `Ctrl+C`.

#### Xem IP Wi-Fi nội bộ của Mac

Cách nhanh với Wi-Fi thường dùng trên macOS:

```bash
ipconfig getifaddr en0
```

Nếu lệnh trên không trả về địa chỉ, xem tất cả interface:

```bash
ifconfig
```

Tìm interface đang có dòng `inet 192.168.x.x` hoặc `inet 10.x.x.x`, thường là `en0` hoặc `en1`. Ví dụ Mac có IP `192.168.1.42`, các thiết bị khác trong cùng Wi-Fi dùng:

```text
ws://192.168.1.42:48485
```

Không dùng `ws://localhost:48485` trên điện thoại hoặc máy khác: `localhost` khi đó trỏ về chính thiết bị đang chạy client. `localhost` chỉ phù hợp khi client và relay cùng chạy trên Mac.

Nếu macOS hỏi quyền Firewall cho Node, chọn **Allow**. Router hoặc firewall nội bộ cũng phải cho phép TCP inbound tới cổng `48485`.

### 3. Chạy nhiều client từ Mac

Mỗi client nên chạy trong một cửa sổ terminal riêng.

#### Client 1: macOS Desktop

```bash
flutter run -d macos
```

Trong màn hình cấu hình server, dùng:

```text
ws://localhost:48485
```

#### Client 2: Chrome Web

```bash
flutter run -d chrome
```

Dùng `ws://localhost:48485` nếu Chrome chạy cùng Mac. Nếu mở ứng dụng Web từ một máy khác, dùng IP LAN của Mac:

```text
ws://<IP_MAC_WIFI>:48485
```

Web/Desktop không bắt buộc phải dùng camera: màn hình QR có ô dán payload thủ công.

#### Client 3: Android Emulator hoặc điện thoại

Liệt kê thiết bị trước:

```bash
flutter devices
```

Sau đó chạy bằng device ID thực tế:

```bash
flutter run -d <android-device-id>
```

Ví dụ:

```bash
flutter run -d emulator-5554
```

Trên Android Emulator, `10.0.2.2` thường trỏ về máy host, vì vậy có thể thử:

```text
ws://10.0.2.2:48485
```

Trên điện thoại thật, dùng IP Wi-Fi của Mac:

```text
ws://<IP_MAC_WIFI>:48485
```

Điện thoại và Mac phải nằm trong cùng mạng LAN. Android đã được khai báo quyền Internet và camera trong manifest.

### 4. Kịch bản kiểm thử kết bạn

1. Khởi động relay server và giữ terminal server mở.
2. Mở Client 1, tạo profile bằng tên hiển thị và Master PIN 6 chữ số.
3. Mở màn hình **Danh bạ & QR**.
4. Ở Client 2, mở màn hình **Thêm liên hệ**.
5. Quét QR của Client 1 bằng camera nếu thiết bị hỗ trợ.
6. Nếu đang dùng Chrome/Desktop, nhấn sao chép payload ở Client 1 rồi dán chuỗi JSON vào ô payload của Client 2.
7. Nhấn **Thêm vào danh bạ** và kiểm tra Client 1 xuất hiện trong danh sách liên hệ.
8. Lặp lại theo chiều ngược lại nếu cần để hai client đều lưu Public Key của nhau.

Payload QR có dạng tương tự:

```json
{
  "v": 1,
  "id": "usr_...",
  "name": "Alice",
  "pk": "base64_x25519_public_key"
}
```

Chỉ Public Key và thông tin nhận dạng được chia sẻ. Không chia sẻ Master PIN hoặc Private Key.

### 5. Kịch bản kiểm thử tin nhắn E2EE

1. Đảm bảo Client 1 và Client 2 cùng trỏ tới relay server và đều hiển thị trạng thái kết nối.
2. Từ Client 1, mở cuộc trò chuyện với Client 2.
3. Gửi một bản rõ dễ nhận biết, ví dụ:

```text
Tin nhắn kiểm thử E2EE Alice -> Bob
```

4. Kiểm tra Client 1 hiển thị bong bóng tin gửi bên phải với trạng thái đã gửi.
5. Kiểm tra Client 2 nhận được cùng nội dung ở bong bóng bên trái.
6. Kiểm tra database cục bộ của Client 2 chỉ lưu bản rõ sau khi client giải mã thành công.
7. Đóng Client 2, gửi thêm một tin từ Client 1, sau đó mở/kết nối lại Client 2 để kiểm tra offline queue được relay giao lại.

### 6. Kiểm tra log zero-knowledge của relay

Trong terminal chạy `npm start`, log hợp lệ sẽ có dạng:

```text
[CONNECT] client connected
[REGISTER] usr_alice connected (1 online)
[REGISTER] usr_bob connected (2 online)
[FORWARD] usr_alice -> usr_bob (92 bytes, fields: iv,ciphertext,tag)
```

Nếu Client nhận đang offline:

```text
[QUEUE] usr_alice -> usr_bob (92 bytes, fields: iv,ciphertext,tag, 1 pending)
[QUEUE] delivered 1 message(s) to usr_bob
```

Các log cần xác nhận:

- Có `sender`, `receiver`, số byte và tên trường `iv,ciphertext,tag`.
- Không có bản rõ như `Tin nhắn kiểm thử E2EE Alice -> Bob`.
- Không có Private Key hoặc Session Key.
- Relay chỉ giữ payload trong RAM khi phải queue offline.

Relay hiện cố ý không in giá trị `iv`, `ciphertext` hoặc `tag` ra terminal. Điều này tránh biến log thành nơi rò rỉ dữ liệu; việc nhìn thấy tên trường và kích thước payload cùng với bản rõ chỉ xuất hiện ở hai client là tiêu chí kiểm thử zero-knowledge phù hợp.

### 7. Kiểm tra tự động

Tại thư mục project:

```bash
flutter pub get
flutter analyze
flutter test
flutter build web --no-tree-shake-icons
```

Tại thư mục relay:

```bash
cd server
npm install
node --check index.js
npm start
```

Nếu `flutter analyze` và `flutter test` đều thành công, tầng Crypto, Database, WebSocket và UI đã vượt qua kiểm tra hồi quy cơ bản.

## Kiến trúc bảo mật

- X25519 tạo shared secret giữa hai client.
- HKDF-HMAC-SHA256 dẫn xuất Session Key.
- AES-256-GCM mã hóa nội dung với IV 12 byte và authentication tag.
- Relay Node.js không có khóa để giải mã và không đọc nội dung message.
- Private Key được lưu cục bộ dưới dạng mã hóa bằng Master PIN.
