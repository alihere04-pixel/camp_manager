import 'package:flutter/material.dart';
import '../database/hive_database.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';
import '../services/whatsapp_service.dart';


class RoomDetailScreen extends StatefulWidget {
  final Room room;
  
  const RoomDetailScreen({super.key, required this.room});

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  late Room _room;
  Set<String> _selectedUserIds = {};
  bool _isSelectionMode = false;
  
  
  int _currentIndex = 0;
  List<User> _queueUsers = [];
  bool _isQueueActive = false;

  @override
  void initState() {
    super.initState();
    _room = widget.room;
  }

  // ============ SELECTION MODE FUNCTIONS ============
  
  void _toggleUserSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
      _isSelectionMode = _selectedUserIds.isNotEmpty;
    });
  }

  void _selectAllUsers() {
    final roomBox = HiveDatabase.getRoomsBox();
    final freshRoom = roomBox.get(_room.id);
    if (freshRoom == null) return;
    setState(() {
      _selectedUserIds = freshRoom.users.map((u) => u.id).toSet();
      _isSelectionMode = true;
    });
  }

  void _deselectAllUsers() {
    setState(() {
      _selectedUserIds.clear();
      _isSelectionMode = false;
    });
  }

  void _resetSelectionMode() {
    setState(() {
      _selectedUserIds.clear();
      _isSelectionMode = false;
    });
  }

  void _resetQueue() {
    setState(() {
      _isQueueActive = false;
      _queueUsers = [];
      _currentIndex = 0;
    });
  }

  // ✅ REFRESH ROOM - FIXED (async)
  Future<void> _refreshRoom() async {
    
    
    final roomBox = HiveDatabase.getRoomsBox();
    final freshRoom = roomBox.get(_room.id);
    
    if (freshRoom == null) {
      
      return;
    }
    
    final userBox = HiveDatabase.getUsersBox();
    final freshUsers = <User>[];
    
    for (var user in freshRoom.users) {
      final freshUser = userBox.get(user.id);
      if (freshUser != null) {
        freshUsers.add(freshUser);
      }
    }
    
    final updatedRoom = freshRoom.copyWith(users: freshUsers);
    updatedRoom.isFullyPaid = updatedRoom.allUsersPaid;
    
    // ✅ FORCE UPDATE
    await roomBox.put(updatedRoom.id, updatedRoom);
    
    if (mounted) {
      setState(() {
        _room = updatedRoom;
      });
    }
  }
Future<void> _toggleActiveStatus() async {
  if (_selectedUserIds.length != 1) return;

  final userId = _selectedUserIds.first;
  final user = _room.users.firstWhere((u) => u.id == userId);

  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(user.isActive ? 'Mark Inactive' : 'Mark Active'),
      content: Text(
        user.isActive
            ? 'Do you want to mark ${user.name} as INACTIVE?'
            : 'Do you want to mark ${user.name} as ACTIVE?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            user.isActive ? 'Mark Inactive' : 'Mark Active',
            style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  final userBox = HiveDatabase.getUsersBox();
  final existingUser = userBox.get(user.id);

  if (existingUser != null) {
    final updatedUser = existingUser.copyWith(
      isActive: !existingUser.isActive,
      updatedAt: DateTime.now(),
    );
    await userBox.put(updatedUser.id, updatedUser);
    await _refreshRoom();
  }
}


  Future<void> _editSelectedUser() async {
    if (_selectedUserIds.length != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select only one user to edit')),
      );
      return;
    }
    
    final userId = _selectedUserIds.first;
    final user = _room.users.firstWhere((u) => u.id == userId);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _UserFormDialog(roomId: _room.id, user: user),
    );
    
    if (result == true) {
      await _refreshRoom();
      _resetSelectionMode();
    }
  }

  Future<void> _deleteSelectedUsers() async {
    if (_selectedUserIds.isEmpty) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Users'),
        content: Text('Are you sure you want to delete ${_selectedUserIds.length} user(s)?'),
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
    
    if (confirm == true) {
      final userBox = HiveDatabase.getUsersBox();
      final roomBox = HiveDatabase.getRoomsBox();
      final deletedCount = _selectedUserIds.length;

      for (final userId in _selectedUserIds) {
        await userBox.delete(userId);
      }

      final updatedUsers = _room.users
          .where((u) => !_selectedUserIds.contains(u.id))
          .toList();

      final updatedRoom = _room.copyWith(users: updatedUsers);
      updatedRoom.isFullyPaid = updatedRoom.allUsersPaid;
      await roomBox.put(updatedRoom.id, updatedRoom);

      await _refreshRoom();
_resetSelectionMode();

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('$deletedCount user(s) deleted')),
);
    }
  }

  // ============ USER CRUD ============

  void _addUser() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _UserFormDialog(roomId: _room.id),
    );
    if (result == true) {
      await _refreshRoom();
    }
  }

  Future<void> _toggleUserPaid(User user) async {
    final userBox = HiveDatabase.getUsersBox();
    final roomBox = HiveDatabase.getRoomsBox();

    final existingUser = userBox.get(user.id);
    if (existingUser != null) {
      final updatedUser = existingUser.copyWith(isPaid: !existingUser.isPaid);
      await userBox.put(updatedUser.id, updatedUser);
    }

    final freshRoom = roomBox.get(_room.id);
    if (freshRoom != null) {
      final updatedUsers = freshRoom.users.map((u) {
        return userBox.get(u.id) ?? u;
      }).toList();
      final updatedRoom = freshRoom.copyWith(users: updatedUsers);
      updatedRoom.isFullyPaid = updatedRoom.allUsersPaid;
      await roomBox.put(updatedRoom.id, updatedRoom);
      setState(() {
        _room = updatedRoom;
      });
    }
  }

 Future<void> _sendUserPassword(User user) async {
  if (!user.isActive) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Inactive user — cannot send password')),
    );
    return;
  }
  // ⭐ Direct send — no comment dialog
  final result = await WhatsAppService.sendPasswordToUser(user);

  // ⭐ Mark as sent (icon blue)
  final userBox = HiveDatabase.getUsersBox();
  final existingUser = userBox.get(user.id);

  if (existingUser != null) {
    final updatedUser = existingUser.copyWith(
      isSentMarked: true,        // ⭐ Always mark sent
      updatedAt: DateTime.now(),
    );

    await userBox.put(updatedUser.id, updatedUser);
    await _refreshRoom();

    // ⭐ AUTO UPDATE ROOM SEND STATUS (INDIVIDUAL)
    final roomBox = HiveDatabase.getRoomsBox();
    final freshRoom = roomBox.get(_room.id);

    if (freshRoom != null) {
      final allSent = freshRoom.users.every((u) => u.isSentMarked);
      final updatedRoom = freshRoom.copyWith(allUsersSent: allSent);
      await roomBox.put(updatedRoom.id, updatedRoom);

      if (mounted) {
        setState(() => _room = updatedRoom);
      }
    }
  }

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        result['success'] == true
            ? '✅ Password sent to ${user.name}!'
            : '❌ ${result['message'] ?? "Failed to send"}',
      ),
    ),
  );
}

Future<void> _editUserComment() async {
  if (_selectedUserIds.length != 1) return;

  final userId = _selectedUserIds.first;
  final user = _room.users.firstWhere((u) => u.id == userId);

  final controller = TextEditingController(text: user.comment ?? '');

  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Edit Comment for ${user.name}'),
      content: TextField(
        controller: controller,
        maxLines: 3,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText: 'Write comment...',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  final userBox = HiveDatabase.getUsersBox();
  final existingUser = userBox.get(user.id);

  if (existingUser != null) {
    final updatedUser = existingUser.copyWith(
      comment: controller.text.trim(),
      updatedAt: DateTime.now(),
    );
    await userBox.put(updatedUser.id, updatedUser);
    await _refreshRoom();
  }
}
Future<void> _removeUserComment() async {
  if (_selectedUserIds.length != 1) return;

  final userId = _selectedUserIds.first;
  final user = _room.users.firstWhere((u) => u.id == userId);

  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remove Comment'),
      content: Text('Delete comment for ${user.name}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  final userBox = HiveDatabase.getUsersBox();
  final existingUser = userBox.get(user.id);

  if (existingUser != null) {
    final updatedUser = existingUser.copyWith(
      comment: '',
      updatedAt: DateTime.now(),
    );
    await userBox.put(updatedUser.id, updatedUser);
    await _refreshRoom();
  }
}


  void _openCurrentUser() async {
    if (!mounted) return;

    if (_currentIndex >= _queueUsers.length) {
      _resetQueue();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ All users processed')),
        );
      }
      return;
    }

    final user = _queueUsers[_currentIndex];
    final bool isLastUser = (_currentIndex + 1) >= _queueUsers.length;

    // ⭐ INACTIVE USER KO SKIP KARO
    if (!user.isActive) {
      _currentIndex++;
      _openCurrentUser();
      return;
    }

    if (user.voucherCode == null || user.voucherCode!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ ${user.name} has no password! Skipping...')),
        );
      }
      _currentIndex++;
      _openCurrentUser();
      return;
    }

    await WhatsAppService.sendPasswordToUser(user);

    if (isLastUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _resetQueue();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Queue Finished! All users processed.')),
          );
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  Future<void> _nextUser() async {
    if (!mounted) return;
    
    _currentIndex++;
    

    if (_currentIndex >= _queueUsers.length) {
  _resetQueue();
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Queue Finished!')),
    );

    // ⭐ AUTO UPDATE ROOM SEND STATUS (BULK QUEUE)
    final roomBox = HiveDatabase.getRoomsBox();
    final userBox = HiveDatabase.getUsersBox();
    final freshRoom = roomBox.get(_room.id);

    if (freshRoom != null) {
      // ⭐ REFRESH USERS FROM DATABASE
      final refreshedUsers = freshRoom.users.map((u) {
        return userBox.get(u.id) ?? u;
      }).toList();

      // ⭐ CHECK IF ALL USERS ARE SENT
      final allSent = refreshedUsers.every((u) => u.isSentMarked);

      // ⭐ UPDATE ROOM STATUS
      final updatedRoom = freshRoom.copyWith(
        users: refreshedUsers,
        allUsersSent: allSent,
      );

      await roomBox.put(updatedRoom.id, updatedRoom);

      setState(() => _room = updatedRoom);
    }
  }
  return;
}


    setState(() {});
    _openCurrentUser();
  }

  Future<void> _sendAllPasswords() async {
    final roomBox = HiveDatabase.getRoomsBox();
    final freshRoom = roomBox.get(_room.id);

    if (freshRoom == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room not found!')),
        );
      }
      return;
    }

    final userBox = HiveDatabase.getUsersBox();

    final users = freshRoom.users
        .map((u) => userBox.get(u.id))
        .where((u) => u != null)
        .cast<User>()
        .toList();

    final sourceUsers = _isSelectionMode && _selectedUserIds.isNotEmpty
        ? users.where((u) => _selectedUserIds.contains(u.id)).toList()
        : users;

    // ⭐ INACTIVE USERS KO QUEUE SE HATAO
    final activeUsers = sourceUsers.where((u) => u.isActive).toList();

    if (!mounted) return;

    setState(() {
      _queueUsers = activeUsers;
      _currentIndex = 0;
      _isQueueActive = _queueUsers.isNotEmpty;
    });

    if (_queueUsers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active users to process')),
        );
      }
      return;
    }

    _openCurrentUser();
  }

  // ============ AMOUNT FUNCTIONS ============

  double _getCollectedAmount() {
    double total = 0;
    for (var user in _room.users) {
      if (user.isPaid && user.isActive) {
        total += user.amount;
      }
    }
    return total;
  }

  double _getTotalAmount() {
    double total = 0;
    for (var user in _room.users) {
      if (user.isActive) {
        total += user.amount;
      }
    }
    return total;
  }

  double _getRemainingAmount() {
    return _getTotalAmount() - _getCollectedAmount();
  }

  // ============ BUILD METHODS ============

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _resetQueue();
        _resetSelectionMode();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isQueueActive
                ? '${_room.roomNumber} (${_currentIndex + 1}/${_queueUsers.length})'
                : _room.roomNumber,
          ),
          actions: [
            if (_isSelectionMode) ...[
              IconButton(
                icon: const Icon(Icons.select_all),
                onPressed: _selectAllUsers,
                tooltip: 'Select All',
              ),
              IconButton(
                icon: const Icon(Icons.deselect),
                onPressed: _deselectAllUsers,
                tooltip: 'Deselect All',
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _deleteSelectedUsers,
                tooltip: 'Delete Selected',
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _deselectAllUsers,
                tooltip: 'Cancel',
              ),
            ] else ...[
              if (_isQueueActive && _queueUsers.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: _nextUser,
                  tooltip:
                      'Next User (${_currentIndex + 1}/${_queueUsers.length})',
                ),
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: _isQueueActive ? null : _sendAllPasswords,
                tooltip: 'Start Queue',
              ),
            ],
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.indigo[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat(
                    'Users',
                    _room.users.where((u) => u.isActive).length.toString(),
                  ),
                  _buildStat(
                    'Pending',
                    (_room.users.where((u) => u.isActive).length -
                            _room.users
                                .where((u) => u.isActive && u.isPaid)
                                .length)
                        .toString(),
                  ),
                  _buildStat(
                    'Collected',
                    _getCollectedAmount().toStringAsFixed(0),
                  ),
                  _buildStat(
                    'Remaining',
                    _getRemainingAmount().toStringAsFixed(0),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _room.users.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No users in this room'),
                          Text('Tap + button to add occupants'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _room.users.length,
                      itemBuilder: (context, index) {
                        final user = _room.users[index];
                        return _buildUserCard(user);
                      },
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addUser,
          backgroundColor: Colors.indigo,
          elevation: 0,
          highlightElevation: 0,
          child: const Icon(Icons.person_add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
    // ⭐ Long press pe popup menu (right-click style)
  void _showUserActionsSheet(User user) {
    // Ek user ko select bhi kar dete hain, taake existing functions use ho saken
    setState(() {
      _selectedUserIds = {user.id};
      _isSelectionMode = true;
    });

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit User'),
                onTap: () {
                  Navigator.pop(context);
                  _editSelectedUser();
                },
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(
                  _room.users
                          .firstWhere((u) => u.id == user.id)
                          .isActive
                      ? 'Mark Inactive'
                      : 'Mark Active',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleActiveStatus();
                },
              ),
              ListTile(
                leading: const Icon(Icons.comment, color: Colors.blue),
                title: const Text('Edit Comment'),
                onTap: () {
                  Navigator.pop(context);
                  _editUserComment();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.orange),
                title: const Text('Remove Comment'),
                onTap: () {
                  Navigator.pop(context);
                  _removeUserComment();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete User'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteSelectedUsers();
                },
              ),
              ListTile(
                leading: const Icon(Icons.send),
                title: const Text('Send Password'),
                onTap: () {
                  Navigator.pop(context);
                  _sendUserPassword(user);
                },
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildUserCard(User user) {
    final isSelected = _selectedUserIds.contains(user.id);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected ? Colors.indigo[50] : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? const BorderSide(color: Colors.indigo, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        // ⭐ Long press → popup menu
        onLongPress: () {
          if (!user.isActive) return;
          _showUserActionsSheet(user);
        },
        onTap: () {
          if (!user.isActive) return;   // ⭐ INACTIVE → NO TAP
          if (_isSelectionMode) {
            // Selection mode ab sirf internal use ke liye hai
            _toggleUserSelection(user.id);
            return;
          }
          _toggleUserPaid(user);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (_isSelectionMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleUserSelection(user.id),
                ),
              GestureDetector(
                onTap: () {
                  if (!user.isActive) return;   // ⭐ FULL BLOCK
                  if (_isSelectionMode) return;
                  _toggleUserPaid(user);
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: user.isActive
                        ? (user.isPaid ? Colors.green : Colors.grey[300])
                        : Colors.grey[400],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      user.initial,
                      style: TextStyle(
                        color: user.isActive
                            ? (user.isPaid ? Colors.white : Colors.black54)
                            : Colors.black26,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      user.phoneNumber,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${user.passwordCount}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    Text(
                      user.amount.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    if (user.voucherCode != null && user.voucherCode!.isNotEmpty)
                      Text(
                        'Password: ${user.voucherCode}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.indigo,
                        ),
                      ),
                    if ((user.comment ?? '').isNotEmpty)
                      Text(
                        'Note: ${user.comment}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          user.isPaid ? Colors.green[100] : Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user.isPaid ? 'PAID' : 'PENDING',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: user.isPaid
                            ? Colors.green[800]
                            : Colors.orange[800],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.send,
                      color:
                          user.isSentMarked ? Colors.blue : Colors.green,
                    ),
                    onPressed:
                        user.isActive ? () => _sendUserPassword(user) : null,
                    tooltip: user.isSentMarked
                        ? 'Already Sent (tap to send again)'
                        : 'Send Password',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ USER FORM DIALOG ============

class _UserFormDialog extends StatefulWidget {
  final String roomId;
  final User? user;
  
  const _UserFormDialog({required this.roomId, this.user});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _passwordCountController;
  late TextEditingController _amountController;
  final FocusNode _nameFocusNode = FocusNode();
  bool _isPaid = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _phoneController = TextEditingController(text: widget.user?.phoneNumber ?? '');
    _passwordCountController = TextEditingController(
      text: (widget.user?.passwordCount ?? 1).toString()
    );
    _amountController = TextEditingController(
      text: widget.user?.amount.toStringAsFixed(2) ?? '20.00'
    );
    _isPaid = widget.user?.isPaid ?? false;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordCountController.dispose();
    _amountController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    final passwordCount = int.tryParse(_passwordCountController.text.trim()) ?? 1;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final now = DateTime.now();
    
    if (widget.user != null) {
      final userBox = HiveDatabase.getUsersBox();
      final existingUser = userBox.get(widget.user!.id);
      
      if (existingUser != null) {
        final updatedUser = existingUser.copyWith(
          name: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          isPaid: _isPaid,
          passwordCount: passwordCount,
          amount: amount,
          updatedAt: now,
        );
        await userBox.put(updatedUser.id, updatedUser);
        
      } else {
        
      }
    } else {
      final newUser = User(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        roomId: widget.roomId,
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        isPaid: _isPaid,
        passwordCount: passwordCount,
        amount: amount,
        createdAt: now,
        updatedAt: now,
      );
      await HiveDatabase.getUsersBox().put(newUser.id, newUser);
      
      
      final room = HiveDatabase.getRoomsBox().get(widget.roomId);
      if (room != null) {
        final updatedUsers = List<User>.from(room.users)..add(newUser);
        final updatedRoom = room.copyWith(
          users: updatedUsers,
          updatedAt: now,
        );
        await HiveDatabase.getRoomsBox().put(room.id, updatedRoom);
      }
    }
    
    setState(() => _isLoading = false);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.user != null ? 'Edit User' : 'Add User'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g., Ali Ahmed',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
  controller: _phoneController,
  decoration: const InputDecoration(
    labelText: 'WhatsApp Number (Optional)',
    hintText: 'e.g., 923001234567',
    border: OutlineInputBorder(),
  ),
  keyboardType: TextInputType.phone,
  // ✅ VALIDATOR HATAO - PHONE OPTIONAL
),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCountController,
                  decoration: const InputDecoration(
                    labelText: 'No. of Passwords',
                    hintText: '1, 2, 3...',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final count = int.tryParse(v);
                    if (count == null || count < 1 || count > 10) return '1-10 only';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount (AED)',
                    hintText: '20.00',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final amount = double.tryParse(v);
                    if (amount == null || amount < 0) return 'Enter valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Payment Status'),
                  subtitle: Text(_isPaid ? 'Paid' : 'Pending'),
                  value: _isPaid,
                  onChanged: (val) => setState(() => _isPaid = val),
                  activeThumbColor: Colors.green,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}