# SECURE LOCAL MESSENGER (E2EE RELAY ARCHITECTURE) - TECHNICAL SPECIFICATION

## 1. Mục tiêu dự án
Xây dựng hệ thống nhắn tin bảo mật nội bộ hoạt động qua mạng LAN/Intranet, không phụ thuộc vào hạ tầng Cloud của bên thứ ba, hỗ trợ đồng thời 5 nền tảng: **Android, iOS, macOS, Windows, và Web (Browser)** bằng Flutter kết hợp một trạm trung chuyển cục bộ (**Local Relay Server**).

### Nguyên tắc bảo mật cốt lõi (Zero-Knowledge Relay)
- **Toàn vẹn đầu cuối (End-to-End Encryption - E2EE):** Nội dung tin nhắn chỉ được mã hóa và giải mã trực tiếp tại thiết bị của người gửi và người nhận.
- **Relay Server trung lập:** Server chỉ làm nhiệm vụ kết nối và định tuyến gói tin (Routing/Relay). Server hoàn toàn **không lưu trữ khóa bí mật**, **không có khóa phiên**, và **không thể đọc nội dung tin nhắn**.

---

## 2. Công nghệ & Thư viện (Tech Stack)

### Client (Flutter)
- **Framework:** Flutter SDK (kênh Stable) hỗ trợ Android, iOS, macOS, Windows, Web.
- **Mật mã học (Cryptography):** Thư viện `cryptography`
  - Thỏa thuận khóa bất đối xứng: **X25519** (Curve25519 ECDH).
  - Dẫn xuất khóa phiên (KDF): **HKDF-HMAC-SHA256**.
  - Mã hóa đối xứng có xác thực (AEAD): **AES-256-GCM** (IV 12-byte ngẫu nhiên, Authentication Tag 16-byte).
  - Bảo vệ khóa cá nhân: Mã hóa Private Key bằng Master PIN qua **PBKDF2-HMAC-SHA256** (100.000 vòng lặp) kết hợp Salt 16-byte.
- **Mạng (Networking):** Package `web_socket_channel` (hỗ trợ WebSocket chuẩn đồng nhất trên cả Web, Mobile và Desktop).
- **Cơ sở dữ liệu cục bộ (Local Storage):**
  - Mobile & Desktop (Android, iOS, macOS, Windows): `sqflite` và `sqflite_common_ffi` (kết hợp `path_provider`).
  - Web: `shared_preferences` / Hive / IndexedDB (được trừu tượng hóa qua Database Repository).
- **Mã QR:** `qr_flutter` (tạo và hiển thị mã QR) và `mobile_scanner` (quét camera trên Android, iOS, macOS/Web).

### Local Relay Server
- **Nền tảng:** Node.js (TypeScript/JavaScript) hoặc Dart thuần (sử dụng thư viện `ws` hoặc `shelf_web_socket`).
- **Nhiệm vụ:** Quản lý kết nối WebSocket thời gian thực, lưu trữ danh sách thiết bị trực tuyến (Online Presence) và hàng đợi tin nhắn ngoại tuyến (Offline Queue).

---

## 3. Quy trình bảo mật & Giao thức dữ liệu (Data Protocol)

### A. Định dạng dữ liệu mã QR danh bạ (Contact QR Payload)
Khi người dùng chia sẻ danh bạ, ứng dụng xuất chuỗi JSON nén:
```json
{
  "v": 1,
  "id": "usr_c3e8b61a-4d20-4e42",
  "name": "Quang Dung",
  "pk": "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA..." 
}

```

*(Trong đó `pk` là chuỗi Base64 của X25519 Public Key).*

### B. Cơ chế bắt tay và mã hóa tin nhắn (E2EE Handshake)

#### 1. Dẫn xuất khóa phiên (Session Key Derivation)

Bên A dùng Private Key của mình ($sk_A$) và Public Key của bên B ($pk_B$) tính toán khóa bí mật chung:


$$\text{Shared Secret} = \text{ECDH}(sk_A, pk_B)$$

Sau đó, đưa Shared Secret qua hàm HKDF để tạo Session Key 32 bytes (256-bit):


$$\text{Session Key} = \text{HKDF-SHA256}(\text{ikm} = \text{Shared Secret}, \text{salt} = \text{"SECURE\_LAN\_SALT"}, \text{info} = \text{"MSG\_CIPHER\_KEY"}, \text{length} = 32)$$

#### 2. Mã hóa tin nhắn bản rõ (Plaintext Encryption)

* Sinh vector khởi tạo ngẫu nhiên bảo đảm tính duy nhất:

$$IV \in \{0, 1\}^{96} \quad (12 \text{ bytes})$$


* Thực hiện mã hóa đối xứng có xác thực:

$$\text{Ciphertext, Tag} = \text{AES-256-GCM-Encrypt}(\text{Plaintext}, \text{Session Key}, IV)$$



#### 3. Đóng gói tin nhắn gửi lên Relay Server (Wire Format)

Dữ liệu gửi qua WebSocket lên Server có cấu trúc JSON như sau:

```json
{
  "type": "MESSAGE_FORWARD",
  "to": "usr_receiver_id",
  "from": "usr_sender_id",
  "timestamp": 1725805200000,
  "payload": {
    "iv": "dGVzdF9pdl8xMmJ5dGVz",
    "ciphertext": "base64_encoded_ciphertext...",
    "tag": "base64_encoded_auth_tag..."
  }
}

```

---

## 4. Kiến trúc Module mã nguồn (Architecture & Modules)

```
lan_secure_messenger/
├── server/                              # Thư mục mã nguồn Local Relay Server
│   ├── package.json
│   └── index.js                         # WebSocket Relay Engine (Node.js)
│
├── lib/
│   ├── core/
│   │   ├── crypto/
│   │   │   ├── crypto_service.dart      # X25519, HKDF, AES-GCM, PBKDF2
│   │   │   └── key_storage.dart         # Lưu khóa bí mật đã mã hóa
│   │   ├── network/
│   │   │   ├── websocket_client.dart    # Quản lý WebSocket, tự động Reconnect
│   │   │   └── protocol_models.dart     # Data Transfer Objects (Payloads)
│   │   └── database/
│   │       ├── database_helper.dart     # Interface lưu trữ DB dùng chung
│   │       ├── native_db.dart           # SQLite FFI cho Mobile/Desktop
│   │       └── web_db.dart              # Lưu trữ cục bộ cho Web
│   │
│   ├── models/
│   │   ├── contact_model.dart           # ID, Tên, Public Key, Status
│   │   └── message_model.dart           # ID, Sender, Receiver, Content, Status
│   │
│   ├── ui/
│   │   ├── screens/
│   │   │   ├── setup_profile_screen.dart # Nhập Tên & Tạo Master PIN sinh khóa
│   │   │   ├── server_connect_screen.dart# Cấu hình IP:Port của Relay Server
│   │   │   ├── chat_list_screen.dart    # Danh sách cuộc trò chuyện
│   │   │   ├── chat_room_screen.dart    # Khung chat bong bóng (Telegram style)
│   │   │   └── qr_contact_screen.dart   # Xem mã QR cá nhân & Quét Camera
│   │   └── widgets/
│   │       ├── chat_bubble.dart         # Widget hiển thị tin nhắn đến/đi
│   │       └── connection_indicator.dart# Trạng thái kết nối Server (Xanh/Đỏ)
│   └── main.dart

```

---

## 5. Thiết kế Cơ sở dữ liệu cục bộ (Local SQLite Schema)

```sql
-- Bảng danh bạ đã lưu
CREATE TABLE contacts (
    id TEXT PRIMARY KEY,            -- User ID đối phương
    display_name TEXT NOT NULL,     -- Tên hiển thị
    public_key TEXT NOT NULL,       -- Chuỗi Base64 của Public Key
    is_online INTEGER DEFAULT 0,    -- 0: Offline, 1: Online
    last_seen DATETIME
);

-- Bảng tin nhắn đã giải mã trên máy
CREATE TABLE messages (
    id TEXT PRIMARY KEY,
    sender_id TEXT NOT NULL,
    receiver_id TEXT NOT NULL,
    content TEXT NOT NULL,          -- Bản rõ hiển thị trên màn hình
    timestamp INTEGER NOT NULL,     -- Unix epoch (milliseconds)
    status TEXT CHECK(status IN ('pending', 'sent', 'delivered', 'read'))
);

-- Bảng thông tin chủ thiết bị
CREATE TABLE my_profile (
    id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    public_key TEXT NOT NULL,
    encrypted_private_key TEXT NOT NULL,
    salt TEXT NOT NULL
);

```

---

## 6. Ràng buộc quyền hệ thống (Platform Entitlements & Permissions)

### 1. Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-feature android:name="android.hardware.camera" android:required="false" />

```

### 2. iOS (`ios/Runner/Info.plist`)

```xml
<key>NSCameraUsageDescription</key>
<string>Ứng dụng cần quyền Camera để quét mã QR kết bạn.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Ứng dụng cần truy cập mạng nội bộ để kết nối tới Local Relay Server.</string>
<key>NSBonjourServices</key>
<array>
    <string>_http._tcp</string>
    <string>_websocket._tcp</string>
</array>

```

### 3. macOS (`macos/Runner/DebugProfile.entitlements` & `Release.entitlements`)

```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
<key>com.apple.security.device.camera</key>
<true/>

```

### 4. Windows (`windows/runner/main.cpp`)

Đảm bảo app không yêu cầu đặc quyền Admin nhưng có quyền kết nối mạng Outbound tới cổng WebSocket của mạng nội bộ.

---

## 7. Các giai đoạn triển khai (Implementation Plan)

* **Giai đoạn 1:** Khởi tạo cấu hình đa nền tảng (`android,ios,macos,windows,web`), cấu hình permissions, dependencies trong `pubspec.yaml`.
* **Giai đoạn 2:** Viết Local Relay Server siêu nhẹ bằng Node.js trong thư mục `server/` (khoảng ~100 dòng code WebSocket).
* **Giai đoạn 3:** Xây dựng module `CryptoService` với X25519, HKDF, AES-GCM và bộ Unit Test đảm bảo 100% test case mã hóa - giải mã đều PASS.
* **Giai đoạn 4:** Xây dựng `WebSocketClient` xử lý truyền nhận gói tin JSON và cơ chế tự động kết nối lại khi mất mạng.
* **Giai đoạn 5:** Dựng giao diện người dùng phong cách Telegram/Zalo: Màn hình kích hoạt hồ sơ/PIN, danh sách chat, khung chat bong bóng và quét mã QR danh bạ.

```

```