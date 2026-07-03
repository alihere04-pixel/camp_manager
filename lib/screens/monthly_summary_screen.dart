import 'package:flutter/material.dart';
import '../database/hive_database.dart';

class MonthlySummaryScreen extends StatefulWidget {
  final DateTime currentMonth;
final Map<String, dynamic> selectedCamp;   // ⭐ ADD

const MonthlySummaryScreen({
  super.key,
  required this.currentMonth,
  required this.selectedCamp,              // ⭐ ADD
});


  @override
  State<MonthlySummaryScreen> createState() => _MonthlySummaryScreenState();
}

class _MonthlySummaryScreenState extends State<MonthlySummaryScreen> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.currentMonth;
  }

  void _changeMonth(int direction) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + direction);
    });
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final allRooms = HiveDatabase.getRoomsBox().values.toList();
    final monthRooms = allRooms.where((room) {
  return room.month == _currentMonth.month &&
         room.year == _currentMonth.year &&
         room.campName == widget.selectedCamp['campName'];   // ⭐ CAMP FILTER
}).toList();


    final totalRooms = monthRooms.length;
    int totalUsers = 0;
    int paidUsers = 0;
    double totalAmount = 0;
    double collectedAmount = 0;

    for (var room in monthRooms) {
      totalUsers += room.users.length;
      paidUsers += room.paidUsers;
      for (var user in room.users) {
        totalAmount += user.amount;
        if (user.isPaid) {
          collectedAmount += user.amount;
        }
      }
    }

    final pendingUsers = totalUsers - paidUsers;
    final pendingAmount = totalAmount - collectedAmount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Summary'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.indigo[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 18, color: Colors.indigo),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.indigo),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCard(
                  'Total Rooms',
                  totalRooms.toString(),
                  Icons.meeting_room,
                  Colors.indigo,
                ),
                _buildSummaryCard(
                  'Total Users',
                  totalUsers.toString(),
                  Icons.people,
                  Colors.teal,
                ),
                _buildSummaryCard(
                  'Paid Users',
                  paidUsers.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildSummaryCard(
                  'Pending Users',
                  pendingUsers.toString(),
                  Icons.pending,
                  Colors.orange,
                ),
                _buildSummaryCard(
                  'Total Amount',
                  '${totalAmount.toStringAsFixed(2)} AED',
                  Icons.attach_money,
                  Colors.purple,
                ),
                _buildSummaryCard(
                  'Collected Amount',
                  '${collectedAmount.toStringAsFixed(2)} AED',
                  Icons.credit_card,
                  Colors.green,
                ),
                _buildSummaryCard(
                  'Pending Amount',
                  '${pendingAmount.toStringAsFixed(2)} AED',
                  Icons.pending_actions,
                  Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}