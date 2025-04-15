import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:base32/base32.dart';
import 'package:crypto/crypto.dart' hide Hmac;
import 'package:cryptography/cryptography.dart';
import 'package:sentinel/domain/entities/account.dart';
import 'package:ntp/ntp.dart';
import 'package:sentinel/core/utils/logger_util.dart';

/// Service for generating TOTP codes according to RFC 6238
class TOTPService {
  /// Cache for the time offset with NTP servers
  static int? _timeOffset;

  /// Initialize time synchronization with NTP
  static Future<void> initializeTimeSync() async {
    try {
      LoggerUtil.debug("Initializing time sync...");
      final DateTime ntpTime = await NTP.now();
      final DateTime localTime = DateTime.now();
      _timeOffset =
          ntpTime.millisecondsSinceEpoch - localTime.millisecondsSinceEpoch;
      LoggerUtil.debug("Time offset: $_timeOffset ms");
    } catch (e) {
      LoggerUtil.error("Error syncing time", e);
      // Use default offset (0) if time sync fails
      _timeOffset = 0;
    }
  }

  /// Get the current timestamp adjusted with NTP offset
  static int _getCurrentTimestamp() {
    final DateTime now = DateTime.now();
    final int adjustedTimeMs = now.millisecondsSinceEpoch + (_timeOffset ?? 0);
    return adjustedTimeMs ~/ 1000;
  }

  /// Generate a TOTP code for the specified account
  static Future<String> generateCode(Account account) async {
    try {
      LoggerUtil.debug("Generating code for ${account.issuer}");
      // Decode the secret key (base32)
      final secretBytes = base32.decode(account.secretKey);
      LoggerUtil.debug("Secret key decoded, length: ${secretBytes.length}");

      // Calculate the counter value from Unix time
      final timeMs = DateTime.now().millisecondsSinceEpoch + (_timeOffset ?? 0);
      final counter = (timeMs ~/ 1000) ~/ account.period;
      LoggerUtil.debug("Counter value: $counter");

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

      // Calculate HMAC
      final hmac = await _calculateHmac(
        secretBytes,
        counterBytes,
        account.algorithm,
      );
      LoggerUtil.debug("HMAC calculated, length: ${hmac.length}");

      // Convert to integer code base on RFC 6238
      final code = _generateCodeFromHmac(hmac, account.digits);
      LoggerUtil.debug("Generated code: $code");

      // Format the code with proper padding
      String result = code.toString().padLeft(account.digits, '0');
      LoggerUtil.debug("Formatted code: $result");
      return result;
    } catch (e, stack) {
      LoggerUtil.error("Error generating TOTP code", e, stack);
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

  /// Calculate HMAC
  static Future<List<int>> _calculateHmac(
    Uint8List secretBytes,
    Uint8List counterBytes,
    Algorithm algorithm,
  ) async {
    // Choose the appropriate algorithm
    MacAlgorithm macAlgorithm;
    switch (algorithm) {
      case Algorithm.sha1:
        macAlgorithm = Hmac.sha1();
        break;
      case Algorithm.sha256:
        macAlgorithm = Hmac.sha256();
        break;
      case Algorithm.sha512:
        macAlgorithm = Hmac.sha512();
        break;
    }

    // Compute the HMAC
    final SecretKey secretKey = SecretKey(secretBytes);
    final macValue = await macAlgorithm.calculateMac(
      counterBytes,
      secretKey: secretKey,
    );
    return macValue.bytes;
  }

  /// Generate the TOTP code from the HMAC
  static int _generateCodeFromHmac(List<int> hmac, int digits) {
    // Generate the TOTP code using proper truncation algorithm
    final int offset = hmac.last & 0xf;
    final int binary =
        ((hmac[offset] & 0x7f) << 24) |
        ((hmac[offset + 1] & 0xff) << 16) |
        ((hmac[offset + 2] & 0xff) << 8) |
        (hmac[offset + 3] & 0xff);

    // Create the TOTP code with proper modulo (10^digits)
    final int digitsPower = 10.toInt() * 10.toInt().pow(digits - 1);
    return binary % digitsPower;
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
