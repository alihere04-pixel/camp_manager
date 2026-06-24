import 'package:hive_flutter/hive_flutter.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';
import '../models/voucher_model.dart';

class HiveDatabase {
  static const String roomsBoxName = 'rooms_box';
  static const String usersBoxName = 'users_box';
  static const String vouchersBoxName = 'vouchers_box';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register all adapters
    Hive.registerAdapter(RoomAdapter());
    Hive.registerAdapter(UserAdapter());
    Hive.registerAdapter(VoucherAdapter());

    // Open boxes
    await Hive.openBox<Room>(roomsBoxName);
    await Hive.openBox<User>(usersBoxName);
    await Hive.openBox<Voucher>(vouchersBoxName);
  }

  static Box<Room> getRoomsBox() => Hive.box<Room>(roomsBoxName);
  static Box<User> getUsersBox() => Hive.box<User>(usersBoxName);
  static Box<Voucher> getVouchersBox() => Hive.box<Voucher>(vouchersBoxName);

  // Helper method to get all rooms
  static List<Room> getAllRooms() {
    return getRoomsBox().values.toList();
  }

  // Helper method to get users for a specific room
  static List<User> getUsersForRoom(String roomId) {
    return getUsersBox().values.where((user) => user.roomId == roomId).toList();
  }

  // Helper method to get available vouchers (not used)
  static List<Voucher> getAvailableVouchers() {
    return getVouchersBox().values.where((v) => !v.isUsed).toList();
  }
}