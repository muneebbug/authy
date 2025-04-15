import 'dart:convert';
import 'dart:typed_data';
import 'package:base32/base32.dart';
import 'package:cryptography/cryptography.dart';
import 'package:authy/domain/entities/account.dart';
import 'package:ntp/ntp.dart';

/// Service for generating TOTP codes according to RFC 6238
class TOTPService {
  /// Cache for the time offset with NTP servers
  static int? _timeOffset;

  /// Initialize the time offset with NTP
  static Future<void> initTimeSync() async {
    try {
      print("Initializing time sync...");
      final DateTime ntpTime = await NTP.now();
      final DateTime localTime = DateTime.now();
      _timeOffset =
          ntpTime.millisecondsSinceEpoch - localTime.millisecondsSinceEpoch;
      print("Time offset: $_timeOffset ms");
    } catch (e) {
      print("Error syncing time: $e");
      // If NTP fails, we'll use local time
      _timeOffset = 0;
    }
  }

  /// Get the current timestamp adjusted with NTP offset
  static int _getCurrentTimestamp() {
    final DateTime now = DateTime.now();
    final int adjustedTimeMs = now.millisecondsSinceEpoch + (_timeOffset ?? 0);
    return adjustedTimeMs ~/ 1000;
  }

  /// Generate TOTP code for an account
  static Future<String> generateCode(Account account) async {
    try {
      print("Generating code for ${account.issuer}");
      // Decode the base32 secret key
      final Uint8List secretBytes = base32.decode(account.secretKey);
      print("Secret key decoded, length: ${secretBytes.length}");

      // Calculate the time counter value (T)
      final int counter = _getCurrentTimestamp() ~/ account.period;
      print("Counter value: $counter");

      // Convert counter to bytes
      final Uint8List counterBytes = _int64ToBytes(counter);

      // Choose the appropriate algorithm
      MacAlgorithm algorithm;
      switch (account.algorithm) {
        case Algorithm.sha1:
          algorithm = Hmac.sha1();
          break;
        case Algorithm.sha256:
          algorithm = Hmac.sha256();
          break;
        case Algorithm.sha512:
          algorithm = Hmac.sha512();
          break;
      }

      // Compute the HMAC
      final SecretKey secretKey = SecretKey(secretBytes);
      final List<int> rawHmac = await algorithm
          .calculateMac(counterBytes, secretKey: secretKey)
          .then((macValue) => macValue.bytes);

      print("HMAC calculated, length: ${rawHmac.length}");

      // Generate the TOTP code using proper truncation algorithm
      final int offset = rawHmac.last & 0xf;
      final int binary =
          ((rawHmac[offset] & 0x7f) << 24) |
          ((rawHmac[offset + 1] & 0xff) << 16) |
          ((rawHmac[offset + 2] & 0xff) << 8) |
          (rawHmac[offset + 3] & 0xff);

      // Create the TOTP code with proper modulo (10^digits)
      final int digitsPower = 10.toInt() * 10.toInt().pow(account.digits - 1);
      final int code = binary % digitsPower;

      print("Generated code: $code");

      // Format the code to have the correct number of digits
      final String result = code.toString().padLeft(account.digits, '0');
      print("Formatted code: $result");
      return result;
    } catch (e, stack) {
      print("Error generating TOTP code: $e");
      print("Stack trace: $stack");
      rethrow;
    }
  }

  /// Calculate time remaining until next code rotation
  static int getRemainingSeconds(Account account) {
    final int timestamp = _getCurrentTimestamp();
    final int currentPeriod = timestamp ~/ account.period;
    final int nextChange = (currentPeriod + 1) * account.period;
    return nextChange - timestamp;
  }

  /// Convert a 64-bit integer to a byte array (big-endian)
  static Uint8List _int64ToBytes(int value) {
    final ByteData data = ByteData(8);
    data.setInt64(0, value, Endian.big);
    return data.buffer.asUint8List();
  }
}

extension IntPow on int {
  int pow(int exponent) {
    if (exponent < 0) {
      throw ArgumentError('Exponent must be non-negative');
    }

    int result = 1;
    int base = this;

    while (exponent > 0) {
      if (exponent & 1 == 1) {
        result *= base;
      }
      exponent >>= 1;
      base *= base;
    }

    return result;
  }
}
