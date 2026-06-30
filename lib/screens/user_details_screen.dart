import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UserDetailsScreen extends StatelessWidget {
  final String username;
  final String password;
  final String mac;
  final String profile;

  const UserDetailsScreen({
    super.key,
    required this.username,
    required this.password,
    required this.mac,
    required this.profile,
  });

  void copyText(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $text'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(username),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // PASSWORD
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Password:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.copy),
                  onPressed: () => copyText(context, password),
                ),
              ],
            ),
            Text(password, style: TextStyle(fontSize: 16)),
            SizedBox(height: 20),

            // MAC
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "MAC Address:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.copy),
                  onPressed: () => copyText(context, mac),
                ),
              ],
            ),
            Text(mac, style: TextStyle(fontSize: 16)),
            SizedBox(height: 20),

            // PROFILE
            Text(
              "Profile:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(profile, style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
