import 'package:flutter/material.dart';
import '../services/mikrotik_service.dart';

class ActiveUsersOnlyScreen extends StatefulWidget {
  const ActiveUsersOnlyScreen({super.key});

  @override
  State<ActiveUsersOnlyScreen> createState() => _ActiveUsersOnlyScreenState();
}

class _ActiveUsersOnlyScreenState extends State<ActiveUsersOnlyScreen> {
  List<Map<String, dynamic>> _activeUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveUsers();
  }

  Future<void> _loadActiveUsers() async {
    setState(() => _isLoading = true);
    
    try {
      final users = await MikroTikService.getActiveUsers();
      setState(() {
        _activeUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Users'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActiveUsers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeUsers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No Active Users'),
                      SizedBox(height: 8),
                      Text('No users are currently active'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _activeUsers.length,
                  itemBuilder: (context, index) {
                    final user = _activeUsers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green[100],
                          child: Text(
                            (user['name']?.isNotEmpty == true)
                                ? user['name'][0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        title: Text(
                          user['name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('IP: ${user['address'] ?? 'N/A'}'),
                            Text('Uptime: ${user['uptime'] ?? 'N/A'}'),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}