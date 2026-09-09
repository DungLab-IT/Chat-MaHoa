# Chạy local trên Mac và deploy Relay lên VPS

Tài liệu này hướng dẫn kiểm thử thực tế và đưa **Node.js Local Relay Server** lên VPS thông qua GitHub. Flutter Client vẫn được build riêng cho macOS, Web, Android hoặc iOS.

## 1. Điều kiện cần

### Trên Mac

```bash
flutter doctor
node --version
npm --version
flutter devices
```

Cần có Flutter stable, Node.js/npm và Chrome. Android Studio/Xcode chỉ cần khi chạy đúng nền tảng đó.

### Trên VPS

- Ubuntu/Debian hiện đại.
- SSH access.
- Node.js LTS và npm.
- Git.
- Firewall có thể mở TCP port `48485`.
- GitHub repository đã được tạo.

## 2. Test toàn bộ project trên Mac

Từ thư mục project:

```bash
cd /Volumes/KIOXIA_G2/Projects/ATBM
flutter pub get
flutter analyze
flutter test
flutter build web --no-tree-shake-icons
```

Các lệnh trên kiểm tra dependencies, analyzer, crypto/database/chat pipeline và build Web.

## 3. Chạy Relay Server local

Mở terminal riêng:

```bash
cd /Volumes/KIOXIA_G2/Projects/ATBM/server
npm install
node --check index.js
npm start
```

Kết quả mong đợi:

```text
LAN Secure Messenger relay listening on ws://0.0.0.0:48485
```

Kiểm tra port ở terminal khác:

```bash
lsof -nP -iTCP:48485 -sTCP:LISTEN
```

Dừng server:

```text
Ctrl+C
```

### IP Wi-Fi của Mac

```bash
ipconfig getifaddr en0
```

Nếu không có kết quả:

```bash
ifconfig
```

Client chạy cùng Mac dùng:

```text
ws://localhost:48485
```

Thiết bị khác trong cùng Wi-Fi dùng:

```text
ws://<IP_MAC>:48485
```

Ví dụ `ws://192.168.1.42:48485`.

## 4. Chạy nhiều client local

Mỗi lệnh nên chạy trong một terminal riêng.

### macOS

```bash
cd /Volumes/KIOXIA_G2/Projects/ATBM
flutter run -d macos
```

### Chrome Web

```bash
cd /Volumes/KIOXIA_G2/Projects/ATBM
flutter run -d chrome
```

### Android

```bash
cd /Volumes/KIOXIA_G2/Projects/ATBM
flutter devices
flutter run -d <android-device-id>
```

Android Emulator thường dùng `ws://10.0.2.2:48485` để trỏ về Mac host. Điện thoại thật dùng IP Wi-Fi của Mac.

Sau khi unlock Master PIN, client tự kết nối relay. Nếu relay chưa chạy, UI hiển thị `Reconnecting` và tự thử lại mỗi 3 giây.

## 5. Kiểm thử kết bạn và E2EE

1. Chạy relay.
2. Mở Client 1 và Client 2.
3. Tạo profile riêng cho mỗi client.
4. Ở Client 1 mở **Danh bạ & QR** rồi sao chép payload hoặc hiển thị QR.
5. Ở Client 2 mở **Thêm liên hệ**, quét QR hoặc dán JSON/Base64.
6. Lặp lại chiều ngược lại để hai client có Public Key của nhau.
7. Mở phòng chat và gửi plaintext từ Client 1.
8. Xác nhận Client 1 lưu trạng thái `sent`, Client 2 giải mã và hiển thị trạng thái `delivered`.
9. Kiểm tra relay chỉ log sender/receiver, kích thước và tên field `iv,ciphertext,tag`, không log plaintext.

## 6. Đẩy project lên GitHub

Tại thư mục root:

```bash
cd /Volumes/KIOXIA_G2/Projects/ATBM
git init
git add .
git status
git commit -m "Initial secure LAN messenger"
git branch -M main
git remote add origin git@github.com:<GITHUB_USER>/<REPOSITORY>.git
git push -u origin main
```

Nếu remote đã tồn tại:

```bash
git remote -v
git add .
git commit -m "Update relay and client"
git push origin main
```

Khuyến nghị dùng SSH key GitHub. Không commit:

- Master PIN.
- Private Key.
- Database chứa dữ liệu thật.
- `.env`, token hoặc password VPS.
- `node_modules/` và build artifacts.

Kiểm tra trước khi push:

```bash
git status --short
git diff --cached --check
```

## 7. Cài Relay từ GitHub lên VPS

SSH vào VPS:

```bash
ssh <VPS_USER>@<VPS_IP>
```

Cài Git/Node.js nếu VPS chưa có:

```bash
sudo apt update
sudo apt install -y git curl
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs
node --version
npm --version
```

Clone repository:

```bash
cd /opt
sudo git clone git@github.com:<GITHUB_USER>/<REPOSITORY>.git lan-secure-messenger
sudo chown -R "$USER":"$USER" /opt/lan-secure-messenger
cd /opt/lan-secure-messenger/server
npm ci --omit=dev
node --check index.js
```

Nếu repository private, VPS cần SSH deploy key hoặc GitHub token phù hợp. Không ghi token trực tiếp vào shell history.

## 8. Mở firewall VPS

Với UFW:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 48485/tcp
sudo ufw enable
sudo ufw status
```

Nếu VPS provider có firewall/security group riêng, mở TCP `48485` ở đó nữa.

Kiểm tra relay chỉ bind đúng port:

```bash
sudo ss -lntp | grep 48485
```

## 9. Chạy relay bền vững bằng PM2

Cài PM2:

```bash
sudo npm install -g pm2
```

Khởi động relay:

```bash
cd /opt/lan-secure-messenger/server
pm2 start index.js --name lan-secure-relay
pm2 status
pm2 logs lan-secure-relay
```

Cho PM2 tự khởi động sau reboot:

```bash
pm2 save
pm2 startup
```

Chạy lệnh `pm2 startup` được in ra bởi terminal với quyền `sudo` nếu PM2 yêu cầu.

Cập nhật code từ GitHub:

```bash
cd /opt/lan-secure-messenger
git pull --ff-only origin main
cd server
npm ci --omit=dev
pm2 restart lan-secure-relay
pm2 logs lan-secure-relay --lines 50
```

## 10. Trỏ Flutter Client tới VPS

Trong màn hình cấu hình server của app, nhập:

```text
ws://<VPS_IP>:48485
```

Nếu dùng domain và reverse proxy TLS:

```text
wss://relay.example.com
```

URL cuối cùng được lưu cục bộ và app sẽ tự dùng lại ở lần mở sau.

## 11. Khuyến nghị production

Cổng WebSocket raw `ws://` phù hợp cho test LAN hoặc mạng tin cậy. Khi đưa relay lên VPS Internet:

1. Dùng Nginx/Caddy reverse proxy.
2. Cấp TLS và dùng `wss://`.
3. Chỉ mở port `80/443`, hạn chế expose trực tiếp `48485` nếu proxy cùng máy.
4. Giới hạn Origin bằng biến `ALLOWED_ORIGINS`.
5. Thêm authentication client và rate limit trước khi public.
6. Giám sát log, CPU, RAM và dung lượng queue.

Ví dụ allowlist Origin:

```bash
ALLOWED_ORIGINS=https://app.example.com npm start
```

Không coi relay hiện tại là production Internet server nếu chưa có authentication và TLS.
