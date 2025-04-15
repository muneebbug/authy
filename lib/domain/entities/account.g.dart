// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AlgorithmAdapter extends TypeAdapter<Algorithm> {
  @override
  final int typeId = 2;

  @override
  Algorithm read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Algorithm.sha1;
      case 1:
        return Algorithm.sha256;
      case 2:
        return Algorithm.sha512;
      default:
        return Algorithm.sha1;
    }
  }

  @override
  void write(BinaryWriter writer, Algorithm obj) {
    switch (obj) {
      case Algorithm.sha1:
        writer.writeByte(0);
        break;
      case Algorithm.sha256:
        writer.writeByte(1);
        break;
      case Algorithm.sha512:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlgorithmAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
