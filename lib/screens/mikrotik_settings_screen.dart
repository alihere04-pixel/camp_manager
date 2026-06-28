import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/mikrotik_service.dart';
import 'password_manager_screen.dart';
import 'active_users_screen.dart'; 
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class MikrotikSettingsScreen extends StatefulWidget {
  const MikrotikSettingsScreen({super.key});

  @override
  State<MikrotikSettingsScreen> createState() => _MikrotikSettingsScreenState();
}

class _MikrotikSettingsScreenState extends State<MikrotikSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _userController;
  late TextEditingController _passController;
  late bool _useSsl;
  
  bool _isLoading = false;
  bool _isConnected = false;
  
  bool _obscurePassword = true;

  int _savedUsersCount = 0;
bool _isLoadingSavedUsers = false;

  
  int _selectedLength = 8;
  String _selectedType = 'mix';
  
  String _selectedProfile = 'default';
  List<String> _profiles = [];
  bool _isLoadingProfiles = false;
  
  // ✅ PASSWORD PREFIX (A-Z + None)
  String _selectedPrefix = 'None';

      // ✅ AVAILABLE PASSWORDS VARIABLES
  List<Map<String, dynamic>> _availablePasswords = [];
  bool _isLoadingPasswords = false;
  final String _selectedPasswordProfile = 'all';

   // ✅ ACTIVE USERS COUNT VARIABLES
  int _activeUsersCount = 0;
  bool _isLoadingActiveUsers = false;
  // ✅ Timer HATA DIYA


    @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: SettingsService.mikrotikHost);
    _portController = TextEditingController(text: SettingsService.mikrotikPort);
    _userController = TextEditingController(text: SettingsService.mikrotikUser);
    _passController = TextEditingController(text: SettingsService.mikrotikPass);
    _useSsl = SettingsService.mikrotikUseSsl;
    
    _selectedLength = SettingsService.passwordLength;
    _selectedPrefix = SettingsService.passwordPrefix;
    _selectedProfile = SettingsService.mikrotikProfile;

    if (!_prefixExists(_selectedPrefix)) {
      _selectedPrefix = 'None';
    }

    _selectedType = SettingsService.passwordType.toLowerCase();

    if (!['capital', 'small', 'mix', 'number'].contains(_selectedType)) {
      _selectedType = 'mix';
    }
    
    _isConnected = SettingsService.mikrotikConnected;

    _loadProfiles();
    _checkSavedConnection();
    
       _loadActiveUsersCount();
       _loadSavedUsersCount();

    // ✅ Timer HATA DIYA
  }
  bool _prefixExists(String value) {
    return value == 'None' ||
        List.generate(
          26,
          (i) => String.fromCharCode(65 + i),
        ).contains(value);
  }

    @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // ✅ LOAD AVAILABLE PASSWORDS
  Future<void> _loadAvailablePasswords() async {
    setState(() {
      _isLoadingPasswords = true;
      _availablePasswords = [];
    });
    
    try {
      final profile = _selectedPasswordProfile == 'all' ? null : _selectedPasswordProfile;

      _availablePasswords = await MikroTikService.getAvailablePasswords(
        profile: profile,
      );
      
      // ✅ SAVE PASSWORDS FOR OFFLINE USE
      if (_availablePasswords.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'saved_passwords',
          jsonEncode(_availablePasswords),
        );
      }
      
      // agar MikroTik se empty aya to local cache use karo
      if (_availablePasswords.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final data = prefs.getString('saved_passwords');

        if (data != null && data.isNotEmpty) {
          final List decoded = jsonDecode(data);
          _availablePasswords = decoded
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('saved_passwords');

      if (data != null && data.isNotEmpty) {
        final List decoded = jsonDecode(data);
        _availablePasswords = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    
    if (!mounted) return;
    setState(() {
      _isLoadingPasswords = false;
    });
  }

  // ✅ LOAD ACTIVE USERS COUNT
  Future<void> _loadActiveUsersCount() async {
    setState(() {
      _isLoadingActiveUsers = true;
    });
    
    try {
      final activeUsers = await MikroTikService.getActiveUsers();
      setState(() {
        _activeUsersCount = activeUsers.length;
        _isLoadingActiveUsers = false;
      });
    } catch (e) {
      setState(() {
        _activeUsersCount = 0;
        _isLoadingActiveUsers = false;
      });
    }
  }

  Future<void> _loadSavedUsersCount() async {
  setState(() {
    _isLoadingSavedUsers = true;
  });

  try {
    final saved = await MikroTikService.getUsedPasswords();
    setState(() {
      _savedUsersCount = saved.length;
      _isLoadingSavedUsers = false;
    });
  } catch (e) {
    setState(() {
      _savedUsersCount = 0;
      _isLoadingSavedUsers = false;
    });
  }
}


  Future<void> _checkSavedConnection() async {
    try {
      final connected = await MikroTikService.checkConnection();

      if (!mounted) return;
      setState(() {
        _isConnected = connected;
      });

      await SettingsService.saveMikrotikConnected(connected);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnected = false;
      });
      await SettingsService.saveMikrotikConnected(false);
    }
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoadingProfiles = true);
    _profiles = await MikroTikService.getProfiles();
    
    if (!_profiles.contains('default')) {
      _profiles.insert(0, 'default');
    }
    
    if (_selectedProfile.isEmpty) {
      _selectedProfile = 'default';
    }
    
    setState(() => _isLoadingProfiles = false);
    
    // ✅ PROFILES LOAD HONE KE BAAD PASSWORDS LOAD KARO
    _loadAvailablePasswords();
  }

  Future<void> _testConnection() async {
    setState(() => _isLoading = true);
    final connected = await MikroTikService.checkConnection();
    
    setState(() {
      _isLoading = false;
      _isConnected = connected;
    });

    await SettingsService.saveMikrotikConnected(connected);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(connected ? '✅ Connected to MikroTik!' : '❌ Failed to connect'),
        backgroundColor: connected ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    await SettingsService.saveMikrotikSettings(
      host: _hostController.text.trim(),
      user: _userController.text.trim(),
      pass: _passController.text.trim(),
      port: _portController.text.trim(),
      useSsl: _useSsl,
    );
    
    await SettingsService.savePasswordSettings(
      length: _selectedLength,
      type: _selectedType,
      prefix: _selectedPrefix,
    );
    
    await SettingsService.saveMikrotikProfile(_selectedProfile);
    
    // ✅ AUTO-REMOVE SAVE KARO

    
    // ✅ FORCE DISCONNECT (STATUS RESET)
    _isConnected = false;
    await SettingsService.saveMikrotikConnected(false);

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Settings saved! Tap "Check Status" to verify.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MikroTik Settings'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status Card
            Card(
              color: _isConnected ? Colors.green[50] : Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _isConnected ? Icons.check_circle : Icons.warning,
                      color: _isConnected ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isConnected ? '✅ Connected to MikroTik' : '❌ Not Connected',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isConnected ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),

            // ✅ AVAILABLE PASSWORDS (CLICKABLE CARD)
InkWell(
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PasswordManagerScreen(),
      ),
    );
    _loadAvailablePasswords();
  },
  borderRadius: BorderRadius.circular(12),
  child: Card(
    color: Colors.indigo[50],
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.password, color: Colors.indigo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Available Passwords',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                if (_isLoadingPasswords)
                  const Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  )
                else
                  Text(
                    '${_availablePasswords.length} passwords available',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.indigo, size: 16),
        ],
      ),
    ),
  ),
),

const SizedBox(height: 16),  // ✅ SIRF 1 GAP (12 WALA DELETE KARO)

// ✅ ACTIVE USERS (CLICKABLE CARD)
InkWell(
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ActiveUsersScreen(),
      ),
    );
    _loadActiveUsersCount();  // ✅ WAPAS AANE PAR REFRESH
    _loadSavedUsersCount();

  },
  
  borderRadius: BorderRadius.circular(12),
  child: Card(
    color: Colors.green[50],
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.person, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
  'Saved Users',
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.green,
  ),
),

if (_isLoadingSavedUsers)
  const Text(
    'Loading...',
    style: TextStyle(
      fontSize: 12,
      color: Colors.grey,
    ),
  )
else
  Text(
    '$_savedUsersCount saved users',
    style: TextStyle(
      fontSize: 12,
      color: Colors.grey,
    ),
  ),

              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.green, size: 16),
        ],
      ),
    ),
  ),
),
const SizedBox(height: 16), 
            // IP Address
            TextFormField(
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: 'IP Address',
                hintText: 'e.g., 192.168.88.1',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wifi),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            
            const SizedBox(height: 12),
            
            // Port
            TextFormField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '8728 (HTTP) or 8729 (HTTPS)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.settings_ethernet),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            
            const SizedBox(height: 12),
            
            // Username
            TextFormField(
              controller: _userController,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'admin',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            
            const SizedBox(height: 12),
            
            // Password
            TextFormField(
              controller: _passController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              obscureText: _obscurePassword,
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            
            const SizedBox(height: 12),
            
            // SSL Switch
            SwitchListTile(
              title: const Text('Use SSL (HTTPS)'),
              subtitle: Text(_useSsl ? 'Port 8729' : 'Port 8728'),
              value: _useSsl,
              onChanged: (val) {
                setState(() => _useSsl = val);
                if (val) {
                  _portController.text = '8729';
                } else {
                  _portController.text = '8728';
                }
              },
              contentPadding: EdgeInsets.zero,
            ),
            
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            
            // ==============================
            // PASSWORD SETTINGS SECTION
            // ==============================
            const Text(
              'Password Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // ✅ PASSWORD PREFIX
            const Text(
              'Password Prefix',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            
            DropdownButtonFormField<String>(
              value: _selectedPrefix,
              decoration: const InputDecoration(
                labelText: 'Prefix (A-Z)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: 'None',
                  child: Text('None'),
                ),
                ...List.generate(26, (i) {
                  final letter = String.fromCharCode(65 + i);
                  return DropdownMenuItem(
                    value: letter,
                    child: Text(letter),
                  );
                }),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedPrefix = value;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // ✅ PASSWORD LENGTH
            const Text(
              'Password Length',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            
            DropdownButtonFormField<int>(
              value: _selectedLength,
              decoration: const InputDecoration(
                labelText: 'Length',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 4, child: Text('4')),
                DropdownMenuItem(value: 6, child: Text('6')),
                DropdownMenuItem(value: 8, child: Text('8')),
                DropdownMenuItem(value: 10, child: Text('10')),
                DropdownMenuItem(value: 12, child: Text('12')),
              ],
              onChanged: (int? value) {
                if (value == null) return;
                setState(() {
                  _selectedLength = value;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // ✅ CHARACTER TYPE
            const Text(
              'Character Type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'capital', child: Text('Capital (ABC)')),
                DropdownMenuItem(value: 'small', child: Text('Small (abc)')),
                DropdownMenuItem(value: 'mix', child: Text('Mix (AbC123)')),
                DropdownMenuItem(value: 'number', child: Text('Number (123)')),
              ],
              onChanged: (String? value) {
                if (value == null) return;
                setState(() {
                  _selectedType = value;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
                        // ✅ USER PROFILE
            const Text(
              'User Profile',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: _isLoadingProfiles
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : DropdownButton<String>(
                        value: _selectedProfile,
                        isExpanded: true,
                        hint: const Text('Select Profile'),
                        items: _profiles.map((profile) {
                          return DropdownMenuItem<String>(
                            value: profile,
                            child: Text(profile),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedProfile = value!;
                          });
                        },
                      ),
              ),
            ),
            

            
            const SizedBox(height: 24),
            
            // ✅ BUTTONS
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Save Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isLoading ? null : _saveSettings,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.network_check),
                    label: const Text('Check Status'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isLoading ? null : _testConnection,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}