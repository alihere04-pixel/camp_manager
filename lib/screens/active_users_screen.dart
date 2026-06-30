import 'package:flutter/material.dart';
import '../services/mikrotik_service.dart';
import '../models/user_model.dart';
import '../database/hive_database.dart';
import 'active_users_only_screen.dart';
import 'user_details_screen.dart';


class ActiveUsersScreen extends StatefulWidget {
  const ActiveUsersScreen({super.key});

  @override
  State<ActiveUsersScreen> createState() => _ActiveUsersScreenState();
}

class _ActiveUsersScreenState extends State<ActiveUsersScreen> {
  List<Map<String, dynamic>> _activeUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  int _totalActiveUsers = 0;
  
  Set<String> _activeUsernames = {};

  // ✅ SELECTION MODE VARIABLES
  bool _isSelectionMode = false;
  Set<String> _selectedUserIds = {};
    // ✅ SEARCH BAR VARIABLES
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchMode = false;


  @override
  void initState() {
    super.initState();
    _loadActiveUsers();
  }

  Future<void> _loadActiveUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
     
      
      final allUsers = await MikroTikService.getUsedPasswords();    

      final usersWithMac = allUsers.where((user) {
        final mac = (user['mac-address'] ?? '').toString().trim();
        return mac.isNotEmpty;
      }).toList();
      
      // ✅ ACTIVE USERS FETCH KARO
      final activeUsers = await MikroTikService.getActiveUsers();
      _activeUsernames = activeUsers
          .map((u) => (u['name'] ?? u['user'] ?? '').toString())
          .where((name) => name.isNotEmpty)
          .toSet();
      
      

      if (usersWithMac.isEmpty) {
        
        if (mounted) {
          setState(() {
            _activeUsers = [];
            _filteredUsers = [];
            _totalActiveUsers = 0;
            _isLoading = false;
          });
        }
        return;
      }

      final userBox = HiveDatabase.getUsersBox();
      final localUsers = userBox.values.toList();
      
      final activeList = <Map<String, dynamic>>[];
      
      for (var mikrotikUser in usersWithMac) {
        final username = (mikrotikUser['name'] ?? '').toString();
        if (username.isEmpty) continue;
        
        final mac = (mikrotikUser['mac-address'] ?? '').toString();
        
        // ✅ CHECK KARO KE YEH USER ACTIVE HAI YA NAHI
        final isActive = _activeUsernames.contains(username);
        
        
        
        final matchingLocalUser = localUsers.firstWhere(
          (u) => u.voucherUsername == username || u.voucherCode == username,
          orElse: () => User(
            id: '',
            roomId: '',
            name: 'Unknown',
            phoneNumber: '',
            isPaid: false,
            passwordCount: 0,
            amount: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        
        activeList.add({
  'username': username,
  'macAddress': mac,
  'isActive': isActive,
  'localUser': matchingLocalUser,
  'localUserName': matchingLocalUser.name,

  // ⭐ ADD THIS LINE
  'profile': mikrotikUser['profile'] ??
             mikrotikUser['profile-name'] ??
             mikrotikUser['user-profile'] ??
             'default',
});

      }

      
      
      if (mounted) {
        setState(() {
          _activeUsers = activeList;
          _filteredUsers = activeList;  // ✅ SEARCH KE LIYE
          _totalActiveUsers = activeList.length;
          _isLoading = false;
        });
        
      }
      
    } catch (e) {
      
      if (mounted) {
        setState(() {
          _activeUsers = [];
          _filteredUsers = [];
          _totalActiveUsers = 0;
          _isLoading = false;
        });
      }
    }
  }

  

  void _searchUser(String query) {
  if (query.isEmpty) {
    setState(() {
      _filteredUsers = List.from(_activeUsers);
    });
    return;
  }
  
  final lowercaseQuery = query.toLowerCase().trim();
  final filtered = _activeUsers.where((user) {
    // ✅ USERNAME SE SEARCH
    final username = (user['username'] ?? '').toString().toLowerCase();
    // ✅ MAC ADDRESS SE SEARCH
    final mac = (user['macAddress'] ?? '').toString().toLowerCase();
    // ✅ LOCAL USER NAME SE SEARCH
    final localName = (user['localUserName'] ?? '').toString().toLowerCase();
    
    return username.contains(lowercaseQuery) ||
           mac.contains(lowercaseQuery) ||
           localName.contains(lowercaseQuery);
  }).toList();
  
  setState(() {
    _filteredUsers = filtered;
  });
}

  // ✅ EXIT SELECTION MODE
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedUserIds.clear();
    });
  }

  // ✅ DELETE SELECTED USERS
  Future<void> _deleteSelectedUsers() async {
    if (_selectedUserIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Users'),
        content: Text(
          'Delete ${_selectedUserIds.length} user(s) permanently?\n\nThis will also remove them from MikroTik.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );



   if (confirm != true) return;

int deleted = 0;
int failed = 0;

for (final username in _selectedUserIds) {
  try {
    final success = await MikroTikService.deleteHotspotUser(username);
    if (success) {
      deleted++;
    } else {
      failed++;
    }
  } catch (e) {
    failed++;
  }
}

if (!mounted) return;   // ⭐⭐ REAL FIX — yahi jagah sahi hai ⭐⭐

setState(() {
  _activeUsers.removeWhere((u) => _selectedUserIds.contains(u['username']));
  _filteredUsers.removeWhere((u) => _selectedUserIds.contains(u['username']));
  _totalActiveUsers = _activeUsers.length;
  _selectedUserIds.clear();
  _isSelectionMode = false;
});

ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('✅ $deleted deleted${failed > 0 ? ", $failed failed" : ""}'),
    backgroundColor: failed > 0 ? Colors.orange : Colors.green,
  ),
);

  }

  @override
  Widget build(BuildContext context) {
    
    
    return Scaffold(
            appBar: AppBar(
        title: _isSearchMode
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search by Username, MAC or Name...',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  _searchUser(value);
                },
              )
            : const Text('Saved Users'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.indigo[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_totalActiveUsers',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[800],
                  ),
                ),
              ),
            ),
          ),
          if (_isSelectionMode) ...[
            IconButton(
              icon: Icon(
                _selectedUserIds.length == _filteredUsers.length
                    ? Icons.deselect
                    : Icons.select_all,
              ),
              onPressed: () {
                setState(() {
                  if (_selectedUserIds.length == _filteredUsers.length) {
                    _selectedUserIds.clear();
                  } else {
                    _selectedUserIds = _filteredUsers
                        .map((u) => u['username'].toString())
                        .toSet();
                  }
                });
              },
              tooltip: 'Select All',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _selectedUserIds.isEmpty ? null : _deleteSelectedUsers,
              tooltip: 'Delete Selected',
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _exitSelectionMode,
              tooltip: 'Cancel',
            ),
          ] else ...[
            IconButton(
              icon: Icon(_isSearchMode ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  if (_isSearchMode) {
                    _isSearchMode = false;
                    _searchController.clear();
                    _searchUser('');
                  } else {
                    _isSearchMode = true;
                  }
                });
              },
              tooltip: _isSearchMode ? 'Close Search' : 'Search',
            ),
          ],
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _loadActiveUsers,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // ✅ ACTIVE COUNT CARD (CLICKABLE)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: InkWell(
                      onTap: () async {
                        await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const ActiveUsersOnlyScreen(),
  ),
);

if (!mounted) return;   // ⭐ FIX

_loadActiveUsers();

                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Card(
                        color: Colors.green[50],
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.green,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_activeUsernames.length} users currently active',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.green,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // ✅ USERS LIST
                  Expanded(
                    child: _filteredUsers.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_off, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'No Saved Users',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'No users with saved MAC addresses',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredUsers.length,
                            itemBuilder: (context, index) {
                              

                              final user = _filteredUsers[index];
                              return Card(
  margin: const EdgeInsets.only(bottom: 8),
  child: ListTile(
    // ✅ LONG PRESS = SELECTION MODE
    onLongPress: () {
      setState(() {
        _isSelectionMode = true;
        _selectedUserIds.add(user['username'].toString());
      });
    },
   onTap: () {
  if (_isSelectionMode) {
    setState(() {
      final username = user['username'].toString();
      if (_selectedUserIds.contains(username)) {
        _selectedUserIds.remove(username);
        if (_selectedUserIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedUserIds.add(username);
      }
    });
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserDetailsScreen(
          username: user['username'],
          password: user['localUser']?.voucherCode ?? user['username'],
          mac: user['macAddress'],
          profile: user['profile'],
        ),
      ),
    );
  }
},

    leading: _isSelectionMode
        ? Checkbox(
            value: _selectedUserIds.contains(user['username'].toString()),
            onChanged: (_) {
              setState(() {
                final username = user['username'].toString();
                if (_selectedUserIds.contains(username)) {
                  _selectedUserIds.remove(username);
                  if (_selectedUserIds.isEmpty) {
                    _isSelectionMode = false;
                  }
                } else {
                  _selectedUserIds.add(username);
                }
              });
            },
          )
        : CircleAvatar(
            backgroundColor: Colors.green[100],
            child: Text(
              (user['username']?.isNotEmpty == true)
                  ? user['username'][0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
    title: Text(
      user['username'] ?? 'Unknown',
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),
    subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('MAC: ${user['macAddress'] ?? 'N/A'}'),

    if (user['localUserName'] != 'Unknown' && user['localUserName'] != '')
      Text(
        'Local User: ${user['localUserName']}',
        style: const TextStyle(color: Colors.indigo),
      ),

    // ⭐ NEW LINE — PROFILE SHOW
   Text(
  '${user['profile'] ?? 'default'}',
  style: const TextStyle(color: Colors.deepPurple),
),

  ],
),

    trailing: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: user['isActive'] == true 
            ? Colors.green[100]   // ✅ ACTIVE = GREEN
            : Colors.indigo[100], // ✅ SAVED = INDIGO
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        user['isActive'] == true ? 'ACTIVE' : 'SAVED',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: user['isActive'] == true 
              ? Colors.green[800] 
              : Colors.indigo[800],
        ),
      ),
    ),
  ),
);
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
    @override
  void dispose() {
    _searchController.dispose();   // ⭐ YEH LINE YAHAN
    super.dispose();
  }
}