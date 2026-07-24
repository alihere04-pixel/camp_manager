import 'package:hive/hive.dart';


class SettingsService {
    static const String _boxName = 'settings_box';



  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  static Box _getBox() => Hive.box(_boxName);

  static String get mikrotikHost =>
      _getBox().get('mikrotik_host', defaultValue: '') as String;

  static String get mikrotikUser =>
      _getBox().get('mikrotik_user', defaultValue: '') as String;

  // ✅ CHANGE 1: Future hatao, String rakho, Hive se lo
  static String get mikrotikPass {
    return _getBox().get('mikrotik_pass', defaultValue: '') as String;
  }

  static String get mikrotikPort =>
      _getBox().get('mikrotik_port', defaultValue: '8081') as String;

  static bool get mikrotikUseSsl =>
      _getBox().get('mikrotik_use_ssl', defaultValue: false) as bool;

  static String get mikrotikProfile =>
      _getBox().get('mikrotik_profile', defaultValue: 'default') as String;

  static bool get mikrotikConnected =>
      _getBox().get('mikrotik_connected', defaultValue: false) as bool;

  static Future<void> saveMikrotikConnected(bool value) async {
    await _getBox().put('mikrotik_connected', value);
  }

  static Future<void> setMikrotikHost(String value) async {
    await _getBox().put('mikrotik_host', value);
  }

  static Future<void> setMikrotikPort(String value) async {
    await _getBox().put('mikrotik_port', value);
  }

  static Future<void> setMikrotikUser(String value) async {
    await _getBox().put('mikrotik_user', value);
  }

  // ✅ CHANGE 2: Hive mein save karo, secure storage mat use karo
  static Future<void> setMikrotikPass(String value) async {
    await _getBox().put('mikrotik_pass', value);
  }

  static Future<void> setMikrotikUseSsl(bool value) async {
    await _getBox().put('mikrotik_use_ssl', value);
  }

  static Future<void> saveMikrotikSettings({
    required String host,
    required String user,
    required String pass,
    required String port,
    required bool useSsl,
  }) async {
    final box = _getBox();
    await box.put('mikrotik_host', host);
    await box.put('mikrotik_user', user);
    // ✅ CHANGE 3: Hive mein save karo
    await box.put('mikrotik_pass', pass);
    await box.put('mikrotik_port', port);
    await box.put('mikrotik_use_ssl', useSsl);
  }

  static Future<void> saveMikrotikProfile(String profile) async {
    await _getBox().put('mikrotik_profile', profile);
  }

  static int get passwordLength =>
      _getBox().get('password_length', defaultValue: 8) as int;

  static String get passwordType =>
      _getBox().get('password_type', defaultValue: 'mix') as String;

  static String get passwordPrefix =>
      _getBox().get('password_prefix', defaultValue: 'None') as String;

  static Future<void> savePasswordSettings({
    required int length,
    required String type,
    required String prefix,
  }) async {
    final box = _getBox();
    await box.put('password_length', length);
    await box.put('password_type', type);
    await box.put('password_prefix', prefix);
  }

  static String get whatsappMessageTemplate => _getBox().get(
        'whatsapp_template',
        defaultValue:
            'Internet Password\n\nName: {name}\nUsername: {username}\nPassword: {password}',
      ) as String;

  static Future<void> saveWhatsappTemplate(String template) async {
    await _getBox().put('whatsapp_template', template);
  }
}