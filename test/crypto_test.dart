import 'package:flutter_test/flutter_test.dart';
import 'package:lan_secure_messenger/core/crypto/crypto_service.dart';

void main() {
  final crypto = CryptoService();

  test('generates and imports/exports an X25519 public key', () async {
    final keyPair = await crypto.generateKeyPair();
    final publicKey = await keyPair.extractPublicKey();

    final encoded = crypto.exportPublicKey(publicKey);
    final imported = crypto.importPublicKey(encoded);

    expect(encoded, isNotEmpty);
    expect(imported, equals(publicKey));
  });

  test('derives the same session key on both sides of ECDH', () async {
    final aliceKeyPair = await crypto.generateKeyPair();
    final bobKeyPair = await crypto.generateKeyPair();
    final alicePublicKey = await aliceKeyPair.extractPublicKey();
    final bobPublicKey = await bobKeyPair.extractPublicKey();

    final aliceSessionKey = await crypto.deriveSessionKey(
      localKeyPair: aliceKeyPair,
      remotePublicKey: bobPublicKey,
    );
    final bobSessionKey = await crypto.deriveSessionKey(
      localKeyPair: bobKeyPair,
      remotePublicKey: alicePublicKey,
    );

    expect(
      await aliceSessionKey.extractBytes(),
      equals(await bobSessionKey.extractBytes()),
    );
  });

  test('encrypts at A and decrypts successfully at B', () async {
    final aliceKeyPair = await crypto.generateKeyPair();
    final bobKeyPair = await crypto.generateKeyPair();
    final bobPublicKey = await bobKeyPair.extractPublicKey();
    final alicePublicKey = await aliceKeyPair.extractPublicKey();
    final aliceSessionKey = await crypto.deriveSessionKey(
      localKeyPair: aliceKeyPair,
      remotePublicKey: bobPublicKey,
    );
    final bobSessionKey = await crypto.deriveSessionKey(
      localKeyPair: bobKeyPair,
      remotePublicKey: alicePublicKey,
    );

    final encrypted = await crypto.encryptMessage(
      'Tin nhan LAN bao mat',
      aliceSessionKey,
    );
    final decrypted = await crypto.decryptMessage(
      ciphertext: encrypted.ciphertext,
      iv: encrypted.iv,
      authTag: encrypted.authTag,
      sessionKey: bobSessionKey,
    );

    expect(encrypted.iv, isNotEmpty);
    expect(encrypted.authTag, isNotEmpty);
    expect(decrypted, 'Tin nhan LAN bao mat');
  });

  test('encrypts and restores a private key with a master PIN', () async {
    final keyPair = await crypto.generateKeyPair();
    const masterPin = '246810';

    final encrypted = await crypto.encryptPrivateKey(keyPair, masterPin);
    final restored = await crypto.decryptPrivateKey(encrypted, masterPin);

    expect(
      await restored.extractPrivateKeyBytes(),
      equals(await keyPair.extractPrivateKeyBytes()),
    );
    expect(
      await restored.extractPublicKey(),
      equals(await keyPair.extractPublicKey()),
    );
  });
}