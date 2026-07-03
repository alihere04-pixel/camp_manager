import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/mikrotik_service.dart';

class PasswordManagerScreen extends StatefulWidget {
  final String campName;

  const PasswordManagerScreen({super.key, required this.campName});

  @override
  State<PasswordManagerScreen> createState() =>
      _PasswordManagerScreenState();
}

class _PasswordManagerScreenState
    extends State<PasswordManagerScreen> {
  List<Map<String, dynamic>> _allPasswords = [];
  List<Map<String, dynamic>> _filteredPasswords = [];
  List<Map<String, dynamic>> _cachedPasswords = [];

  List<String> _profiles = [];

  String _selectedProfile = 'all';
  String _searchQuery = '';

  bool _isLoading = true;
  bool _isOffline = false;

  bool _selectionMode = false;
  List<String> _selectedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _savePasswordsLocally() async {
    final prefs = await SharedPreferences.getInstance();
    for (var p in _allPasswords) {
  p['campName'] = widget.campName;
}

    await prefs.setString(
      'saved_passwords',
      jsonEncode(_allPasswords),
    );
  }

  Future<void> _loadPasswordsLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('saved_passwords');

    if (data != null && data.isNotEmpty) {
      final List decoded = jsonDecode(data);
      _cachedPasswords = decoded
    .map((e) => Map<String, dynamic>.from(e))
    .toList();

// ⭐ CAMP FILTER
_cachedPasswords = _cachedPasswords.where((p) {
  return p['campName'] == widget.campName;
}).toList();

_allPasswords = List.from(_cachedPasswords);

    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _isOffline = false;
      _selectionMode = false;
      _selectedUsers.clear();
    });

    // local load first
    await _loadPasswordsLocally();

    if (_allPasswords.isNotEmpty) {
      _applyFilters();
    }

    try {
      try {
        _profiles = await MikroTikService.getProfiles();
        if (!_profiles.contains('default')) {
          _profiles.insert(0, 'default');
        }
      } catch (e) {
        // silently ignore offline error
      }

      final fresh = await MikroTikService.getAvailablePasswords();

      if (fresh.isNotEmpty) {
        final deleted = _cachedPasswords
            .where((oldUser) =>
                !fresh.any((newUser) => newUser['name'] == oldUser['name']))
            .toList();

        _allPasswords = fresh;
for (var p in _allPasswords) {
  p['campName'] = widget.campName; // add campName manually
}

        // ⭐ Only remove deleted users when online
if (!_isOffline) {
  _allPasswords.removeWhere(
      (user) => deleted.any((d) => d['name'] == user['name']));
}


        _cachedPasswords = List.from(_allPasswords);
        await _savePasswordsLocally();
        _applyFilters();
        _isOffline = false;
      } else {
        if (_cachedPasswords.isNotEmpty) {
          _allPasswords = List.from(_cachedPasswords);
          _applyFilters();
          _isOffline = true;
        }
      }
    } catch (e) {
  _isOffline = true;

  // ⭐ Always show cached data if available
  if (_cachedPasswords.isNotEmpty) {
    _allPasswords = List.from(_cachedPasswords);
    _applyFilters();
  } else {
    // ⭐ Do NOT clear lists — keep old data
    // _allPasswords = [];
    // _filteredPasswords = [];
  }

  setState(() {
    _isLoading = false;
  });
  return;
}


    setState(() {
      _isLoading = false;
    });
  }

  void _applyFilters() {
    var data = List<Map<String, dynamic>>.from(_allPasswords);

    if (_selectedProfile != 'all') {
      data = data.where((user) {
        return user['profile'] == _selectedProfile;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      data = data.where((user) {
        final name = user['name'].toString().toLowerCase();
        return name.contains(q);
      }).toList();
    }

    setState(() {
      _filteredPasswords = data;
    });
  }

  Future<void> _copyPassword(String password) async {
    await Clipboard.setData(
      ClipboardData(text: password),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '✅ Password copied to clipboard',
        ),
      ),
    );
  }

  Future<void> _deletePassword(String username) async {
    if (_isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '❌ Offline mode. Cannot delete',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Password'),
          content: Text(
            'Delete "$username"?\n'
            'It will also delete from MikroTik.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    final success = await MikroTikService.deleteHotspotUser(username);

    if (success) {
      setState(() {
        _allPasswords.removeWhere((user) => user['name'] == username);
        _cachedPasswords.removeWhere((user) => user['name'] == username);
        _filteredPasswords.removeWhere((user) => user['name'] == username);
      });

      await _savePasswordsLocally();
      _cachedPasswords = List.from(_allPasswords);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Delete failed'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _deleteSelectedUsers() async {
    if (_isOffline) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Offline mode. Cannot delete'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedUsers.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Users'),
        content: Text(
          'Are you sure you want to delete ${_selectedUsers.length} user(s)?\nThis will also remove them from MikroTik.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    int deletedCount = 0;
    int failedCount = 0;

    for (final username in List.from(_selectedUsers)) {
      final success = await MikroTikService.deleteHotspotUser(username);

      if (success) {
        _allPasswords.removeWhere((e) => e['name'] == username);
        _cachedPasswords.removeWhere((e) => e['name'] == username);
        _filteredPasswords.removeWhere((e) => e['name'] == username);
        deletedCount++;
      } else {
        failedCount++;
      }
    }

    _selectedUsers.clear();
    _selectionMode = false;
    await _savePasswordsLocally();

    setState(() => _isLoading = false);

    if (failedCount == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $deletedCount user(s) deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ $deletedCount deleted, $failedCount failed'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectionMode
              ? '${_selectedUsers.length} Selected'
              : 'Password Manager',
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: () {
                setState(() {
                  final allSelected = _filteredPasswords.isNotEmpty &&
                      _selectedUsers.length == _filteredPasswords.length;

                  if (allSelected) {
                    _selectedUsers.clear();
                  } else {
                    _selectedUsers = _filteredPasswords
                        .map((e) => e['name'].toString())
                        .toList();
                    _selectionMode = true;
                  }
                });
              },
            ),

          if (_selectionMode)
            IconButton(
              icon: const Icon(
                Icons.delete,
                color: Colors.red,
              ),
              onPressed: () async {
                await _deleteSelectedUsers();
              },
            ),

          if (_isOffline)
            Padding(
              padding: const EdgeInsets.all(8),
              child: const Center(
                child: Text(
                  'Offline',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          // ⭐ CHANGE 1: REFRESH ICON HATAYA
          // IconButton removed

        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search passwords...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _applyFilters();
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                _searchQuery = value;
                _applyFilters();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedProfile,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All Profiles'),
                          ),
                          ..._profiles.map((profile) {
                            return DropdownMenuItem(
                              value: profile,
                              child: Text(profile),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedProfile = value!;
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_filteredPasswords.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ⭐ CHANGE 2: PULL-TO-REFRESH ADD KIYA
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPasswords.isEmpty
                    ? const Center(child: Text('No passwords found'))
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredPasswords.length,
                          itemBuilder: (context, index) {
                            final user = _filteredPasswords[index];
                            final username = user['name'] ?? 'Unknown';
                            final password = user['password'] ?? 'N/A';
                            final profile = user['profile'] ?? 'default';

                            return Card(
                              child: ListTile(
                                onLongPress: () {
                                  setState(() {
                                    _selectionMode = true;
                                    if (!_selectedUsers.contains(username)) {
                                      _selectedUsers.add(username);
                                    }
                                  });
                                },

                                leading: _selectionMode
                                    ? Checkbox(
                                        value: _selectedUsers.contains(username),
                                        onChanged: (value) {
                                          setState(() {
                                            if (value == true) {
                                              _selectedUsers.add(username);
                                            } else {
                                              _selectedUsers.remove(username);
                                              if (_selectedUsers.isEmpty) {
                                                _selectionMode = false;
                                              }
                                            }
                                          });
                                        },
                                      )
                                    : null,

                                // ⭐ CHANGE 3: USERNAME HATAYA, SIRF PASSWORD + PROFILE
                                title: Text(
                                  password,
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  profile,
                                  style: const TextStyle(
                                    color: Colors.indigo,
                                  ),
                                ),

                                // ⭐ CHANGE 4: DELETE ICON HATAYA, SIRF COPY RAKHA
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.copy,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () =>
                                          _copyPassword(password),
                                    ),
                                    // ❌ Delete icon removed
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}