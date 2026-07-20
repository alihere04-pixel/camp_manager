import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/mikrotik_service.dart';
import '../services/password_export_service.dart';
import 'password_manager_screen.dart';
import 'active_users_screen.dart'; 
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:file_picker/file_picker.dart';

class MikrotikSettingsScreen extends StatefulWidget {
  final String campName;

  const MikrotikSettingsScreen({super.key, required this.campName});

  @override
  State<MikrotikSettingsScreen> createState() => _MikrotikSettingsScreenState();
}

class _MikrotikSettingsScreenState extends State<MikrotikSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _userController;
  late TextEditingController _passController;
  late TextEditingController _passwordCountController;
  late bool _useSsl;
  
  bool _isLoading = false;
  bool _isConnected = false;
  
  bool _obscurePassword = true;

  int _savedUsersCount = 0;
bool _isLoadingSavedUsers = false;

  String _loadingStatus = 'Initializing...';
  
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
 
  // ✅ Timer HATA DIYA


    @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: SettingsService.mikrotikHost);
    _portController = TextEditingController(text: SettingsService.mikrotikPort);
    _userController = TextEditingController(text: SettingsService.mikrotikUser);
    _passController = TextEditingController(text: SettingsService.mikrotikPass);
    _passwordCountController = TextEditingController(text: '100');
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
    _autoConnectOnStart(); // ✅ AUTO-CONNECT ON START
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
    _passwordCountController.dispose();
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

      // ⭐ HAR PASSWORD ME CAMP NAME ADD KARO
      for (var p in _availablePasswords) {
        p['campName'] = widget.campName;
      }
      
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

          // ⭐ CAMP FILTER LAGAO (SIRF CURRENT CAMP KA DATA)
          _availablePasswords = _availablePasswords.where((p) {
            return p['campName'] == widget.campName;
          }).toList();
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

        // ⭐ CAMP FILTER LAGAO (SIRF CURRENT CAMP KA DATA)
        _availablePasswords = _availablePasswords.where((p) {
          return p['campName'] == widget.campName;
        }).toList();
      }
    }
    
    if (!mounted) return;
    setState(() {
      _isLoadingPasswords = false;
    });
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
  // ✅ AUTO-CONNECT ON APP START
  Future<void> _autoConnectOnStart() async {
    // Pehle saved connection status check karo
    await _checkSavedConnection();
    
    // Agar saved status false hai toh auto-connect try karo
    if (!_isConnected) {
      final connected = await MikroTikService.checkConnection();
      if (mounted) {
        setState(() {
          _isConnected = connected;
        });
        await SettingsService.saveMikrotikConnected(connected);
      }
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

// PROFILES LOAD HONE KE BAAD — sirf tab load karo jab loading nahi ho rahi
if (!_isLoadingPasswords) {
  _loadAvailablePasswords();
}
}   // ← ⭐ THIS BRACKET WAS MISSING (VERY IMPORTANT)



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
    
    // ✅ AUTO-CONNECT: SETTINGS SAVE HONE KE BAAD CONNECT KARO
    _isLoading = true;
    final connected = await MikroTikService.checkConnection();
    
    setState(() {
      _isConnected = connected;
      _isLoading = false;
    });
    
    await SettingsService.saveMikrotikConnected(connected);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(connected ? '✅ Settings saved & Connected to MikroTik!' : '✅ Settings saved! But failed to connect.'),
        backgroundColor: connected ? Colors.green : Colors.orange,
      ),
    );
  }

       Future<void> _generatePdf() async {
    final countValue = int.tryParse(_passwordCountController.text.trim());

    if (countValue == null || countValue <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Password Count greater than zero.')),
      );
      return;
    }

    // ✅ SHOW LOADING DIALOG WITH STATUS
    _showLoadingDialog();

    List<String> passwords = [];
    try {
      _updateLoadingStatus('Generating passwords...');
      passwords = PasswordExportService.generateUniquePasswords(
        prefix: _selectedPrefix,
        length: _selectedLength,
        type: _selectedType,
        count: countValue,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate passwords.')),
      );
      return;
    }

    if (passwords.isEmpty) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to generate unique passwords.')),
      );
      return;
    }

    // ✅ MIKROTIK MEIN USERS CREATE KARO
    int createdCount = 0;
    int failedCount = 0;
    final totalCount = passwords.length;

    for (var i = 0; i < passwords.length; i++) {
      final password = passwords[i];
      // ✅ USERNAME = PASSWORD (JAISE WHATSAPP MEIN HAI)
      final username = password;

      // ✅ LIVE COUNTER UPDATE
      _updateLoadingStatus('Creating users in MikroTik... (${i + 1}/$totalCount)');
      // Force dialog to rebuild
      if (mounted) {
        setState(() {});
      }

      final success = await MikroTikService.createHotspotUser(
        username: username,
        password: password,
        comment: 'Generated from PDF',
        profile: _selectedProfile,
      );

      if (success) {
        createdCount++;
      } else {
        failedCount++;
      }
    }

    if (failedCount > 0) {
      print('⚠️ $failedCount users failed to create');
    }

    // Close loading dialog
    if (mounted) {
      Navigator.pop(context);
      setState(() => _isLoading = false);
    }

    if (createdCount == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create any users in MikroTik.')),
      );
      return;
    }

    // ✅ DIALOG DIKHAO — SHARE YA SAVE
    _showGenerateOptionsDialog(
      passwords: passwords,
      createdCount: createdCount,
    );
  }
  // ✅ LOADING DIALOG WITH STATUS
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  _loadingStatus,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  void _updateLoadingStatus(String status) {
    _loadingStatus = status;
    // Dialog update karne ke liye setState call karo
    if (mounted) {
      setState(() {});
    }
  }

  // ✅ NEW METHOD: DIALOG FOR SHARE / SAVE
  void _showGenerateOptionsDialog({
    required List<String> passwords,
    required int createdCount,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('✅ Passwords Generated!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$createdCount users created in MikroTik.'),
            const SizedBox(height: 8),
            const Text('What would you like to do with the PDF?'),
          ],
        ),
        actions: [
          // BUTTON 1: SHARE
          ElevatedButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('Share'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _sharePdf(passwords: passwords);
            },
          ),
          // BUTTON 2: SAVE TO DEVICE
          ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Save to Device'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _savePdfToDevice(passwords: passwords);
            },
          ),
        ],
      ),
    );
  }

  // ✅ SHARE METHOD (EXISTING FUNCTIONALITY)
  Future<void> _sharePdf({required List<String> passwords}) async {
    setState(() => _isLoading = true);

    try {
      await PasswordExportService.generateAndSharePdf(
        profile: _selectedProfile,
        characterType: _selectedType,
        passwordLength: _selectedLength,
        passwordCount: passwords.length,
        prefix: _selectedPrefix,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF shared successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ SAVE TO DEVICE METHOD (NEW)
    // ✅ SAVE TO DEVICE METHOD (WITH FOLDER PICKER)
  Future<void> _savePdfToDevice({required List<String> passwords}) async {
    setState(() => _isLoading = true);

    try {
      // ✅ FOLDER PICKER — USER SELECT KAREGA KAHAN SAVE KARNA HAI
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select folder to save PDF',
      );

      if (selectedDirectory == null) {
        // User cancelled folder selection
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Save cancelled.')),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      // ✅ PDF GENERATE KARO
      final document = PdfDocument();
      final now = DateTime.now().toLocal();
      final pdfFont = PdfStandardFont(PdfFontFamily.helvetica, 11);
      final pdfBoldFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
      final pdfTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);

      const margin = 28.0;
      const cardWidth = 250.0;
      const cardHeight = 95.0;
      const horizontalGap = 18.0;
      const verticalGap = 16.0;
      const cardsPerRow = 2;
      const cardsPerPage = 24;

      var pageIndex = 0;
      var currentPage = document.pages.add();

      void drawPageHeader(PdfPage page) {
        page.graphics.drawString(
          'Password List',
          pdfTitleFont,
          bounds: const Rect.fromLTWH(28, 24, 500, 24),
        );
        page.graphics.drawString(
          'Profile: $_selectedProfile',
          pdfFont,
          bounds: const Rect.fromLTWH(28, 54, 500, 16),
        );
        page.graphics.drawString(
          'Generated: ${_formatDate(now)}  ${_formatTime(now)}',
          pdfFont,
          bounds: const Rect.fromLTWH(28, 72, 500, 16),
        );
      }

      void drawVoucherCard({
        required PdfPage page,
        required double x,
        required double y,
        required int serialNumber,
        required String password,
      }) {
        final borderBounds = Rect.fromLTWH(x, y, cardWidth, cardHeight);
        page.graphics.drawRectangle(
          bounds: borderBounds,
          pen: PdfPen(PdfColor(120, 120, 120)),
        );

        final voucherCode = password.length > 5 ? password.substring(0, 5) : password;
        final phoneNumber = '0552567451';

        page.graphics.drawString(
          '[$serialNumber] $phoneNumber',
          pdfBoldFont,
          bounds: Rect.fromLTWH(x + 10, y + 8, cardWidth - 20, 18),
        );
        page.graphics.drawString(
          'Kode Voucher',
          pdfFont,
          bounds: Rect.fromLTWH(x + 10, y + 30, cardWidth - 20, 18),
        );
        page.graphics.drawString(
          voucherCode,
          pdfBoldFont,
          bounds: Rect.fromLTWH(x + 10, y + 48, cardWidth - 20, 24),
        );
        page.graphics.drawString(
          '34d aed 20.00',
          pdfFont,
          bounds: Rect.fromLTWH(x + 10, y + 74, cardWidth - 20, 18),
        );
      }

      drawPageHeader(currentPage);

      for (var i = 0; i < passwords.length; i++) {
        final pageOffset = i % cardsPerPage;
        if (pageOffset == 0 && i > 0) {
          pageIndex += 1;
          currentPage = document.pages.add();
          drawPageHeader(currentPage);
        }

        final cardIndexInPage = i % cardsPerPage;
        final row = cardIndexInPage ~/ cardsPerRow;
        final column = cardIndexInPage % cardsPerRow;
        final x = margin + (column * (cardWidth + horizontalGap));
        final y = 100.0 + (row * (cardHeight + verticalGap));

        drawVoucherCard(
          page: currentPage,
          x: x,
          y: y,
          serialNumber: i + 1,
          password: passwords[i],
        );
      }

      final bytes = await document.save();
      document.dispose();

      // ✅ USER SELECTED FOLDER MEIN SAVE KARO
      final fileName = 'Password_List_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('$selectedDirectory/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ PDF saved to: $selectedDirectory/$fileName'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // ✅ HELPER METHODS (DATE/TIME FORMAT)
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
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
        builder: (context) => PasswordManagerScreen(
  campName: widget.campName,
),

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

    // ACTIVE USERS refresh
    if (!_isLoadingSavedUsers) {
      _loadSavedUsersCount();
    }
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
  initialValue: _selectedPrefix,   // ⭐ yahan change
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
  initialValue: _selectedLength,   // ⭐ yahan change
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
  initialValue: _selectedType,     // ⭐ yahan change
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
            

            
            const SizedBox(height: 16),
            
            // ✅ PASSWORD COUNT
            const Text(
              'Password Count',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordCountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Count',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Required';
                }
                final parsed = int.tryParse(value.trim());
                if (parsed == null || parsed <= 0) {
                  return 'Must be greater than zero';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Generate PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _isLoading ? null : _generatePdf,
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