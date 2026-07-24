import 'dart:async';
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

    final protocol = SettingsService.mikrotikUseSsl ? 'https' : 'http';

    return Uri.parse(
      '$protocol://$host:$port/rest/$path',
    );
  }

  // ==========================
  // GET PROFILES
  // ==========================

  static const Duration _defaultTimeout = Duration(seconds: 15);
  static const int _maxRetries = 2;

  static Future<List<String>> getProfiles() async {
    final url = _buildUri('ip/hotspot/user/profile');
    
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await http.get(
          url,
          headers: {
            'Authorization': _getAuthHeader(),
            'Content-Type': 'application/json',
          },
        ).timeout(_defaultTimeout);

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final names = data.map((e) => e['name'] as String).toList();
          
          if (!names.contains('default')) {
            names.insert(0, 'default');
          }
          
          return names;
        }
        return ['default'];
      } on TimeoutException {
        if (attempt == _maxRetries - 1) return ['default'];
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      } catch (e) {
        if (attempt == _maxRetries - 1) return ['default'];
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    
    return ['default'];
  }

  // ==========================
  // TEST CONNECTION
  // ==========================

  static Future<bool> checkConnection() async {
    final url = _buildUri('system/resource');
    
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await http.get(
          url,
          headers: {
            'Authorization': _getAuthHeader(),
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 8));

        return response.statusCode == 200;
        
      } on TimeoutException {
        if (attempt == _maxRetries - 1) return false;
        await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      } catch (e) {
        if (attempt == _maxRetries - 1) return false;
        await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
    
    return false;
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

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
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
        ).timeout(_defaultTimeout);

        return response.statusCode == 200 || response.statusCode == 201;
      } on TimeoutException {
        if (attempt == _maxRetries - 1) return false;
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      } catch (e) {
        if (attempt == _maxRetries - 1) return false;
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    
    return false;
  }

  // ==========================
  // DELETE HOTSPOT USER
  // ==========================

  static Future<bool> deleteHotspotUser(String username) async {
  try {
    final auth = _getAuthHeader();

    // 1️⃣ GET USER ID
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

    // 2️⃣ DELETE HOTSPOT USER
    final deleteUrl = _buildUri('ip/hotspot/user/$id');
    await http.delete(
      deleteUrl,
      headers: {
        'Authorization': auth,
        'Content-Type': 'application/json',
      },
    );

    // 3️⃣ DELETE ACTIVE SESSION
    final activeUrl = _buildUri('ip/hotspot/active');
    final activeRes = await http.get(
      activeUrl,
      headers: {
        'Authorization': auth,
        'Content-Type': 'application/json',
      },
    );

    if (activeRes.statusCode == 200) {
      final List activeList = jsonDecode(activeRes.body);

      for (var a in activeList) {
        if (a['user'] == username) {
          final activeId = a['.id'];
          final killUrl = _buildUri('ip/hotspot/active/$activeId');
          await http.delete(
            killUrl,
            headers: {
              'Authorization': auth,
              'Content-Type': 'application/json',
            },
          );
        }
      }
    }

    // 4️⃣ DELETE HOST ENTRY (MAC BASED)
final hostUrl = _buildUri('ip/hotspot/host');
final hostRes = await http.get(
  hostUrl,
  headers: {
    'Authorization': auth,
    'Content-Type': 'application/json',
  },
);

if (hostRes.statusCode == 200) {
  final List hosts = jsonDecode(hostRes.body);

  for (var h in hosts) {
    // Host table me user empty hota hai, MAC se match karte hain
    if ((h['mac-address'] ?? '') == (user['mac-address'] ?? '')) {
      final hostId = h['.id'];
      final removeHostUrl = _buildUri('ip/hotspot/host/$hostId');
      await http.delete(
        removeHostUrl,
        headers: {
          'Authorization': auth,
          'Content-Type': 'application/json',
        },
      );
    }
  }
}


    return true;

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
  // RANDOM PASSWORD
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

    final prefix = SettingsService.passwordPrefix;

    if (prefix == 'None') {
      return password;
    } else {
      return prefix + password;
    }
  }

  // ==========================
  // GET AVAILABLE PASSWORDS
  // ==========================

  static Future<List<Map<String, dynamic>>> getAvailablePasswords({
  String? profile,
}) async {
  final url = _buildUri('ip/hotspot/user');
  
  for (var attempt = 0; attempt < _maxRetries; attempt++) {
  try {
    final response = await http.get(
      url,
      headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      },
    ).timeout(_defaultTimeout);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      
      // ✅ SIRF UN USERS KO FILTER KARO JIN KA MAC NAHI HAI
      var availableUsers = data.where((user) {
        final mac = (user['mac-address'] ?? '').toString().trim();
        return mac.isEmpty;  // ✅ SIRF MAC NAHI WALE
      }).map((user) {
       return {
  'name': user['name'] ?? '',
  'password': user['password'] ?? '',

  'profile': 
      user['profile'] ??
      user['profile-name'] ??
      user['user-profile'] ??
      'default',

  'mac-address': user['mac-address'] ?? '',
  'comment': user['comment'] ?? '',
};

      }).toList();
      
      // ✅ AGAR PROFILE SELECT HAI TOH FILTER KARO
      if (profile != null && profile.isNotEmpty) {
        availableUsers = availableUsers.where((user) {
          return user['profile'] == profile;
        }).toList();
      }
      
      availableUsers.sort((a, b) {
        return a['name'].toString().compareTo(b['name'].toString());
      });

      return availableUsers.cast<Map<String, dynamic>>();
    }
    return [];
  } on TimeoutException {
    if (attempt == _maxRetries - 1) return [];
    await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
  } catch (e) {
    if (attempt == _maxRetries - 1) return [];
    await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
  }
  }
  
  return [];
}

// ==========================
// GET USED PASSWORDS (HAS MAC - SAVED USERS)
// ==========================

static Future<List<Map<String, dynamic>>> getUsedPasswords({
  String? profile,
}) async {
  final url = _buildUri('ip/hotspot/user');
  
  for (var attempt = 0; attempt < _maxRetries; attempt++) {
  try {
    final response = await http.get(
      url,
      headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      },
    ).timeout(_defaultTimeout);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      
      // ✅ SIRF UN USERS KO FILTER KARO JIN KA MAC HAI
      var usedUsers = data.where((user) {
        final mac = (user['mac-address'] ?? '').toString().trim();
        return mac.isNotEmpty;  // ✅ SIRF MAC WALE (USED)
      }).map((user) {
       return {
  'name': user['name'] ?? '',
  'password': user['password'] ?? '',

  'profile': 
      user['profile'] ??
      user['profile-name'] ??
      user['user-profile'] ??
      'default',

  'mac-address': user['mac-address'] ?? '',
  'comment': user['comment'] ?? '',
};

      }).toList();
      
      if (profile != null && profile.isNotEmpty) {
        usedUsers = usedUsers.where((user) {
          return user['profile'] == profile;
        }).toList();
      }
      
      usedUsers.sort((a, b) {
        return a['name'].toString().compareTo(b['name'].toString());
      });

      return usedUsers.cast<Map<String, dynamic>>();
    }
    return [];
  } on TimeoutException {
    if (attempt == _maxRetries - 1) return [];
    await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
  } catch (e) {
    if (attempt == _maxRetries - 1) return [];
    await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
  }
  }
  
  return [];
}


  // ==========================
  // MARK USER AS USED
  // ==========================

  static Future<bool> markUserAsUsed(String username) async {
    final findUrl = _buildUri(
      'ip/hotspot/user?name=${Uri.encodeQueryComponent(username)}',
    );
    
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
    try {
      final findResponse = await http.get(
        findUrl,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
      ).timeout(_defaultTimeout);
      
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
    } on TimeoutException {
      if (attempt == _maxRetries - 1) return false;
      await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
    } catch (e) {
      if (attempt == _maxRetries - 1) return false;
      await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
    }
    }
    
    return false;
  }

  // ==========================
  // GET USER PROFILES
  // ==========================

  static Future<Map<String, String>> getUserProfiles() async {
    final url = _buildUri('ip/hotspot/user');

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
      ).timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        final Map<String, String> map = {};

        for (final user in data) {
          map[user['name']] =
    user['profile'] ??
    user['profile-name'] ??
    user['user-profile'] ??
    'default';
        }

        return map;
      }

      return {};
    } on TimeoutException {
      if (attempt == _maxRetries - 1) return {};
      await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
    } catch (e) {
      if (attempt == _maxRetries - 1) return {};
      await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
    }
    }
    
    return {};
  }

  // ==========================
  // GET ACTIVE USERS - FIXED ✅
  // ==========================

  static Future<List<Map<String, dynamic>>> getActiveUsers() async {
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
    try {
      final url = _buildUri('ip/hotspot/active/print');
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': _getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          '.proplist': ['.id', 'user', 'address', 'uptime', 'bytes-in', 'bytes-out', 'server'],
        }),
      ).timeout(_defaultTimeout);
      
      if (response.statusCode != 200) {
        
        return [];
      }
      
      final List<dynamic> data = jsonDecode(response.body);
      
      
      
      return data.map((item) {
        return {
          'name': item['user'] ?? 'Unknown',
          'address': item['address'] ?? 'N/A',
          'uptime': item['uptime'] ?? 'N/A',
          'bytesIn': item['bytes-in'] ?? '0',
          'bytesOut': item['bytes-out'] ?? '0',
          'server': item['server'] ?? 'default',
          'isActive': true,
        };
      }).toList();
      
    } on TimeoutException {
      if (attempt == _maxRetries - 1) return [];
      await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
    } catch (e) {
      if (attempt == _maxRetries - 1) return [];
      await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
    }
    }
    
    return [];
  } 

static Future<Map<String, String>> getProfileExpiryMap() async {
  final url = _buildUri('ip/hotspot/user/profile');

  for (var attempt = 0; attempt < _maxRetries; attempt++) {
  try {
    final response = await http.get(
      url,
      headers: {
        'Authorization': _getAuthHeader(),
        'Content-Type': 'application/json',
      },
    ).timeout(_defaultTimeout);

    if (response.statusCode != 200) return {};

    final List<dynamic> data = jsonDecode(response.body);

    final Map<String, String> map = {};

    for (final p in data) {
      map[p['name']] = p['session-timeout'] ?? '0';
    }

    return map;
  } on TimeoutException {
    if (attempt == _maxRetries - 1) return {};
    await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
  } catch (e) {
    if (attempt == _maxRetries - 1) return {};
    await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
  }
  }
  
  return {};
}


}