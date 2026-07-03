import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'database/hive_database.dart';
import 'screens/camp_list_screen.dart';
import 'screens/voucher_inventory_screen.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await SettingsService.init();
  await HiveDatabase.init();

  final prefs = await SharedPreferences.getInstance();
  final campList = prefs.getString('camp_list');

  // ⭐ DEFAULT CAMP AUTO-CREATE
  if (campList == null) {
    final defaultCamp = [
      {
        "campName": "My Camp",
        "host": SettingsService.mikrotikHost,
        "port": SettingsService.mikrotikPort,
        "user": SettingsService.mikrotikUser,
        "pass": SettingsService.mikrotikPass,
        "ssl": SettingsService.mikrotikUseSsl,
      }
    ];

    await prefs.setString('camp_list', jsonEncode(defaultCamp));
  }

  // ⭐ MIGRATE OLD ROOMS → DEFAULT CAMP
  final roomsBox = HiveDatabase.getRoomsBox();
  final usersBox = HiveDatabase.getUsersBox();

  final allRooms = roomsBox.values.toList();

  for (var room in allRooms) {
    if (room.campName == null || room.campName.isEmpty) {
      final updatedRoom = room.copyWith(
        campName: "My Camp",
      );
      await roomsBox.put(updatedRoom.id, updatedRoom);
    }
  }

  // ⭐ USERS ALREADY ROOM KE ANDAR SAFE HAIN → NO CHANGE NEEDED

  runApp(const CampInternetApp());
}

class CampInternetApp extends StatelessWidget {
  const CampInternetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camp Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const CampListScreen(),
        '/inventory': (context) => const VoucherInventoryScreen(),
      },
    );
  }
}
