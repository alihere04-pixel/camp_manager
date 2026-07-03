import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_camp_screen.dart';
import 'camp_dashboard_screen.dart';
import '../database/hive_database.dart';

class CampListScreen extends StatefulWidget {
  const CampListScreen({super.key});

  @override
  State<CampListScreen> createState() => _CampListScreenState();
}

class _CampListScreenState extends State<CampListScreen> {
  bool _isSearchVisible = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _camps = [];

  bool _selectionMode = false;
  List<int> _selectedCamps = [];

  @override
  void initState() {
    super.initState();
    _loadCamps();
  }

  Future<void> _loadCamps() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('camp_list');

    if (data != null) {
      _camps = List<Map<String, dynamic>>.from(jsonDecode(data));

      for (var camp in _camps) {
        camp['campName'] = camp['campName'].replaceAll("✔", "").trim();
      }
    }

    setState(() {});
  }

  Future<void> _saveCamps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('camp_list', jsonEncode(_camps));
  }

  void _addCamp() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCampScreen(onSave: (camp) {
          _camps.add(camp);
          _saveCamps();
          _loadCamps();
        }),
      ),
    );
  }

  void _openCamp(Map<String, dynamic> camp) async {
    if (_selectionMode) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mikrotik_host', camp['host']);
    await prefs.setString('mikrotik_port', camp['port']);
    await prefs.setString('mikrotik_user', camp['user']);
    await prefs.setString('mikrotik_pass', camp['pass']);
    await prefs.setBool('mikrotik_ssl', camp['ssl']);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CampDashboardScreen(selectedCamp: camp),
      ),
    );
  }

  void _editCamp() async {
    if (_selectedCamps.isEmpty) return;

    final index = _selectedCamps.first;
    final camp = _camps[index];
    final controller = TextEditingController(text: camp['campName']);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Camp Name'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      _camps[index]['campName'] = newName;
      _saveCamps();
      setState(() {});
    }
  }

  void _deleteCamp() async {
    if (_selectedCamps.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Camps'),
        content: Text('Delete ${_selectedCamps.length} selected camp(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _selectedCamps.sort((a, b) => b.compareTo(a));

      final roomsBox = HiveDatabase.getRoomsBox();
      final usersBox = HiveDatabase.getUsersBox();

      for (final index in _selectedCamps) {
        final campName = _camps[index]['campName'];

        final roomsToDelete =
            roomsBox.values.where((room) => room.campName == campName).toList();

        for (final room in roomsToDelete) {
          final usersToDelete =
              usersBox.values.where((u) => u.roomId == room.id).toList();

          for (final user in usersToDelete) {
            await usersBox.delete(user.id);
          }

          await roomsBox.delete(room.id);
        }

        _camps.removeAt(index);
      }

      _selectedCamps.clear();
      _selectionMode = false;
      _saveCamps();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCamps = _searchQuery.isEmpty
        ? _camps
        : _camps.where((camp) {
            final name = camp['campName'].toString().toLowerCase();
            return name.contains(_searchQuery.toLowerCase());
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Camps'),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editCamp,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteCamp,
            ),
            IconButton(
              icon: Icon(
                _selectedCamps.length == _camps.length
                    ? Icons.check_box_outline_blank
                    : Icons.check_box,
                color: Colors.indigo,
              ),
              onPressed: () {
                setState(() {
                  if (_selectedCamps.length == _camps.length) {
                    _selectedCamps.clear();
                    _selectionMode = false;
                  } else {
                    _selectedCamps =
                        List.generate(_camps.length, (index) => index);
                    _selectionMode = true;
                  }
                });
              },
            ),
          ],
          if (!_selectionMode)
            IconButton(
              icon: Icon(_isSearchVisible ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _isSearchVisible = !_isSearchVisible;
                  if (!_isSearchVisible) {
                    _searchQuery = '';
                    _searchController.clear();
                  }
                });
              },
            ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _addCamp,
        child: const Icon(Icons.add),
      ),

      body: Column(
        children: [
          if (_isSearchVisible)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.white,
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search Camp...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim());
                },
              ),
            ),

          Expanded(
            child: ListView.builder(
              itemCount: filteredCamps.length,
              itemBuilder: (context, index) {
                final camp = filteredCamps[index];

                return Card(
                  child: ListTile(
                    leading: _selectionMode
                        ? Checkbox(
                            value: _selectedCamps.contains(index),
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  if (!_selectedCamps.contains(index)) {
                                    _selectedCamps.add(index);
                                  }
                                } else {
                                  _selectedCamps.remove(index);
                                  if (_selectedCamps.isEmpty) {
                                    _selectionMode = false;
                                  }
                                }
                              });
                            },
                          )
                        : null,
                    title: Text(camp['campName']),
                    subtitle: Text(
                      camp['host'].isEmpty ? "No MikroTik Set" : camp['host'],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      if (!_selectionMode) {
                        _openCamp(camp);
                      }
                    },
                    onLongPress: () {
                      setState(() {
                        _selectionMode = true;
                        if (!_selectedCamps.contains(index)) {
                          _selectedCamps.add(index);
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
