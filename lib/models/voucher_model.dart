import 'package:hive/hive.dart';

class Voucher extends HiveObject {
  final String id;
  final String code;
  final bool isUsed;
  final String? assignedToUserId;
  final DateTime? assignedAt;

  Voucher({
    required this.id,
    required this.code,
    this.isUsed = false,
    this.assignedToUserId,
    this.assignedAt,
  });

  Voucher copyWith({
    String? id,
    String? code,
    bool? isUsed,
    String? assignedToUserId,
    DateTime? assignedAt,
  }) {
    return Voucher(
      id: id ?? this.id,
      code: code ?? this.code,
      isUsed: isUsed ?? this.isUsed,
      assignedToUserId: assignedToUserId ?? this.assignedToUserId,
      assignedAt: assignedAt ?? this.assignedAt,
    );
  }
}

class VoucherAdapter extends TypeAdapter<Voucher> {
  @override
  final int typeId = 2;

  @override
  Voucher read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Voucher(
      id: fields[0] as String,
      code: fields[1] as String,
      isUsed: fields[2] as bool? ?? false,
      assignedToUserId: fields[3] as String?,
      assignedAt: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Voucher obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.code)
      ..writeByte(2)
      ..write(obj.isUsed)
      ..writeByte(3)
      ..write(obj.assignedToUserId)
      ..writeByte(4)
      ..write(obj.assignedAt);
  }
}