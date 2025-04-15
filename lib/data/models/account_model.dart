import 'package:hive/hive.dart';
import 'package:sentinel/domain/entities/account.dart';

part 'account_model.g.dart';

@HiveType(typeId: 0)
class AccountModel extends Account {
  @HiveField(0)
  @override
  final String id;

  @HiveField(1)
  @override
  final String issuer;

  @HiveField(2)
  @override
  final String accountName;

  @HiveField(3)
  @override
  final String secretKey;

  @HiveField(4)
  @override
  final Algorithm algorithm;

  @HiveField(5)
  @override
  final int digits;

  @HiveField(6)
  @override
  final int period;

  @HiveField(7)
  @override
  final int colorCode;

  @HiveField(8)
  @override
  final DateTime createdAt;

  @HiveField(9)
  @override
  DateTime lastUsedAt;

  AccountModel({
    required this.id,
    required this.issuer,
    required this.accountName,
    required this.secretKey,
    required this.algorithm,
    required this.digits,
    required this.period,
    required this.colorCode,
    required this.createdAt,
    required this.lastUsedAt,
  }) : super(
         id: id,
         issuer: issuer,
         accountName: accountName,
         secretKey: secretKey,
         algorithm: algorithm,
         digits: digits,
         period: period,
         colorCode: colorCode,
         createdAt: createdAt,
         lastUsedAt: lastUsedAt,
       );

  /// Create a model from a domain entity
  factory AccountModel.fromEntity(Account account) {
    return AccountModel(
      id: account.id,
      issuer: account.issuer,
      accountName: account.accountName,
      secretKey: account.secretKey,
      algorithm: account.algorithm,
      digits: account.digits,
      period: account.period,
      colorCode: account.colorCode,
      createdAt: account.createdAt,
      lastUsedAt: account.lastUsedAt,
    );
  }

  /// Convert to a Map for JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'issuer': issuer,
      'accountName': accountName,
      'secretKey': secretKey,
      'algorithm': algorithm.toString().split('.').last,
      'digits': digits,
      'period': period,
      'colorCode': colorCode,
      'createdAt': createdAt.toIso8601String(),
      'lastUsedAt': lastUsedAt.toIso8601String(),
    };
  }

  /// Create from a JSON Map
  factory AccountModel.fromJson(Map<String, dynamic> json) {
    Algorithm algorithm;
    switch (json['algorithm']) {
      case 'sha256':
        algorithm = Algorithm.sha256;
        break;
      case 'sha512':
        algorithm = Algorithm.sha512;
        break;
      default:
        algorithm = Algorithm.sha1;
    }

    return AccountModel(
      id: json['id'],
      issuer: json['issuer'],
      accountName: json['accountName'],
      secretKey: json['secretKey'],
      algorithm: algorithm,
      digits: json['digits'],
      period: json['period'],
      colorCode: json['colorCode'],
      createdAt: DateTime.parse(json['createdAt']),
      lastUsedAt: DateTime.parse(json['lastUsedAt']),
    );
  }
}
