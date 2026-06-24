import 'package:hive/hive.dart';
import 'user_model.dart';

class Room extends HiveObject {
  final String id;
  final String roomNumber;
  final List<User> users;
  bool isFullyPaid;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int month;    // ✅ ADD
  final int year;     // ✅ ADD

  Room({
    required this.id,
    required this.roomNumber,
    required this.users,
    this.isFullyPaid = false,
    required this.createdAt,
    required this.updatedAt,
    required this.month,   // ✅ ADD
    required this.year,    // ✅ ADD
  });

  int get totalUsers => users.length;
  int get paidUsers => users.where((u) => u.isPaid).length;
  bool get allUsersPaid =>
    users.isNotEmpty && users.every((u) => u.isPaid);

  Room copyWith({
    String? id,
    String? roomNumber,
    List<User>? users,
    bool? isFullyPaid,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? month,
    int? year,
  }) {
    return Room(
      id: id ?? this.id,
      roomNumber: roomNumber ?? this.roomNumber,
      users: users ?? this.users,
      isFullyPaid: isFullyPaid ?? this.isFullyPaid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      month: month ?? this.month,
      year: year ?? this.year,
    );
  }
}

class RoomAdapter extends TypeAdapter<Room> {
  @override
  final int typeId = 0;

  @override
  Room read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Room(
      id: fields[0] as String,
      roomNumber: fields[1] as String,
      users: (fields[2] as List?)?.cast<User>() ?? [],
      isFullyPaid: fields[3] as bool? ?? false,
      createdAt: fields[4] as DateTime? ?? DateTime.now(),
      updatedAt: fields[5] as DateTime? ?? DateTime.now(),
      month: fields[6] as int? ?? DateTime.now().month,    // ✅ ADD
      year: fields[7] as int? ?? DateTime.now().year,      // ✅ ADD
    );
  }

  @override
  void write(BinaryWriter writer, Room obj) {
    writer
      ..writeByte(8)  // ✅ 6 se 8 karo
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.roomNumber)
      ..writeByte(2)
      ..write(obj.users)
      ..writeByte(3)
      ..write(obj.isFullyPaid)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)    // ✅ NAYA
      ..write(obj.month)    // ✅ NAYA
      ..writeByte(7)    // ✅ NAYA
      ..write(obj.year);     // ✅ NAYA
  }
}