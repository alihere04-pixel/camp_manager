  import 'dart:convert';
  import 'dart:math';
  import 'package:http/http.dart' as http;
  import 'settings_service.dart';

  class MikroTikService {

    static String _getAuthHeader() {
      final user = SettingsService.mikrotikUser;
      final pass = SettingsService.mikrotikPass;

      final credentials = base64Encode(
        utf8.encode('$user:$pass'),
      );

      return 'Basic $credentials';
    }


    static Uri _buildUri(String path) {
      final host = SettingsService.mikrotikHost;
      final port = SettingsService.mikrotikPort;

      final protocol =
          SettingsService.mikrotikUseSsl ? 'https' : 'http';

      return Uri.parse(
        '$protocol://$host:$port/rest/$path',
      );
    }


    // ==========================
    // GET PROFILES (NEW)
    // ==========================

    static Future<List<String>> getProfiles() async {
    // ✅ USER PROFILES FETCH KARO
    final url = _buildUri('ip/hotspot/user/profile');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final names = data.map((e) => e['name'] as String).toList();
        
        
        // ✅ DEFAULT PROFILE BHI ADD KARO (AGAR NAHI HAI)
        if (!names.contains('default')) {
          names.insert(0, 'default');
        }
        
        return names;
      }
      return ['default'];
    } catch (e) {
      
      return ['default'];
    }
  }

    // ==========================
    // TEST CONNECTION
    // ==========================

    static Future<bool> checkConnection() async {
  final url = _buildUri('system/resource');
  
  
  
  try {
    final response = await http.get(
      url,
      headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 5));

    

    // ✅ IP BHI CHECK KARO
    return response.statusCode == 200;
    
  } catch(e) {
    
    return false;
  }
}

    // ==========================
    // CREATE HOTSPOT USER
    // ==========================

    static Future<bool> createHotspotUser({
    required String username,
    required String password,
    required String comment,
    required String profile,
  }) async {


      final url = _buildUri('ip/hotspot/user');


      try {


        final response = await http.put(

          url,

          headers: {

            'Authorization': _getAuthHeader(),
            'Content-Type': 'application/json',

          },


          body: jsonEncode({

            'name': username,
            'password': password,
            'comment': comment,
            'profile': profile,

          }),


        ).timeout(
          const Duration(seconds: 10),
        );



        



        return response.statusCode == 200 ||
            response.statusCode == 201;



      } catch(e) {

        

        return false;

      }

    }




    // ==========================
    // DELETE HOTSPOT USER
    // ==========================

    static Future<bool> deleteHotspotUser(String username) async {
  try {
    final auth = _getAuthHeader();

    final url = _buildUri('ip/hotspot/user');

    final response = await http.get(
      url,
      headers: {
        'Authorization': auth,
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) return false;

    final List users = jsonDecode(response.body);

    final user = users.firstWhere(
      (u) => u['name'] == username,
      orElse: () => null,
    );

    if (user == null) return false;

    final id = user['.id'];

   

    // ⭐ FIXED DELETE URL (IMPORTANT)
    final deleteUrl = _buildUri('ip/hotspot/user/$id');

    final deleteResponse = await http.delete(
      deleteUrl,
      headers: {
        'Authorization': auth,
        'Content-Type': 'application/json',
      },
    );

   

    return deleteResponse.statusCode == 200 ||
           deleteResponse.statusCode == 204;

  } catch (e) {
    
    return false;
  }
}

    // ==========================
    // RANDOM USERNAME
    // ==========================

    static String generateUsername(String name) {
    return name.trim();
  }

    // ==========================
    // RANDOM PASSWORD (UPDATED)
    // ==========================

    static String generateRandomPassword(int length, String type) {
  String chars = '';

  switch (type) {
    case 'capital':
      chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
      break;
    case 'small':
      chars = 'abcdefghijkmnpqrstuvwxyz';
      break;
    case 'mix':
      chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      break;
    case 'number':
      chars = '23456789';
      break;
    default:
      chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  }

  final random = Random();

  final password = List.generate(
    length,
    (index) => chars[random.nextInt(chars.length)],
  ).join();

  // 🔥 PREFIX APPLY HERE (MAIN FIX)
  final prefix = SettingsService.passwordPrefix;

  if (prefix == 'None') {
    return password;
  } else {
    return prefix + password;
  }
}
      // ==========================
  // GET AVAILABLE PASSWORDS (PROFILE-WISE)
  // ==========================

  static Future<List<Map<String, dynamic>>> getAvailablePasswords({
  String? profile,
}) async {
  final url = _buildUri('ip/hotspot/user');
  try {
    final response = await http.get(
      url,
      headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
  final List<dynamic> data = jsonDecode(response.body);
  
  // ✅ DEBUG: DEKHO KE KONSI FIELDS HAIN
  if (data.isNotEmpty) {
    
  }

  
  
 var available = data.where((user) {

  final mac =
      (user['mac-address'] ?? '').toString().trim();

  return mac.isEmpty;

}).toList();
  // ✅ AGAR PROFILE SELECT HAI TOH US PROFILE KE USERS FILTER KARO
  if (profile != null && profile.isNotEmpty) {
    available = available.where((user) {
      return user['profile'] == profile;
    }).toList();  // ✅ VAR HATAO (pehle se define hai)
  }
  
  available.sort((a, b) {
  return a['name']
      .toString()
      .compareTo(
        b['name'].toString(),
      );
});

  return available.cast<Map<String, dynamic>>();
}
    return [];
  } catch (e) {
    
    return [];
  }
}
  // ==========================
  // MARK USER AS USED
  // ==========================

  static Future<bool> markUserAsUsed(String username) async {
    // Pehle user find karo
    final findUrl = _buildUri(
  'ip/hotspot/user?name=${Uri.encodeQueryComponent(username)}',
);
    try {
      final findResponse = await http.get(
        findUrl,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (findResponse.statusCode == 200) {
        final List<dynamic> users = jsonDecode(findResponse.body);
        if (users.isNotEmpty) {
          final id = users[0]['.id'];
          final updateUrl = _buildUri('ip/hotspot/user/$id');
          
          final updateResponse = await http.patch(
            updateUrl,
            headers: {
              'Authorization': _getAuthHeader(),
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'comment': 'used',
            }),
          ).timeout(const Duration(seconds: 10));
          
          return updateResponse.statusCode == 200;
        }
      }
      return false;
    } catch (e) {
      
      return false;
    }
  }
  }