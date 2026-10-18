import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';

class MeshCryptoEngine {
  static final X25519 _x25519 = X25519();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static final AesGcm _aesGcm = AesGcm.with256bits();

  SimpleKeyPair? _localKeyPair;
  SimplePublicKey? _localPublicKey;
  final Map<String, SecretKey> _peerSessionKeys = {};
  final Map<String, String> _peerFingerprints = {};

  Future<void> init() async {
    _localKeyPair = await _x25519.newKeyPair();
    _localPublicKey = await _localKeyPair!.extractPublicKey();
  }

  Uint8List getLocalPublicKeyBytes() {
    return Uint8List.fromList(_localPublicKey?.bytes ?? []);
  }

  String getLocalPublicKeyBase64() {
    return base64Encode(getLocalPublicKeyBytes());
  }

  Future<String> getLocalFingerprint() async {
    final bytes = _localPublicKey?.bytes ?? [];
    if (bytes.isEmpty) return "----";
    final hash = await Sha256().hash(bytes);
    return hash.bytes.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }

  Future<bool> establishPeerSession(String peerId, Uint8List remoteKeyBytes) async {
    if (_localKeyPair == null) await init();
    try {
      final remotePubKey = SimplePublicKey(remoteKeyBytes, type: KeyPairType.x25519);
      final sharedSecret = await _x25519.sharedSecretKey(
        keyPair: _localKeyPair!,
        remotePublicKey: remotePubKey,
      );
      final sessionKey = await _hkdf.deriveKey(
        secretKey: sharedSecret,
        info: utf8.encode("NoInternet-E2EE-v1"),
      );
      _peerSessionKeys[peerId] = sessionKey;

      final hash = await Sha256().hash(remoteKeyBytes);
      _peerFingerprints[peerId] = hash.bytes.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
      return true;
    } catch (e) {
      return false;
    }
  }

  bool hasSession(String peerId) => _peerSessionKeys.containsKey(peerId);

  String? getPeerFingerprint(String peerId) => _peerFingerprints[peerId];

  Future<Uint8List?> encryptBytes(String peerId, Uint8List plainBytes) async {
    final sessionKey = _peerSessionKeys[peerId];
    if (sessionKey == null) return null;
    try {
      final box = await _aesGcm.encrypt(plainBytes, secretKey: sessionKey);
      return Uint8List.fromList(box.concatenation());
    } finally {
      plainBytes.fillRange(0, plainBytes.length, 0);
    }
  }

  Future<Uint8List?> decryptBytes(String peerId, Uint8List cipherConcatenated) async {
    final sessionKey = _peerSessionKeys[peerId];
    if (sessionKey == null) return null;
    try {
      final box = SecretBox.fromConcatenation(
        cipherConcatenated,
        nonceLength: 12,
        macLength: 16,
      );
      final decrypted = await _aesGcm.decrypt(box, secretKey: sessionKey);
      return Uint8List.fromList(decrypted);
    } catch (e) {
      return null;
    }
  }

  Future<File?> encryptFile(String peerId, File inputFile, String outputPath) async {
    final sessionKey = _peerSessionKeys[peerId];
    if (sessionKey == null) return null;
    try {
      if (!inputFile.existsSync()) return null;
      final fileLength = await inputFile.length();

      final outputFile = File(outputPath);
      if (!outputFile.parent.existsSync()) {
        outputFile.parent.createSync(recursive: true);
      }

      // Fast single-pass path for files up to 1MB (covers all typical photos / GIFs)
      if (fileLength < 1024 * 1024) {
        final plainBytes = await inputFile.readAsBytes();
        final box = await _aesGcm.encrypt(plainBytes, secretKey: sessionKey);
        final cipherBytes = box.concatenation();

        final sink = outputFile.openWrite();
        try {
          sink.add([0x4D, 0x31]); // "M1" header
          sink.add(cipherBytes);
          await sink.flush();
        } finally {
          await sink.close();
        }
        return outputFile;
      }

      // High-performance bounded streaming chunked path for large files / videos (1MB chunk size)
      const chunkSize = 1024 * 1024; // 1 MB chunks
      final sink = outputFile.openWrite();
      sink.add([0x4D, 0x32]); // "M2" header for streaming chunks

      try {
        final inputStream = inputFile.openRead();
        final builder = BytesBuilder(copy: false);

        await for (final data in inputStream) {
          builder.add(data);
          while (builder.length >= chunkSize) {
            final fullBytes = builder.takeBytes();
            final chunk = Uint8List.sublistView(fullBytes, 0, chunkSize);
            if (fullBytes.length > chunkSize) {
              builder.add(Uint8List.sublistView(fullBytes, chunkSize));
            }

            final box = await _aesGcm.encrypt(chunk, secretKey: sessionKey);
            final chunkCipher = box.concatenation();

            final lenBytes = Uint8List(4)
              ..buffer.asByteData().setUint32(0, chunkCipher.length, Endian.big);
            sink.add(lenBytes);
            sink.add(chunkCipher);
          }
        }

        if (builder.isNotEmpty) {
          final remaining = builder.takeBytes();
          final box = await _aesGcm.encrypt(remaining, secretKey: sessionKey);
          final chunkCipher = box.concatenation();
          final lenBytes = Uint8List(4)
            ..buffer.asByteData().setUint32(0, chunkCipher.length, Endian.big);
          sink.add(lenBytes);
          sink.add(chunkCipher);
        }

        await sink.flush();
      } finally {
        await sink.close();
      }
      return outputFile;
    } catch (e) {
      return null;
    }
  }

  Future<File?> decryptFile(String peerId, File cipherFile, String outputPath) async {
    final sessionKey = _peerSessionKeys[peerId];
    if (sessionKey == null) return null;
    try {
      if (!cipherFile.existsSync()) return null;
      final fileLength = await cipherFile.length();
      if (fileLength < 2) return null;

      final outputFile = File(outputPath);
      if (!outputFile.parent.existsSync()) {
        outputFile.parent.createSync(recursive: true);
      }

      final raf = await cipherFile.open(mode: FileMode.read);
      try {
        final header = await raf.read(2);

        if (header.length == 2 && header[0] == 0x4D && header[1] == 0x32) {
          // Chunked stream format "M2"
          final outSink = outputFile.openWrite();
          try {
            while (await raf.position() < fileLength) {
              final lenBytes = await raf.read(4);
              if (lenBytes.length < 4) break;
              final chunkLen = ByteData.sublistView(lenBytes).getUint32(0, Endian.big);

              final chunkCipher = await raf.read(chunkLen);
              if (chunkCipher.length < chunkLen) break;

              final box = SecretBox.fromConcatenation(
                chunkCipher,
                nonceLength: 12,
                macLength: 16,
              );
              final decryptedChunk = await _aesGcm.decrypt(box, secretKey: sessionKey);
              outSink.add(decryptedChunk);
            }
            await outSink.flush();
          } finally {
            await outSink.close();
          }
          return outputFile;
        } else {
          // "M1" or legacy raw single box format
          await raf.setPosition(0);
          var allBytes = await raf.read(fileLength);

          if (allBytes.length >= 2 && allBytes[0] == 0x4D && allBytes[1] == 0x31) {
            allBytes = Uint8List.sublistView(allBytes, 2);
          }

          final box = SecretBox.fromConcatenation(
            allBytes,
            nonceLength: 12,
            macLength: 16,
          );
          final decryptedBytes = await _aesGcm.decrypt(box, secretKey: sessionKey);
          await outputFile.writeAsBytes(decryptedBytes, flush: true);
          return outputFile;
        }
      } finally {
        await raf.close();
      }
    } catch (e) {
      return null;
    }
  }

  void removePeer(String peerId) {
    _peerSessionKeys.remove(peerId);
    _peerFingerprints.remove(peerId);
  }

  void destroyAll() {
    _peerSessionKeys.clear();
    _peerFingerprints.clear();
    _localKeyPair = null;
    _localPublicKey = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MeshCryptoEngine full test with photo and video transmission', () async {
    final nodeA = MeshCryptoEngine();
    final nodeB = MeshCryptoEngine();

    await nodeA.init();
    await nodeB.init();

    final pubA = nodeA.getLocalPublicKeyBytes();
    final pubB = nodeB.getLocalPublicKeyBytes();

    expect(await nodeA.establishPeerSession('nodeB', pubB), isTrue);
    expect(await nodeB.establishPeerSession('nodeA', pubA), isTrue);

    // 1. Text transmission
    const message = "Top secret mesh message 🛡️";
    final plainBytes = Uint8List.fromList(utf8.encode(message));
    final encrypted = await nodeA.encryptBytes('nodeB', plainBytes);
    expect(encrypted, isNotNull);

    final decryptedBytes = await nodeB.decryptBytes('nodeA', encrypted!);
    expect(decryptedBytes, isNotNull);
    final decryptedText = utf8.decode(decryptedBytes!);
    expect(decryptedText, equals(message));

    // 2. Photo transmission simulation (500 KB JPEG image)
    final tempDir = Directory.systemTemp.createTempSync('mesh_test_');
    final photoFile = File('${tempDir.path}/camera_photo.jpg');
    final photoData = Uint8List(512 * 1024); // 512 KB
    for (int i = 0; i < photoData.length; i++) {
      photoData[i] = (i * 7) % 256;
    }
    await photoFile.writeAsBytes(photoData);

    final encryptedPhoto = await nodeA.encryptFile('nodeB', photoFile, '${tempDir.path}/photo.enc');
    expect(encryptedPhoto, isNotNull);
    expect(encryptedPhoto!.existsSync(), isTrue);

    final decryptedPhoto = await nodeB.decryptFile('nodeA', encryptedPhoto, '${tempDir.path}/decrypted_photo.jpg');
    expect(decryptedPhoto, isNotNull);
    expect(decryptedPhoto!.existsSync(), isTrue);
    expect(await decryptedPhoto.length(), equals(512 * 1024));
    expect(await decryptedPhoto.readAsBytes(), equals(photoData));

    // 3. Large Video transmission simulation (2.5 MB video stream test)
    final videoFile = File('${tempDir.path}/reel_video.mp4');
    final videoData = Uint8List(2500000); // 2.5 MB
    for (int i = 0; i < videoData.length; i++) {
      videoData[i] = (i * 13) % 256;
    }
    await videoFile.writeAsBytes(videoData);

    final encryptedVideo = await nodeA.encryptFile('nodeB', videoFile, '${tempDir.path}/video.enc');
    expect(encryptedVideo, isNotNull);

    final decryptedVideo = await nodeB.decryptFile('nodeA', encryptedVideo!, '${tempDir.path}/decrypted_video.mp4');
    expect(decryptedVideo, isNotNull);
    expect(await decryptedVideo!.length(), equals(2500000));
    final decryptedVideoBytes = await decryptedVideo.readAsBytes();
    expect(decryptedVideoBytes, equals(videoData));

    // 4. Metadata encoding and parsing verification
    final safeFileNameB64 = base64Encode(utf8.encode("vacation_photo.jpg"));
    final metaMessage = "META_FILE:1024:image:$safeFileNameB64:media_msg_99:UserAlice";
    final parts = metaMessage.split(":");
    expect(parts.length, equals(6));
    expect(int.tryParse(parts[1]), equals(1024));
    expect(parts[2], equals("image"));
    expect(utf8.decode(base64Decode(parts[3])), equals("vacation_photo.jpg"));
    expect(parts[4], equals("media_msg_99"));
    expect(parts[5], equals("UserAlice"));

    tempDir.deleteSync(recursive: true);
  });
}
