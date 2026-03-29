import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'dart:typed_data';

void main() {
  final keyString = 'cw_0x689RpI_jtRR7oE8h_eQsKImvJapLeSbXpwF4e4=';
  final key = Key.fromBase64(keyString);
  final fernet = Fernet(key);
  final encrypter = Encrypter(fernet);

  final jn = r'\x5b3132382c302c302c302c302c3130352c3230302c3232332c3131372c36322c35302c38362c3234322c39382c37352c3130392c37382c34302c3135342c32312c382c34352c35382c34392c3136392c3133342c39322c37302c36392c3233362c3235332c3137342c3130312c3138332c3135322c3134322c3232382c382c3135332c34312c37302c3136312c3130312c3139392c3130382c33312c33392c34392c35392c3232332c3131392c34332c3134372c3231332c3234372c38322c38382c3231312c3139352c3136342c33382c3132302c34362c38382c3130352c372c3139342c322c3131302c37342c3230332c34312c3233345d';
  
  if (jn.startsWith('\\x')) {
    final hexStr = jn.substring(2);
    final asciiBytes = <int>[];
    for (int i = 0; i < hexStr.length; i += 2) {
      asciiBytes.add(int.parse(hexStr.substring(i, i + 2), radix: 16));
    }
    
    final inner = String.fromCharCodes(asciiBytes);
    print('inner string: $inner');
    
    if (inner.startsWith('[')) {
      final stripped = inner.substring(1, inner.length - 1).trim();
      final parsedBytes = stripped.split(',').map((e) => int.parse(e.trim())).toList();
      print('parsedBytes: $parsedBytes');
      
      try {
        final encrypted = Encrypted(Uint8List.fromList(parsedBytes));
        final result = encrypter.decrypt(encrypted);
        print('decrypted: $result');
      } catch (e) {
        print('decrypt error: $e');
        print('fallback: ${String.fromCharCodes(parsedBytes)}');
      }
    }
  }
}
