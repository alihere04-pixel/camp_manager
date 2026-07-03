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
  bool isSentMarked;     // password sent mark
  String? comment;       // user note/comment
  bool isActive;         // ⭐ ACTIVE / INACTIVE USER

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
  this.amount = 0.0,
  required this.createdAt,
  required this.updatedAt,

  // ⭐ NEW FIELDS
  this.isSentMarked = false,
  this.comment,
  this.isActive = true,   // ⭐ DEFAULT ACTIVE
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
  double? amount,
  DateTime? createdAt,
  DateTime? updatedAt,

  // ⭐ NEW FIELDS
  bool? isSentMarked,
  String? comment,
  bool? isActive,
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
    amount: amount ?? this.amount,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,

    // ⭐ NEW FIELDS
    isSentMarked: isSentMarked ?? this.isSentMarked,
    comment: comment ?? this.comment,
    isActive: isActive ?? this.isActive,
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
    amount: fields[9] as double? ?? 0.0,
    createdAt: fields[10] as DateTime? ?? DateTime.now(),
    updatedAt: fields[11] as DateTime? ?? DateTime.now(),

    // ⭐ NEW FIELDS
    isSentMarked: fields[12] as bool? ?? false,
    comment: fields[13] as String?,
    isActive: fields[14] as bool? ?? true,
  );
}

  @override
  void write(BinaryWriter writer, User obj) {
   writer
  ..writeByte(15)  // ⭐ 14 → 15 (1 new field added)
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
  ..writeByte(9)
  ..write(obj.amount)
  ..writeByte(10)
  ..write(obj.createdAt)
  ..writeByte(11)
  ..write(obj.updatedAt)

  // ⭐ NEW FIELDS
  ..writeByte(12)
  ..write(obj.isSentMarked)
  ..writeByte(13)
  ..write(obj.comment)
  ..writeByte(14)
  ..write(obj.isActive);

  }
}