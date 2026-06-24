import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../database/hive_database.dart';
import '../models/voucher_model.dart';

class VoucherInventoryScreen extends StatefulWidget {
  const VoucherInventoryScreen({super.key});

  @override
  State<VoucherInventoryScreen> createState() => _VoucherInventoryScreenState();
}

class _VoucherInventoryScreenState extends State<VoucherInventoryScreen> {
  bool _isImporting = false;
  String? _lastImportedFile;

  @override
void initState() {
  super.initState();
  _lastImportedFile = null;
}

  Future<void> _importPDF() async {
    setState(() {
      _isImporting = true;
    });

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null) {
        setState(() => _isImporting = false);
        return;
      }

      final platformFile = result.files.single;
      final fileName = platformFile.name;
      _lastImportedFile = fileName;
      
      List<int>? fileBytes;

      if (kIsWeb) {
        fileBytes = platformFile.bytes;
      } else {
        if (platformFile.bytes != null) {
          fileBytes = platformFile.bytes;
        } else if (platformFile.path != null) {
          fileBytes = await File(platformFile.path!).readAsBytes();
        }
      }

      if (fileBytes != null) {
        final PdfDocument document = PdfDocument(inputBytes: fileBytes);
        final PdfTextExtractor extractor = PdfTextExtractor(document);
        final String extractedText = extractor.extractText();
        document.dispose();

        final RegExp regExp = RegExp(r'\b[A-Z0-9]{4,12}\b');
        final matches = regExp.allMatches(extractedText);
        
        final Set<String> codes = {};
        for (final match in matches) {
          final code = match.group(0)!;
          final isPhoneNumber = RegExp(r'^[0-9]{10,15}$').hasMatch(code);
          if (!isPhoneNumber && code.length >= 4 && code.length <= 12) {
            codes.add(code);
          }
        }

        final voucherBox = HiveDatabase.getVouchersBox();
        int newImported = 0;
        int duplicates = 0;

        for (final code in codes) {
          final exists = voucherBox.values.any((v) => v.code == code);
          if (!exists) {
            final voucher = Voucher(
              id: DateTime.now().millisecondsSinceEpoch.toString() + code,
              code: code,
              isUsed: false,
            );
            await voucherBox.put(voucher.id, voucher);
            newImported++;
          } else {
            duplicates++;
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📄 $fileName\n✅ New: $newImported | 🔄 Duplicate: $duplicates'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _deleteAllUnusedVouchers() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Unused Vouchers'),
        content: const Text('Are you sure? This action cannot be undone.'),
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
      final voucherBox = HiveDatabase.getVouchersBox();
      final toDelete = voucherBox.values.where((v) => !v.isUsed).toList();
      for (var voucher in toDelete) {
        await voucher.delete();
      }
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted ${toDelete.length} unused vouchers')),
        );
      }
    }
  }

  Future<void> _deleteAllVouchers() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete ALL Vouchers'),
        content: const Text('Warning: This will delete ALL vouchers including used ones!\nAre you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final voucherBox = HiveDatabase.getVouchersBox();
      await voucherBox.clear();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All vouchers deleted')),
        );
      }
    }
  }

 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voucher Inventory'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: _isImporting ? null : _importPDF,
            tooltip: 'Import PDF',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete_unused') {
                _deleteAllUnusedVouchers();
              } else if (value == 'delete_all') {
                _deleteAllVouchers();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete_unused',
                child: Text('Delete Unused Only'),
              ),
              const PopupMenuItem(
                value: 'delete_all',
                child: Text('Delete All Vouchers'),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: ValueListenableBuilder(
        valueListenable: HiveDatabase.getVouchersBox().listenable(),
        builder: (context, Box<Voucher> box, _) {
          final allVouchers = box.values.toList();
          final unusedVouchers = allVouchers.where((v) => !v.isUsed).toList();
          final usedVouchers = allVouchers.where((v) => v.isUsed).toList();

          return Column(
            children: [
              if (_isImporting)
                const LinearProgressIndicator(color: Colors.indigo),
              
              // Stats Cards
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: Colors.indigo[50],
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Text(
                                '${allVouchers.length}',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo),
                              ),
                              const Text('Total Vouchers', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        color: Colors.green[50],
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Text(
                                '${unusedVouchers.length}',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                              const Text('Available', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        color: Colors.grey[200],
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Text(
                                '${usedVouchers.length}',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                              const Text('Used', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Last Import Info
              if (_lastImportedFile != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          const Icon(Icons.file_present, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Last Import: $_lastImportedFile',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              
              const SizedBox(height: 8),
              
              // Vouchers List
              Expanded(
                child: allVouchers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'No vouchers in inventory',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Upload a PDF to import vouchers',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                            const SizedBox(height: 24),
                            // ✅ CENTER MEIN UPLOAD BUTTON
                            ElevatedButton.icon(
                              icon: const Icon(Icons.file_upload),
                              label: const Text('Upload PDF'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _isImporting ? null : _importPDF,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: allVouchers.length,
                        itemBuilder: (context, index) {
                          final voucher = allVouchers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: voucher.isUsed ? Colors.grey[300] : Colors.green[100],
                                child: Icon(
                                  voucher.isUsed ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: voucher.isUsed ? Colors.grey : Colors.green,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                voucher.code,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Text(
                                voucher.isUsed 
                                    ? 'Used - Assigned to: ${voucher.assignedToUserId ?? "Unknown"}'
                                    : 'Available',
                                style: TextStyle(fontSize: 12, color: voucher.isUsed ? Colors.grey : Colors.green),
                              ),
                              trailing: voucher.isUsed
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () async {
                                        await voucher.delete();
                                        setState(() {});
                                      },
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}