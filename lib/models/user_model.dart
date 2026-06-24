import 'package:hive/hive.dart';

class User extends HiveObject {
  String id;
  String roomId;
  String name;
  String phoneNumber;
  bool isPaid;
  String? voucherCode;
  String? voucherUsername;
  bool syncedWithMikrotik;
  int passwordCount;
  double amount;  // ✅ ADDED
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.roomId,
    required this.name,
    required this.phoneNumber,
    this.isPaid = false,
    this.voucherCode,
    this.voucherUsername,
    this.syncedWithMikrotik = false,
    this.passwordCount = 1,
    this.amount = 0.0,  // ✅ ADDED
    required this.createdAt,
    required this.updatedAt,
  });

  String get initial {
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  User copyWith({
    String? id,
    String? roomId,
    String? name,
    String? phoneNumber,
    bool? isPaid,
    String? voucherCode,
    String? voucherUsername,
    bool? syncedWithMikrotik,
    int? passwordCount,
    double? amount,  // ✅ ADDED
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isPaid: isPaid ?? this.isPaid,
      voucherCode: voucherCode ?? this.voucherCode,
      voucherUsername: voucherUsername ?? this.voucherUsername,
      syncedWithMikrotik: syncedWithMikrotik ?? this.syncedWithMikrotik,
      passwordCount: passwordCount ?? this.passwordCount,
      amount: amount ?? this.amount,  // ✅ ADDED
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 1;

  @override
  User read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return User(
      id: fields[0] as String,
      roomId: fields[1] as String,
      name: fields[2] as String,
      phoneNumber: fields[3] as String,
      isPaid: fields[4] as bool? ?? false,
      voucherCode: fields[5] as String?,
      voucherUsername: fields[6] as String?,
      syncedWithMikrotik: fields[7] as bool? ?? false,
      passwordCount: fields[8] as int? ?? 1,
      amount: fields[9] as double? ?? 0.0,  // ✅ ADDED
      createdAt: fields[10] as DateTime? ?? DateTime.now(),
      updatedAt: fields[11] as DateTime? ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer
      ..writeByte(12)  // ✅ 11 se 12 karo (1 naya field)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.roomId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.phoneNumber)
      ..writeByte(4)
      ..write(obj.isPaid)
      ..writeByte(5)
      ..write(obj.voucherCode)
      ..writeByte(6)
      ..write(obj.voucherUsername)
      ..writeByte(7)
      ..write(obj.syncedWithMikrotik)
      ..writeByte(8)
      ..write(obj.passwordCount)
      ..writeByte(9)    // ✅ amount
      ..write(obj.amount)    // ✅ amount
      ..writeByte(10)   // ✅ createdAt
      ..write(obj.createdAt)
      ..writeByte(11)   // ✅ updatedAt
      ..write(obj.updatedAt);
  }
}