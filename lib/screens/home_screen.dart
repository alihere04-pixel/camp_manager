import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../database/hive_database.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';
import '../services/whatsapp_service.dart';

import 'add_room_screen.dart';
import 'room_detail_screen.dart';
import 'mikrotik_settings_screen.dart'; 
import 'monthly_summary_screen.dart';  
import '../services/mikrotik_service.dart'; 
import '../services/settings_service.dart'; 

 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
bool _isMikroTikConnected = false;  // ✅ ADD
  Set<String> _selectedRoomIds = {};
  bool _isSelectionMode = false;
  
  // ✅ SEARCH VARIABLES
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  // ✅ MONTH VARIABLES
  DateTime _currentMonth = DateTime.now();

  @override
void initState() {
  super.initState();
  _tabController = TabController(length: 4, vsync: this);
  
  _tabController.addListener(() {
    if (mounted) {
      setState(() {});
    }
  });
  
  // ✅ SAVED STATUS LOAD KARO (FAST)
  _isMikroTikConnected = SettingsService.mikrotikConnected;


}

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
@override
void didChangeDependencies() {
  super.didChangeDependencies();

  _refreshMikroTikIndicator();
}


Future<void> _refreshMikroTikIndicator() async {

  final status = SettingsService.mikrotikConnected;

  if(mounted){
    setState(() {
      _isMikroTikConnected = status;
    });
  }
}


  // ✅ MONTH DISPLAY FUNCTIONS
  String _getMonthDisplay() {
    return _getMonthName(_currentMonth.month);
  }

  String _getMonthName(int month) {
    final safeMonth = ((month - 1) % 12) + 1;
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[safeMonth - 1];
  }

  // ✅ COUNT FUNCTIONS
  int _getRoomCount() {
    final allRooms = HiveDatabase.getRoomsBox().values.toList();
    final currentMonthRooms = allRooms.where((room) {
      return room.month == _currentMonth.month && 
             room.year == _currentMonth.year;
    }).toList();
    return currentMonthRooms.length;
  }

  int _getUserCount() {
    final allRooms = HiveDatabase.getRoomsBox().values.toList();
    final currentMonthRooms = allRooms.where((room) {
      return room.month == _currentMonth.month && 
             room.year == _currentMonth.year;
    }).toList();
    int count = 0;
    for (var room in currentMonthRooms) {
      count += room.users.length;
    }
    return count;
  }

  int _getPaidCount() {
    final allRooms = HiveDatabase.getRoomsBox().values.toList();
    final currentMonthRooms = allRooms.where((room) {
      return room.month == _currentMonth.month && 
             room.year == _currentMonth.year;
    }).toList();
    return currentMonthRooms.where((r) => r.allUsersPaid).length;
  }

  int _getPendingCount() {
    final allRooms = HiveDatabase.getRoomsBox().values.toList();
    final currentMonthRooms = allRooms.where((room) {
      return room.month == _currentMonth.month && 
             room.year == _currentMonth.year;
    }).toList();
    return currentMonthRooms.where((r) => !r.allUsersPaid && r.users.isNotEmpty).length;
  }

  // ✅ BUILD TAB WITH COUNT
  Widget _buildTabWithCount(String label, int count) {
    return Tab(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: count > 0 ? Colors.indigo : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ SEARCH FILTER FUNCTION
  List<Room> _filterRoomsBySearch(List<Room> rooms) {
    if (_searchQuery.isEmpty) return rooms;
    return rooms.where((room) {
      return room.roomNumber.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  // ✅ SEARCH DIALOG FUNCTION
  void _openSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Room'),
        content: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter room number...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (value) {
            setState(() {
              _searchQuery = value;
            });
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _searchQuery = _searchController.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }
 Future<void> _checkMikroTikStatus() async {
  try {
    final connected = await MikroTikService.checkConnection();

    // Hive me latest status save karo
    await SettingsService.saveMikrotikConnected(connected);

    if (mounted) {
      setState(() {
        _isMikroTikConnected = connected;
      });
    }
  } catch (e) {

    await SettingsService.saveMikrotikConnected(false);

    if (mounted) {
      setState(() {
        _isMikroTikConnected = false;
      });
    }
  }
}

  // ✅ COPY TO NEXT MONTH FUNCTION
  Future<void> _copyToNextMonth() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copy to Next Month'),
        content: Text(
          'Copy all rooms and users from ${_getMonthDisplay()} to ${_getMonthName(_currentMonth.month + 1)} ${_currentMonth.year}?\n\n'
          'All users will be marked as UNPAID in the new month.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text('Copy'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() => _isLoading = true);
    
    try {
      final allRooms = HiveDatabase.getAllRooms();
      final usersBox = HiveDatabase.getUsersBox();
      final roomsBox = HiveDatabase.getRoomsBox();
      
      final currentRooms = allRooms.where((room) {
        return room.month == _currentMonth.month && 
               room.year == _currentMonth.year;
      }).toList();
      
      if (currentRooms.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No rooms to copy in current month!')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
      
      final nextMonth = _currentMonth.month == 12 ? 1 : _currentMonth.month + 1;
      final nextYear = _currentMonth.month == 12 ? _currentMonth.year + 1 : _currentMonth.year;
      
      final nextMonthRooms = allRooms.where((room) {
        return room.month == nextMonth && room.year == nextYear;
      }).toList();
      
      if (nextMonthRooms.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Rooms already exist in ${_getMonthName(nextMonth)} $nextYear!'),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
      
      int copiedRooms = 0;
      int copiedUsers = 0;
      
      for (final oldRoom in currentRooms) {
        final newRoomId = '${DateTime.now().millisecondsSinceEpoch}_${oldRoom.id}';
        
        final List<User> newUsers = [];
        
        for (final oldUser in oldRoom.users) {
          final newUserId = '${DateTime.now().millisecondsSinceEpoch}_${oldUser.id}';
          
          final newUser = User(
  id: newUserId,
  roomId: newRoomId,
  name: oldUser.name,
  phoneNumber: oldUser.phoneNumber,
  isPaid: false,
  passwordCount: oldUser.passwordCount,
  amount: oldUser.amount,  // ✅ AMOUNT COPY KARO
  voucherCode: null,
  voucherUsername: null,
  syncedWithMikrotik: false,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
          
          await usersBox.put(newUserId, newUser);
          newUsers.add(newUser);
          copiedUsers++;
        }
        
        final newRoom = Room(
          id: newRoomId,
          roomNumber: oldRoom.roomNumber,
          users: newUsers,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          month: nextMonth,
          year: nextYear,
        );
        
        await roomsBox.put(newRoomId, newRoom);
        copiedRooms++;
      }
      
      setState(() {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Copied $copiedRooms rooms and $copiedUsers users to ${_getMonthName(nextMonth)} $nextYear'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
    
    setState(() => _isLoading = false);
  }

  void _changeMonth(int direction) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + direction);
    });
  }

  // ✅ FILTER ROOMS BY MONTH
  List<Room> _filterRoomsByMonth(List<Room> rooms) {
    return rooms.where((room) {
      return room.month == _currentMonth.month && 
             room.year == _currentMonth.year;
    }).toList();
  }

  void _toggleRoomSelection(String roomId) {
    setState(() {
      if (_selectedRoomIds.contains(roomId)) {
        _selectedRoomIds.remove(roomId);
      } else {
        _selectedRoomIds.add(roomId);
      }
      _isSelectionMode = _selectedRoomIds.isNotEmpty;
    });
  }

  void _selectAllRooms() {
    setState(() {
      final rooms = HiveDatabase.getAllRooms();
      _selectedRoomIds = rooms.map((r) => r.id).toSet();
      _isSelectionMode = true;
    });
  }

  void _deselectAllRooms() {
    setState(() {
      _selectedRoomIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _editSelectedRoom() async {
    if (_selectedRoomIds.length != 1) return;

    final roomId = _selectedRoomIds.first;
    final room = HiveDatabase.getRoomsBox().get(roomId);

    if (room == null) return;

    final controller = TextEditingController(
      text: room.roomNumber,
    );

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Room Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Room Number',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      final updatedRoom = room.copyWith(
        roomNumber: newName,
      );

     await HiveDatabase.getRoomsBox().put(
  room.id,
  updatedRoom,
);

if (!mounted) return;

_deselectAllRooms();

ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Room renamed to $newName'),
  ),
);
    }
  }

  Future<void> _deleteSelectedRooms() async {
  if (_selectedRoomIds.isEmpty) return;

  // ✅ CHECK: Sirf current month ke rooms delete karo
  final roomsToDelete = <String>[];
  final roomsBox = HiveDatabase.getRoomsBox();
  
  for (final roomId in _selectedRoomIds) {
    final room = roomsBox.get(roomId);
    if (room != null && 
        room.month == _currentMonth.month && 
        room.year == _currentMonth.year) {
      roomsToDelete.add(roomId);
    }
  }

  if (roomsToDelete.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No rooms to delete in current month!'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Rooms'),
      content: Text(
        'Delete ${roomsToDelete.length} room(s) from ${_getMonthDisplay()}?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  final usersBox = HiveDatabase.getUsersBox();

  for (final roomId in roomsToDelete) {
    final users = usersBox.values
        .where((u) => u.roomId == roomId)
        .toList();

    for (final user in users) {
      await usersBox.delete(user.id);
    }

    await roomsBox.delete(roomId);
  }

  if (!mounted) return;
  
  _selectedRoomIds.clear();
  _isSelectionMode = false;
  setState(() {});

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('${roomsToDelete.length} room(s) deleted from ${_getMonthDisplay()}'),
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Room Billing',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: [
                  _buildTabWithCount('Rooms', _getRoomCount()),
                  _buildTabWithCount('Users', _getUserCount()),
                  _buildTabWithCount('Paid', _getPaidCount()),
                  _buildTabWithCount('Pending', _getPendingCount()),
                ],
                labelColor: Colors.indigo,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.indigo,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
  // ✅ MIKROTIK STATUS INDICATOR (SIRF CIRCLE, NO TEXT)
  Container(
    margin: const EdgeInsets.only(right: 8),
    child: Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _isMikroTikConnected ? Colors.green : Colors.red,
      ),
    ),
  ),
  if (_isSelectionMode) ...[
    if (_selectedRoomIds.length == 1)
      IconButton(
        icon: const Icon(Icons.edit),
        onPressed: _editSelectedRoom,
      ),
    IconButton(
      icon: const Icon(Icons.delete, color: Colors.red),
      onPressed: _deleteSelectedRooms,
    ),
    IconButton(
      icon: Icon(
        _selectedRoomIds.length == HiveDatabase.getAllRooms().length
            ? Icons.deselect
            : Icons.select_all,
      ),
      onPressed: _selectedRoomIds.length == HiveDatabase.getAllRooms().length
          ? _deselectAllRooms
          : _selectAllRooms,
    ),
    IconButton(
      icon: const Icon(Icons.close),
      onPressed: _deselectAllRooms,
    ),
  ] else ...[
    IconButton(
      icon: const Icon(Icons.search),
      onPressed: _openSearchDialog,
    ),
    PopupMenuButton<String>(
      icon: const Icon(Icons.settings),
      onSelected: (value) {
        if (value == 'mikrotik') {
          _showSettingsDialog();
        } else if (value == 'inventory') {
          _openInventory();
        } else if (value == 'summary') {
          _openMonthlySummary();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'mikrotik',
          child: Row(
            children: [
              Icon(Icons.settings, size: 20, color: Colors.indigo),
              SizedBox(width: 12),
              Text('MikroTik Settings'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'inventory',
          child: Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 20, color: Colors.teal),
              SizedBox(width: 12),
              Text('Voucher Inventory'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'summary',
          child: Row(
            children: [
              Icon(Icons.summarize, size: 20, color: Colors.orange),
              SizedBox(width: 12),
              Text('Monthly Summary'),
            ],
          ),
        ),
      ],
    ),
  ],
],
      ),
      body: Column(
        children: [
          // ✅ MONTH BAR WITH ARROWS
          Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  color: Colors.indigo[50],
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 16, color: Colors.indigo),
            onPressed: () => _changeMonth(-1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          Text(
            _getMonthDisplay(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.indigo),
            onPressed: () => _changeMonth(1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      // ✅ SIMPLE TEXT + ICON (NO BACKGROUND)
      GestureDetector(
        onTap: _isLoading ? null : _copyToNextMonth,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.content_copy, size: 16, color: Colors.indigo),
            const SizedBox(width: 4),
            Text(
              'Next Month',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.indigo,
              ),
            ),
          ],
        ),
      ),
    ],
  ),
),
          // ✅ STATS BAR - HAT GAYA (AB TABS MEIN COUNTS HAIN)
          // Rooms List with TabBarView
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: HiveDatabase.getRoomsBox().listenable(),
              builder: (context, Box<Room> box, _) {
                final allRooms = box.values.toList();
                
                // ✅ MONTH FILTER APPLY
                final monthRooms = _filterRoomsByMonth(allRooms);
                final monthRoomsSorted = [...monthRooms];

monthRoomsSorted.sort((a, b) {
  final roomA = int.tryParse(a.roomNumber) ?? 0;
  final roomB = int.tryParse(b.roomNumber) ?? 0;
  return roomA.compareTo(roomB);
});
                
                final fullyPaidRooms = monthRooms.where((r) => r.allUsersPaid).toList();
                final pendingRooms = monthRooms.where((r) => !r.allUsersPaid && r.users.isNotEmpty).toList();
                
                final filteredAllRooms = _filterRoomsBySearch(monthRoomsSorted);
                final fullyPaidRoomsSorted = [...fullyPaidRooms];
fullyPaidRoomsSorted.sort((a, b) {
  final roomA = int.tryParse(a.roomNumber) ?? 0;
  final roomB = int.tryParse(b.roomNumber) ?? 0;
  return roomA.compareTo(roomB);
});

final pendingRoomsSorted = [...pendingRooms];
pendingRoomsSorted.sort((a, b) {
  final roomA = int.tryParse(a.roomNumber) ?? 0;
  final roomB = int.tryParse(b.roomNumber) ?? 0;
  return roomA.compareTo(roomB);
});

final filteredFullyPaidRooms =
    _filterRoomsBySearch(fullyPaidRoomsSorted);

final filteredPendingRooms =
    _filterRoomsBySearch(pendingRoomsSorted);
                
                // ✅ ANIMATED SWITCHER - PAGE CHANGE KA FEEL
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.3, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: TabBarView(
                    key: ValueKey(_currentMonth.month),
                    controller: _tabController,
                    children: [
                      // 0: Rooms
                      _buildRoomsList(filteredAllRooms),
                      // 1: Users
                      _buildUsersList(monthRooms),
                      // 2: Paid
                      _buildRoomsList(filteredFullyPaidRooms, emptyMessage: 'No fully paid rooms found'),
                      // 3: Pending
                      _buildRoomsList(filteredPendingRooms, emptyMessage: 'No pending rooms found'),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
  onPressed: _addRoom,
  backgroundColor: Colors.indigo,
  elevation: 0,  // ✅ SHADOW HATAO
  highlightElevation: 0,  // ✅ PRESS SHADOW HATAO
  child: const Icon(Icons.add, color: Colors.white),
),
    );
  }

  // ✅ BUILD USERS LIST
  Widget _buildUsersList(List<Room> rooms) {
  final List<User> allUsers = [];
  for (var room in rooms) {
    allUsers.addAll(room.users);
  }
  
  if (allUsers.isEmpty) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No users in this month'),
        ],
      ),
    );
  }
  
  return ListView.builder(
    padding: const EdgeInsets.all(8),
    itemCount: allUsers.length,
    itemBuilder: (context, index) {
      final user = allUsers[index];
      final room = HiveDatabase.getRoomsBox().get(user.roomId);
      final roomNumber = room?.roomNumber ?? 'Unknown';
      
      return Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: InkWell(
          onTap: () => _openUserDetail(user),  // ✅ PURE CARD CLICKABLE
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Avatar (Paid/Unpaid toggle)
                GestureDetector(
                  onTap: () => _toggleUserPaidFromUsersTab(user),
                  child: CircleAvatar(
                    backgroundColor: user.isPaid ? Colors.green : Colors.orange,
                    radius: 20,
                    child: Text(
                      user.initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Room: $roomNumber',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        user.phoneNumber,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                // Paid/Pending toggle
                GestureDetector(
                  onTap: () => _toggleUserPaidFromUsersTab(user),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: user.isPaid ? Colors.green[100] : Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user.isPaid ? 'PAID' : 'PENDING',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: user.isPaid ? Colors.green[800] : Colors.orange[800],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
Future<void> _toggleUserPaidFromUsersTab(User user) async {
  final userBox = HiveDatabase.getUsersBox();
  final roomBox = HiveDatabase.getRoomsBox();
  
  // User ka paid status toggle karo
  final existingUser = userBox.get(user.id);
  if (existingUser != null) {
    existingUser.isPaid = !existingUser.isPaid;
    await existingUser.save();
  }
  
  // Room update karo (kyunki user ka status change hua hai)
  final room = roomBox.get(user.roomId);
  if (room != null) {
    final updatedUsersList = <User>[];
    for (var u in room.users) {
      final freshUser = userBox.get(u.id);
      if (freshUser != null) {
        updatedUsersList.add(freshUser);
      }
    }
    
    final updatedRoom = room.copyWith(
      users: updatedUsersList,
      isFullyPaid: updatedUsersList.every((u) => u.isPaid),
    );
    await roomBox.put(room.id, updatedRoom);
  }
  
  if (mounted) {
    setState(() {});
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${user.name} marked as ${existingUser?.isPaid == true ? "PAID" : "UNPAID"}'
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
void _openUserDetail(User user) {
  // User detail screen nahi hai, isliye RoomDetailScreen open karte hain
  final room = HiveDatabase.getRoomsBox().get(user.roomId);
  if (room != null) {
    _navigateToRoomDetail(room);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Room not found!')),
    );
  }
}
  Widget _buildRoomsList(List<Room> rooms, {String emptyMessage = 'No rooms found'}) {
    if (rooms.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No rooms found for "$_searchQuery"'),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.clear),
              label: const Text('Clear Search'),
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            ),
          ],
        ),
      );
    }
    
    if (rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.meeting_room, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(emptyMessage),
            const SizedBox(height: 16),
            if (emptyMessage == 'No rooms found')
              ElevatedButton(
                onPressed: _addRoom,
                child: const Text('Add Your First Room'),
              ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return _buildRoomCard(room);
      },
    );
  }

  Widget _buildRoomCard(Room room) {
  final isSelected = _selectedRoomIds.contains(room.id);
  return Card(
    margin: const EdgeInsets.only(bottom: 6), // ✅ CHHOTA
    color: isSelected ? Colors.indigo[50] : null,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10), // ✅ CHHOTA
      side: isSelected
          ? const BorderSide(color: Colors.indigo, width: 2)
          : BorderSide.none,
    ),
    child: InkWell(
      onLongPress: () => _toggleRoomSelection(room.id),
      onTap: () {
        if (_isSelectionMode) {
          _toggleRoomSelection(room.id);
        } else {
          _navigateToRoomDetail(room);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // ✅ CHHOTA
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (_isSelectionMode)
                      Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleRoomSelection(room.id),
                        visualDensity: VisualDensity.compact, // ✅ CHHOTA
                      ),
                    Text(
                      room.roomNumber,
                      style: const TextStyle(
                        fontSize: 15, // ✅ CHHOTA
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => _markAllPaidInRoom(room),
                    borderRadius: BorderRadius.circular(8),
                    splashColor: Colors.orange.withValues(alpha: 0.3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // ✅ CHHOTA
                      decoration: BoxDecoration(
                        color: room.allUsersPaid ? Colors.green[100] : Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${room.paidUsers}/${room.totalUsers}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11, // ✅ CHHOTA
                          color: room.allUsersPaid ? Colors.green[800] : Colors.orange[800],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6), // ✅ CHHOTA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 4, // ✅ CHHOTA
                  runSpacing: 4, // ✅ CHHOTA
                  children: room.users.map((user) {
                    return InkWell(
                      onTap: () => _toggleUserPaid(user, room),
                      child: Container(
                        width: 28, // ✅ CHHOTA
                        height: 28, // ✅ CHHOTA
                        decoration: BoxDecoration(
                          color: user.isPaid ? Colors.green : Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            user.initial,
                            style: TextStyle(
                              color: user.isPaid ? Colors.white : Colors.black54,
                              fontWeight: FontWeight.bold,
                              fontSize: 12, // ✅ CHHOTA
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.green, size: 18), // ✅ CHHOTA
                  onPressed: () => _sendRoomPasswords(room),
                  tooltip: 'Send All Passwords',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
  Future<void> _markAllPaidInRoom(Room room) async {
    
    
    
    
    final userBox = HiveDatabase.getUsersBox();
    final roomBox = HiveDatabase.getRoomsBox();
    
    final shouldMarkPaid = !room.allUsersPaid;
    
    
    for (var user in room.users) {
      final existingUser = userBox.get(user.id);
      if (existingUser != null) {
        existingUser.isPaid = shouldMarkPaid;
        await existingUser.save();
      }
    }
    
    final updatedRoom = roomBox.get(room.id);
    if (updatedRoom != null) {
      final updatedUsersList = <User>[];
      for (var user in updatedRoom.users) {
        final freshUser = userBox.get(user.id);
        if (freshUser != null) {
          updatedUsersList.add(freshUser);
        }
      }
      
      final finalRoom = updatedRoom.copyWith(
        users: updatedUsersList,
        isFullyPaid: shouldMarkPaid,
      );
      await roomBox.put(finalRoom.id, finalRoom);
    }
    
    if (mounted) {
      setState(() {});
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shouldMarkPaid 
                ? '✅ All users in ${room.roomNumber} marked as PAID!' 
                : '❌ All users in ${room.roomNumber} marked as UNPAID!'
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
    
    
  }

  Future<void> _toggleUserPaid(User user, Room room) async {
    
    
    final userBox = HiveDatabase.getUsersBox();
    final existingUser = userBox.get(user.id);
    
    if (existingUser != null) {
      existingUser.isPaid = !existingUser.isPaid;
      await existingUser.save();
      
      final roomBox = HiveDatabase.getRoomsBox();
      final currentRoom = roomBox.get(room.id);
      if (currentRoom != null) {
        final updatedUsersList = <User>[];
        for (var u in currentRoom.users) {
          final freshUser = userBox.get(u.id);
          if (freshUser != null) {
            updatedUsersList.add(freshUser);
          }
        }
        
        final updatedRoom = currentRoom.copyWith(
          users: updatedUsersList,
          isFullyPaid: updatedUsersList.every((u) => u.isPaid),
        );
        await roomBox.put(updatedRoom.id, updatedRoom);
      }
      
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _sendRoomPasswords(Room room) async {
    setState(() => _isLoading = true);
    
    final result = await WhatsAppService.sendPasswordsToUsers(room.users);
    
    setState(() => _isLoading = false);
    
    if (mounted) {
      String message;
      if (result['sent'] > 0) {
        message = 'Sent: ${result['sent']}/${result['total']}\n'
                  '📄 PDF: ${result['pdfCount']}  |  📡 MikroTik: ${result['mikrotikCount']}';
        if (result['failed'] > 0) {
          message += '\n❌ Failed: ${result['failed']} (${result['failedUsers'].join(", ")})';
        }
      } else {
        message = '❌ No vouchers available!\nPlease import PDF first.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
    }
  }

  void _openInventory() {
    Navigator.pushNamed(context, '/inventory');
  }
void _openMonthlySummary() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => MonthlySummaryScreen(currentMonth: _currentMonth),
    ),
  );
}

  Future<void> _showSettingsDialog() async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const MikrotikSettingsScreen(),
    ),
  );

  _checkMikroTikStatus();
}

  void _addRoom() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddRoomScreen(currentMonth: _currentMonth),
      ),
    );
    if (result == true && mounted) {
      setState(() {});
    }
  }

  void _navigateToRoomDetail(Room room) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoomDetailScreen(room: room),
      ),
    );
    setState(() {});
  }
}