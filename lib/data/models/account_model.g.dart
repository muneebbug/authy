// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AccountModelAdapter extends TypeAdapter<AccountModel> {
  @override
  final int typeId = 0;

  @override
  AccountModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AccountModel(
      id: fields[0] as String,
      issuer: fields[1] as String,
      accountName: fields[2] as String,
      secretKey: fields[3] as String,
      algorithm: fields[4] as Algorithm,
      digits: fields[5] as int,
      period: fields[6] as int,
      colorCode: fields[7] as int,
      createdAt: fields[8] as DateTime,
      lastUsedAt: fields[9] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, AccountModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.issuer)
      ..writeByte(2)
      ..write(obj.accountName)
      ..writeByte(3)
      ..write(obj.secretKey)
      ..writeByte(4)
      ..write(obj.algorithm)
      ..writeByte(5)
      ..write(obj.digits)
      ..writeByte(6)
      ..write(obj.period)
      ..writeByte(7)
      ..write(obj.colorCode)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.lastUsedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
