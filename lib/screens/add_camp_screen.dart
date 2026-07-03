import 'package:flutter/material.dart';

class AddCampScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;

  const AddCampScreen({super.key, required this.onSave});

  @override
  State<AddCampScreen> createState() => _AddCampScreenState();
}

class _AddCampScreenState extends State<AddCampScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _campName = TextEditingController();
  final TextEditingController _host = TextEditingController();
  final TextEditingController _port = TextEditingController(text: "8728");
  final TextEditingController _user = TextEditingController();
  final TextEditingController _pass = TextEditingController();

  bool _useSsl = false;

  void _saveCamp() {
    if (!_formKey.currentState!.validate()) return;

    final camp = {
      "campName": _campName.text.trim(),
      "host": _host.text.trim(),     // optional
      "port": _port.text.trim(),     // optional
      "user": _user.text.trim(),     // optional
      "pass": _pass.text.trim(),     // optional
      "ssl": _useSsl,
    };

    widget.onSave(camp);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add New Camp")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ⭐ REQUIRED ONLY THIS FIELD
              TextFormField(
                controller: _campName,
                decoration: const InputDecoration(
                  labelText: "Camp Name",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),

              const SizedBox(height: 12),

              // ⭐ OPTIONAL
              TextFormField(
                controller: _host,
                decoration: const InputDecoration(
                  labelText: "MikroTik Host (Optional)",
                  hintText: "192.168.88.1",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              // ⭐ OPTIONAL
              TextFormField(
                controller: _port,
                decoration: const InputDecoration(
                  labelText: "Port (Optional)",
                  hintText: "8728 / 8729",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              // ⭐ OPTIONAL
              TextFormField(
                controller: _user,
                decoration: const InputDecoration(
                  labelText: "Username (Optional)",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              // ⭐ OPTIONAL
              TextFormField(
                controller: _pass,
                decoration: const InputDecoration(
                  labelText: "Password (Optional)",
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),

              const SizedBox(height: 12),

              SwitchListTile(
                title: const Text("Use SSL (HTTPS)"),
                subtitle: Text(_useSsl ? "Port 8729" : "Port 8728"),
                value: _useSsl,
                onChanged: (v) {
                  setState(() {
                    _useSsl = v;
                    _port.text = v ? "8729" : "8728";
                  });
                },
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _saveCamp,
                child: const Text("Save Camp"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
