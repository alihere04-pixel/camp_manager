import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../database/hive_database.dart';
import '../models/voucher_model.dart';

class PdfImportService {
  // Extract voucher codes from PDF text
  static List<String> extractVoucherCodes(String text) {
    final RegExp regExp = RegExp(r'\b[A-Z0-9]{4,12}\b');
    final matches = regExp.allMatches(text);
    
    final Set<String> codes = {};
    for (final match in matches) {
      final code = match.group(0)!;
      // Filter out phone numbers (mostly digits)
      final isPhoneNumber = RegExp(r'^[0-9]{10,15}$').hasMatch(code);
      if (!isPhoneNumber && code.length >= 4 && code.length <= 12) {
        codes.add(code);
      }
    }
    return codes.toList();
  }

  // Pick and import PDF file with detailed result
  static Future<Map<String, dynamic>> importVouchersFromPDFWithStatus() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null) {
        return {
          'success': false,
          'message': 'No file selected',
          'fileName': null,
          'totalFound': 0,
          'newImported': 0,
          'duplicates': 0,
        };
      }

      final platformFile = result.files.single;
      final fileName = platformFile.name;
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

      if (fileBytes == null) {
        return {
          'success': false,
          'message': 'Failed to read file',
          'fileName': fileName,
          'totalFound': 0,
          'newImported': 0,
          'duplicates': 0,
        };
      }

      // Open PDF and extract text
      final PdfDocument document = PdfDocument(inputBytes: fileBytes);
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      final String extractedText = extractor.extractText();
      document.dispose();

      

      final List<String> codes = extractVoucherCodes(extractedText);
      
      
      // Import to database
      final voucherBox = HiveDatabase.getVouchersBox();
      int newImported = 0;
      int duplicates = 0;
      final List<String> newCodes = [];
      final List<String> duplicateCodes = [];

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
          newCodes.add(code);
          
        } else {
          duplicates++;
          duplicateCodes.add(code);
          
        }
      }

      return {
        'success': newImported > 0,
        'message': newImported > 0 
            ? 'Imported $newImported new vouchers' 
            : 'No new vouchers found (all duplicates)',
        'fileName': fileName,
        'totalFound': codes.length,
        'newImported': newImported,
        'duplicates': duplicates,
        'newCodes': newCodes,
        'duplicateCodes': duplicateCodes,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
        'fileName': null,
        'totalFound': 0,
        'newImported': 0,
        'duplicates': 0,
      };
    }
  }

  // Old function for backward compatibility
  static Future<int> importVouchersFromPDF() async {
    final result = await importVouchersFromPDFWithStatus();
    return result['newImported'];
  }

  // Get unused voucher for a user
  static Future<String?> assignVoucherToUser(String userId) async {
    final voucherBox = HiveDatabase.getVouchersBox();
    final availableVoucher = voucherBox.values.firstWhere(
      (v) => !v.isUsed,
      orElse: () => Voucher(id: '', code: '', isUsed: true),
    );

    if (availableVoucher.code.isEmpty) {
      return null;
    }

    final updatedVoucher = availableVoucher.copyWith(
      isUsed: true,
      assignedToUserId: userId,
      assignedAt: DateTime.now(),
    );
    await voucherBox.put(availableVoucher.id, updatedVoucher);
    
    return availableVoucher.code;
  }

  static Map<String, int> getVoucherStats() {
    final vouchers = HiveDatabase.getVouchersBox().values.toList();
    return {
      'total': vouchers.length,
      'used': vouchers.where((v) => v.isUsed).length,
      'available': vouchers.where((v) => !v.isUsed).length,
    };
  }
}