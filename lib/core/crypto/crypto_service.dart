import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class EncryptedMessage {
  const EncryptedMessage({
    required this.ciphertext,
    required this.iv,
    required this.authTag,
  });

  final String ciphertext;
  final String iv;
  final String authTag;

  Map<String, String> toJson() => {
        'ciphertext': ciphertext,
        'iv': iv,
        'tag': authTag,
      };
}

class EncryptedPrivateKey {
  const EncryptedPrivateKey({
    required this.publicKey,
    required this.salt,
    required this.iv,
    required this.ciphertext,
    required this.authTag,
  });

  final String publicKey;
  final String salt;
  final String iv;
  final String ciphertext;
  final String authTag;

  Map<String, String> toJson() => {
        'public_key': publicKey,
        'salt': salt,
        'iv': iv,
        'ciphertext': ciphertext,
        'tag': authTag,
      };

  factory EncryptedPrivateKey.fromJson(Map<String, dynamic> json) {
    return EncryptedPrivateKey(
      publicKey: json['public_key'] as String,
      salt: json['salt'] as String,
      iv: json['iv'] as String,
      ciphertext: json['ciphertext'] as String,
      authTag: (json['tag'] ?? json['auth_tag']) as String,
    );
  }
}

class CryptoService {
  static final X25519 _x25519 = X25519();
  static final AesGcm _aesGcm = AesGcm.with256bits();
  static final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 120000,
    bits: 256,
  );
  static final Hkdf _hkdf = Hkdf(
    hmac: Hmac.sha256(),
    outputLength: 32,
  );

  Future<SimpleKeyPair> generateKeyPair() => _x25519.newKeyPair();

  String exportPublicKey(SimplePublicKey publicKey) {
    return base64Encode(publicKey.bytes);
  }

  SimplePublicKey importPublicKey(String encodedPublicKey) {
    return SimplePublicKey(
      base64Decode(encodedPublicKey),
      type: KeyPairType.x25519,
    );
  }

  Future<EncryptedPrivateKey> encryptPrivateKey(
    SimpleKeyPair keyPair,
    String masterPin,
  ) async {
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    final salt = await _randomBytes(16);
    final iv = await _randomBytes(_aesGcm.nonceLength);
    final wrappingKey = await _pbkdf2.deriveKeyFromPassword(
      password: masterPin,
      nonce: salt,
    );
    final secretBox = await _aesGcm.encrypt(
      privateKeyBytes,
      secretKey: wrappingKey,
      nonce: iv,
    );

    return EncryptedPrivateKey(
      publicKey: exportPublicKey(publicKey),
      salt: base64Encode(salt),
      iv: base64Encode(secretBox.nonce),
      ciphertext: base64Encode(secretBox.cipherText),
      authTag: base64Encode(secretBox.mac.bytes),
    );
  }

  Future<SimpleKeyPair> decryptPrivateKey(
    EncryptedPrivateKey encrypted,
    String masterPin,
  ) async {
    final salt = base64Decode(encrypted.salt);
    final wrappingKey = await _pbkdf2.deriveKeyFromPassword(
      password: masterPin,
      nonce: salt,
    );
    final secretBox = SecretBox(
      base64Decode(encrypted.ciphertext),
      nonce: base64Decode(encrypted.iv),
      mac: Mac(base64Decode(encrypted.authTag)),
    );
    final privateKeyBytes = await _aesGcm.decrypt(
      secretBox,
      secretKey: wrappingKey,
    );

    return SimpleKeyPairData(
      privateKeyBytes,
      publicKey: importPublicKey(encrypted.publicKey),
      type: KeyPairType.x25519,
    );
  }

  Future<SecretKey> deriveSessionKey({
    required SimpleKeyPair localKeyPair,
    required SimplePublicKey remotePublicKey,
  }) async {
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: localKeyPair,
      remotePublicKey: remotePublicKey,
    );
    return _hkdf.deriveKey(
      secretKey: sharedSecret,
      info: utf8.encode('lan-secure-messenger-session-key'),
    );
  }

  Future<EncryptedMessage> encryptMessage(
    String plainText,
    SecretKey sessionKey,
  ) async {
    final iv = await _randomBytes(_aesGcm.nonceLength);
    final secretBox = await _aesGcm.encrypt(
      utf8.encode(plainText),
      secretKey: sessionKey,
      nonce: iv,
    );
    return EncryptedMessage(
      ciphertext: base64Encode(secretBox.cipherText),
      iv: base64Encode(secretBox.nonce),
      authTag: base64Encode(secretBox.mac.bytes),
    );
  }

  Future<String> decryptMessage({
    required String ciphertext,
    required String iv,
    required String authTag,
    required SecretKey sessionKey,
  }) async {
    final secretBox = SecretBox(
      base64Decode(ciphertext),
      nonce: base64Decode(iv),
      mac: Mac(base64Decode(authTag)),
    );
    final clearText = await _aesGcm.decrypt(
      secretBox,
      secretKey: sessionKey,
    );
    return utf8.decode(clearText);
  }

  Future<List<int>> _randomBytes(int length) async {
    return (await SecretKeyData.random(length: length).extractBytes());
  }
}