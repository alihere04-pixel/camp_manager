import 'package:flutter/material.dart';
import '../database/hive_database.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';

class AddRoomScreen extends StatefulWidget {
  final DateTime currentMonth;
  final Map<String, dynamic> selectedCamp;   // ⭐ ADD THIS
  
  const AddRoomScreen({
    super.key,
    required this.currentMonth,
    required this.selectedCamp,              // ⭐ ADD THIS
  });


  @override
  State<AddRoomScreen> createState() => _AddRoomScreenState();
}

class _AddRoomScreenState extends State<AddRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomNumberController = TextEditingController();
  final FocusNode _roomFocusNode = FocusNode();
  
  final List<UserFormData> _users = [];
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _roomFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _roomNumberController.dispose();
    _roomFocusNode.dispose();
    for (var user in _users) {
      user.dispose();
    }
    super.dispose();
  }

  void _addUserField() {
    setState(() {
      _users.add(UserFormData());
    });
  }

  void _removeUserField(int index) {
    setState(() {
      _users[index].dispose();
      _users.removeAt(index);
    });
  }

  Future<void> _saveRoom() async {
  if (!_formKey.currentState!.validate()) return;
  
  final roomNumber = _roomNumberController.text.trim();
  if (roomNumber.isEmpty) return;

  // ✅ SIMPLE DUPLICATE CHECK - SIRF ROOM NUMBER + MONTH
  final allRooms = HiveDatabase.getRoomsBox().values.toList();
  
  bool roomExists = false;
  for (var room in allRooms) {
    if (room.roomNumber.trim() == roomNumber && 
        room.month == widget.currentMonth.month && 
        room.year == widget.currentMonth.year) {
      roomExists = true;
      break;
    }
  }
  
  if (roomExists) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Room $roomNumber already exists!', 
                      style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
    return;
  }

  // ✅ AGAR ROOM EXISTS NAHI KARTA TOH SAVE KARO
  final List<User> users = [];
  final userBox = HiveDatabase.getUsersBox();
  final now = DateTime.now();
  
  for (var userData in _users) {
    if (userData.nameController.text.trim().isNotEmpty) {
      final passwordCountText = userData.passwordCountController.text.trim();
      final passwordCount = int.tryParse(passwordCountText) ?? 1;
      
      final amountText = userData.amountController.text.trim();
      final amount = double.tryParse(amountText) ?? 0.0;

      final newUser = User(
        id: DateTime.now().millisecondsSinceEpoch.toString() + users.length.toString(),
        roomId: '',
        name: userData.nameController.text.trim(),
        phoneNumber: userData.phoneController.text.trim(),
        isPaid: false,
        passwordCount: passwordCount,
        amount: amount,
        createdAt: now,
        updatedAt: now,
      );
      
      await userBox.put(newUser.id, newUser);
      users.add(newUser);
    }
  }
  
  final roomId = DateTime.now().millisecondsSinceEpoch.toString();
  final room = Room(
  id: roomId,
  roomNumber: roomNumber,
  users: users,
  isFullyPaid: false,
  createdAt: now,
  updatedAt: now,
  month: widget.currentMonth.month,
  year: widget.currentMonth.year,

  // ⭐ MUST ADD THIS
  campName: widget.selectedCamp['campName'],
);

  
  for (var user in users) {
    final updatedUser = user.copyWith(
      roomId: roomId,
      updatedAt: now,
    );
    await userBox.put(updatedUser.id, updatedUser);
  }
  
  await HiveDatabase.getRoomsBox().put(room.id, room);
  
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Room $roomNumber created successfully!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context, true);
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Room'),
      ),
      body: Form(
        key: _formKey,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Room Number Field
                TextFormField(
                  controller: _roomNumberController,
                  focusNode: _roomFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'Room Number',
                    hintText: 'e.g., 101, 102, 103',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.meeting_room),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter room number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                
                // Users Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Room Occupants',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // User Fields List
                if (_users.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(Icons.person_outline, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('No users added yet'),
                          Text(
                            'Tap + button to add occupants',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._users.asMap().entries.map((entry) {
                    final index = entry.key;
                    final userData = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // User header with delete button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'User ${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.indigo,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () => _removeUserField(index),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            // Name
                            TextFormField(
                              controller: userData.nameController,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                                hintText: 'e.g., Ali',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            
                            // ✅ Phone (Optional - No Validator)
                            TextFormField(
                              controller: userData.phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number (Optional)',
                                hintText: '923001234567',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 10),
                            
                            // Passwords
                            TextFormField(
                              controller: userData.passwordCountController,
                              decoration: const InputDecoration(
                                labelText: 'Number of Passwords',
                                hintText: '1-10',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Required';
                                }
                                final count = int.tryParse(value);
                                if (count == null || count < 1 || count > 10) {
                                  return 'Enter 1-10';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            
                            // Amount
                            TextFormField(
                              controller: userData.amountController,
                              decoration: const InputDecoration(
                                labelText: 'Amount (AED)',
                                hintText: '20.00',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Required';
                                }
                                final amount = double.tryParse(value);
                                if (amount == null || amount < 0) {
                                  return 'Enter valid amount';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                
                const SizedBox(height: 100),
                
               
              ],
            ),
            
            // Fixed FAB
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: _addUserField,
                backgroundColor: Colors.indigo,
                elevation: 0,
                highlightElevation: 0,
                child: const Icon(Icons.person_add, color: Colors.white),
              ),
            ),
                        // ⭐ FIXED CREATE ROOM BUTTON
            Positioned(
              bottom: 90,
              left: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: _saveRoom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Create Room', style: TextStyle(fontSize: 16)),
              ),
            ),

          ],
        ),
      ),
    );
  }
}

class UserFormData {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordCountController = TextEditingController(text: '1');
  final TextEditingController amountController = TextEditingController(text: '20');
  
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    passwordCountController.dispose();
    amountController.dispose();
  }
}