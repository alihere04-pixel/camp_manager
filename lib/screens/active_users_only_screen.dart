import 'package:flutter/material.dart';
import '../services/mikrotik_service.dart';
import 'dart:async';


class ActiveUsersOnlyScreen extends StatefulWidget {
  const ActiveUsersOnlyScreen({super.key});

  @override
  State<ActiveUsersOnlyScreen> createState() => _ActiveUsersOnlyScreenState();
}

class _ActiveUsersOnlyScreenState extends State<ActiveUsersOnlyScreen> {
  Map<String, String> _profiles = {};
  Map<String, String> _expiryMap = {};

  List<Map<String, dynamic>> _activeUsers = [];
  bool _isLoading = true;
    Timer? _expiryTimer;


  int _parseUptimeToMinutes(String uptime) {
    try {
      uptime = uptime.toLowerCase();

      int totalMinutes = 0;

      if (uptime.contains(':')) {
        final parts = uptime.split(':');
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;
        return (hours * 60) + minutes;
      }

      final regex = RegExp(r'(\d+)([dhms])');
      final matches = regex.allMatches(uptime);

      for (final m in matches) {
        final value = int.parse(m.group(1)!);
        final unit = m.group(2)!;

        if (unit == 'd') totalMinutes += value * 1440;
        if (unit == 'h') totalMinutes += value * 60;
        if (unit == 'm') totalMinutes += value;
      }

      return totalMinutes;
    } catch (e) {
      return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadActiveUsers();

      _expiryTimer = Timer.periodic(
    const Duration(hours: 1),
    (timer) {
      _loadActiveUsers();   // ⭐ 1 ghanta baad fresh expiry
    },
  );

  }


  Future<String> _calculateExpiry(String username, String uptime) async {
    try {
      final profile = _profiles[username] ?? 'default';
      final timeout = _expiryMap[profile] ?? '0';

      if (timeout == '0') return '∞';

      int minutes = 0;

      if (timeout.endsWith('d')) {
        minutes = int.parse(timeout.replaceAll('d', '')) * 1440;
      } else if (timeout.endsWith('h')) {
        minutes = int.parse(timeout.replaceAll('h', '')) * 60;
      } else if (timeout.endsWith('m')) {
        minutes = int.parse(timeout.replaceAll('m', ''));
      }

      final uptimeMinutes = _parseUptimeToMinutes(uptime);
      final remaining = minutes - uptimeMinutes;

      if (remaining <= 0) return 'Expired';

      final days = (remaining / 1440).floor();
      final hours = ((remaining % 1440) / 60).floor();

      return '${days}d ${hours}h';
    } catch (e) {
      return '?';
    }
  }

  Future<void> _loadActiveUsers() async {
    setState(() => _isLoading = true);

    try {
      _profiles = await MikroTikService.getUserProfiles();
      _expiryMap = await MikroTikService.getProfileExpiryMap();
      final users = await MikroTikService.getActiveUsers();

      users.sort((a, b) {
        final nameA = (a['name'] ?? '').toString();
        final nameB = (b['name'] ?? '').toString();

        final isNumA = RegExp(r'^\d').hasMatch(nameA);
        final isNumB = RegExp(r'^\d').hasMatch(nameB);

        if (isNumA && !isNumB) return -1;
        if (!isNumA && isNumB) return 1;

        return nameA.toLowerCase().compareTo(nameB.toLowerCase());
      });

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
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: ActiveUserSearchDelegate(_activeUsers),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadActiveUsers,
        child: _isLoading
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
                              FutureBuilder(
                                future: _calculateExpiry(
                                  user['name'],
                                  user['uptime'] ?? '00:00:00',
                                ),
                                builder: (context, snapshot) {
                                  final expiry = snapshot.data ?? '?';
                                  return Text(
                                    'Uptime: ${user['uptime']}   Exp: $expiry',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  );
                                },
                              ),
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
      ),
    );
  }

    @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }
}

// ⭐ SEARCH DELEGATE
class ActiveUserSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> users;

  ActiveUserSearchDelegate(this.users);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final filtered = users.where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      return name.contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final user = filtered[index];
        return ListTile(
          title: Text(user['name'] ?? 'Unknown'),
          subtitle: Text('IP: ${user['address'] ?? 'N/A'}'),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final filtered = users.where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      return name.contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final user = filtered[index];
        return ListTile(
          title: Text(user['name'] ?? 'Unknown'),
          subtitle: Text('IP: ${user['address'] ?? 'N/A'}'),
        );
      },
    );
  }
}
