import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_camp_screen.dart';
import 'camp_dashboard_screen.dart';

class CampListScreen extends StatefulWidget {
  const CampListScreen({super.key});

  @override
  State<CampListScreen> createState() => _CampListScreenState();
}

class _CampListScreenState extends State<CampListScreen> {
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

      // REMOVE ALL ✔ FROM campName
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
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

    final index = _selectedCamps.first;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Camp'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm == true) {
      _camps.removeAt(index);
      _selectedCamps.clear();
      _selectionMode = false;
      _saveCamps();
      setState(() {});
    }
  }

  void _deleteAllCamps() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete ALL Camps'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete All')),
        ],
      ),
    );

    if (confirm == true) {
      _camps.clear();
      _selectedCamps.clear();
      _selectionMode = false;
      _saveCamps();
      setState(() {});
    }
  }

  void _markAllCamps() {
    for (var camp in _camps) {
      camp['campName'] = "${camp['campName']} ✔";
    }
    _saveCamps();
    setState(() {});
  }

  void _unmarkAllCamps() {
    for (var camp in _camps) {
      camp['campName'] = camp['campName'].replaceAll("✔", "").trim();
    }
    _saveCamps();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Camps'),

        actions: [
          if (_selectionMode) ...[
            IconButton(icon: const Icon(Icons.edit), onPressed: _editCamp),
            IconButton(icon: const Icon(Icons.delete), onPressed: _deleteCamp),
            IconButton(icon: const Icon(Icons.done_all), onPressed: _markAllCamps),
            IconButton(icon: const Icon(Icons.remove_done), onPressed: _unmarkAllCamps),
          ],
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _addCamp,
        child: const Icon(Icons.add),
      ),

      body: ListView.builder(
        itemCount: _camps.length,
        itemBuilder: (context, index) {
          final camp = _camps[index];

          return Card(
            child: ListTile(
              leading: _selectionMode
                  ? Checkbox(
                      value: _selectedCamps.contains(index),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedCamps.add(index);
                          } else {
                            _selectedCamps.remove(index);
                            if (_selectedCamps.isEmpty) _selectionMode = false;
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
                  _selectedCamps.add(index);
                });
              },
            ),
          );
        },
      ),
    );
  }
}
