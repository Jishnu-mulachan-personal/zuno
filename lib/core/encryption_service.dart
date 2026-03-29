import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EncryptionService {
  static late final Encrypter _encrypter;

  static void init() {
    final keyString = dotenv.env['FERNET_KEY'] ??
        'cw_0x689RpI_jtRR7oE8h_eQsKImvJapLeSbXpwF4e4=';
    final key = Key.fromBase64(keyString);
    final fernet = Fernet(key);
    _encrypter = Encrypter(fernet);
  }

  static List<int> encrypt(String text) {
    if (text.isEmpty) return [];
    try {
      final encrypted = _encrypter.encrypt(text);
      return encrypted.bytes;
    } catch (e) {
      return text.codeUnits;
    }
  }

  /// Decrypts Fernet-encrypted bytes back to plain text.
  /// Throws if the bytes are not valid Fernet ciphertext (e.g. old plain records).
  static String decrypt(List<int> bytes) {
    if (bytes.isEmpty) return '';
    final encrypted = Encrypted(Uint8List.fromList(bytes));
    return _encrypter.decrypt(encrypted);
  }
}
