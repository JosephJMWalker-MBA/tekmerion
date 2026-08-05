import 'dart:convert';
import 'package:crypto/crypto.dart';

class NotificationIdGenerator {
  /// Generates a deterministic, positive 31-bit Android-safe notification ID.
  /// 
  /// The algorithm uses SHA-256 with a versioned prefix and an attempt counter
  /// to resolve collisions. It masks the result to 31 bits to ensure it fits
  /// within standard signed 32-bit integer limits used by Android.
  static int generateId(String occurrenceKey, {int attempt = 0}) {
    final input = 'tekmerion-notification-id:v1:$occurrenceKey:$attempt';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    
    // Take the first 4 bytes and interpret them as a big-endian 32-bit integer
    final firstFour = digest.bytes.sublist(0, 4);
    var rawInt = (firstFour[0] << 24) |
                 (firstFour[1] << 16) |
                 (firstFour[2] << 8) |
                 firstFour[3];
                 
    // Constrain to 31 bits (positive, max 0x7FFFFFFF)
    var result = rawInt & 0x7FFFFFFF;
    
    // Remap 0 to 1 if it ever happens, assuming 0 might be problematic for some plugins.
    if (result == 0) {
      result = 1;
    }
    
    return result;
  }
}
