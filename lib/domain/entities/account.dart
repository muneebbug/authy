import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';

part 'account.g.dart';

/// Algorithm types for TOTP generation
@HiveType(typeId: 2)
enum Algorithm {
  @HiveField(0)
  sha1,
  @HiveField(1)
  sha256,
  @HiveField(2)
  sha512,
}

/// Account entity representing a 2FA account
class Account {
  /// Unique identifier for the account
  final String id;

  /// Service name (e.g., Google, Twitter)
  final String issuer;

  /// User account name or email
  final String accountName;

  /// Secret key for TOTP generation (should be encrypted in storage)
  final String secretKey;

  /// TOTP algorithm type
  final Algorithm algorithm;

  /// Number of digits in the generated code
  final int digits;

  /// Period in seconds for code rotation
  final int period;

  /// Color identifier for the account (used for UI)
  final int colorCode;

  /// Timestamp when the account was created
  final DateTime createdAt;

  /// Timestamp when the account was last used
  DateTime lastUsedAt;

  Account({
    String? id,
    required this.issuer,
    required this.accountName,
    required this.secretKey,
    this.algorithm = Algorithm.sha1,
    this.digits = 6,
    this.period = 30,
    this.colorCode = 0xFF2196F3,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       lastUsedAt = lastUsedAt ?? DateTime.now();

  /// Create a copy of this account with optional parameter changes
  Account copyWith({
    String? issuer,
    String? accountName,
    String? secretKey,
    Algorithm? algorithm,
    int? digits,
    int? period,
    int? colorCode,
    DateTime? lastUsedAt,
  }) {
    return Account(
      id: id,
      issuer: issuer ?? this.issuer,
      accountName: accountName ?? this.accountName,
      secretKey: secretKey ?? this.secretKey,
      algorithm: algorithm ?? this.algorithm,
      digits: digits ?? this.digits,
      period: period ?? this.period,
      colorCode: colorCode ?? this.colorCode,
      createdAt: createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }
}
