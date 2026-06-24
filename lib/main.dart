import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'database/hive_database.dart';
import 'screens/home_screen.dart';
import 'screens/voucher_inventory_screen.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive database
  await Hive.initFlutter();
  
  // Initialize settings
  await SettingsService.init();
  
  // Initialize database (registers adapters and opens boxes)
  await HiveDatabase.init();

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
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/inventory': (context) => const VoucherInventoryScreen(),
      },
    );
  }
}