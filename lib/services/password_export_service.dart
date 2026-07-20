import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PasswordExportService {
  static List<String> generateUniquePasswords({
    required String prefix,
    required int length,
    required String type,
    required int count,
  }) {
    if (count <= 0 || length <= 0) {
      return [];
    }

    final chars = _getCharacters(type);
    if (chars.isEmpty) {
      return [];
    }

    final totalCombinations = _getTotalPossibleCombinations(chars.length, length);
    if (count > totalCombinations) {
      return [];
    }

    final random = Random.secure();
    final passwords = <String>{};
    final maxAttempts = max(count * 1000, 10000);
    var attempts = 0;

    while (passwords.length < count && attempts < maxAttempts) {
      final generated = _generateRandomPart(chars, length, random);
      final finalPassword = _applyPrefix(prefix, generated);
      passwords.add(finalPassword);
      attempts++;
    }

    if (passwords.length < count) {
      return [];
    }

    final shuffled = passwords.toList()..shuffle();
    return shuffled;
  }

  static Future<String> generateAndSharePdf({
    required String profile,
    required String characterType,
    required int passwordLength,
    required int passwordCount,
    required String prefix,
  }) async {
    final passwords = generateUniquePasswords(
      prefix: prefix,
      length: passwordLength,
      type: characterType,
      count: passwordCount,
    );

    if (passwords.isEmpty) {
      throw Exception(
        'Unable to generate the requested number of unique passwords with the selected length and character type.',
      );
    }

    final document = PdfDocument();
    final now = DateTime.now().toLocal();
    final pdfFont = PdfStandardFont(PdfFontFamily.helvetica, 11);
    final pdfBoldFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
    final pdfTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);

    final pageSize = document.pageSettings.size;
    const margin = 28.0;
    const cardWidth = 250.0;
    const cardHeight = 95.0;
    const horizontalGap = 18.0;
    const verticalGap = 16.0;
    const cardsPerRow = 2;
    const cardsPerPage = 24;

    var pageIndex = 0;
    var currentPage = document.pages.add();

    void drawPageHeader(PdfPage page) {
      page.graphics.drawString(
        'Password List',
        pdfTitleFont,
        bounds: const Rect.fromLTWH(28, 24, 500, 24),
      );
      page.graphics.drawString(
        'Profile: $profile',
        pdfFont,
        bounds: const Rect.fromLTWH(28, 54, 500, 16),
      );
      page.graphics.drawString(
        'Generated: ${_formatDate(now)}  ${_formatTime(now)}',
        pdfFont,
        bounds: const Rect.fromLTWH(28, 72, 500, 16),
      );
    }

    void drawVoucherCard({
      required PdfPage page,
      required double x,
      required double y,
      required int serialNumber,
      required String password,
    }) {
      final borderBounds = Rect.fromLTWH(x, y, cardWidth, cardHeight);
      page.graphics.drawRectangle(
        bounds: borderBounds,
        pen: PdfPen(PdfColor(120, 120, 120)),
      );

      page.graphics.drawString(
        'Serial No: $serialNumber',
        pdfBoldFont,
        bounds: Rect.fromLTWH(x + 10, y + 12, cardWidth - 20, 18),
      );
      page.graphics.drawString(
        'User Profile',
        pdfFont,
        bounds: Rect.fromLTWH(x + 10, y + 38, cardWidth - 20, 16),
      );
      page.graphics.drawString(
        profile,
        pdfBoldFont,
        bounds: Rect.fromLTWH(x + 10, y + 54, cardWidth - 20, 18),
      );
      page.graphics.drawString(
        'Password',
        pdfFont,
        bounds: Rect.fromLTWH(x + 10, y + 74, cardWidth - 20, 16),
      );
      page.graphics.drawString(
        password,
        pdfBoldFont,
        bounds: Rect.fromLTWH(x + 10, y + 90, cardWidth - 20, 18),
      );
    }

    drawPageHeader(currentPage);

    for (var i = 0; i < passwords.length; i++) {
      final pageOffset = i % cardsPerPage;
      if (pageOffset == 0 && i > 0) {
        pageIndex += 1;
        currentPage = document.pages.add();
        drawPageHeader(currentPage);
      }

      final cardIndexInPage = i % cardsPerPage;
      final row = cardIndexInPage ~/ cardsPerRow;
      final column = cardIndexInPage % cardsPerRow;
      final x = margin + (column * (cardWidth + horizontalGap));
      final y = 100.0 + (row * (cardHeight + verticalGap));

      drawVoucherCard(
        page: currentPage,
        x: x,
        y: y,
        serialNumber: i + 1,
        password: passwords[i],
      );
    }

    final downloadsDirectory = await _getDownloadsDirectory();
    await downloadsDirectory.create(recursive: true);

    final fileName = 'Password_List_${_formatFileDate(now)}_${_formatTime(now).replaceAll(':', '-').replaceAll(' ', '')}.pdf';
    final file = File('${downloadsDirectory.path}/$fileName');
    final bytes = await document.save();
    await file.writeAsBytes(bytes);
    document.dispose();

    await Share.shareXFiles([XFile(file.path)], subject: 'Password List');

    return file.path;
  }

  static String _getCharacters(String type) {
    switch (type) {
      case 'capital':
        return 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      case 'small':
        return 'abcdefghijklmnopqrstuvwxyz';
      case 'mix':
        return 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
      case 'number':
        return '0123456789';
      default:
        return 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    }
  }

  static String _applyPrefix(String prefix, String generated) {
    final normalizedPrefix = prefix.trim();
    if (normalizedPrefix.isEmpty || normalizedPrefix.toLowerCase() == 'none') {
      return generated;
    }
    return '$normalizedPrefix$generated';
  }

  static String _generateRandomPart(String chars, int length, Random random) {
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  static int _getTotalPossibleCombinations(int charCount, int length) {
    if (charCount <= 0 || length <= 0) {
      return 0;
    }

    var total = 1;
    for (var i = 0; i < length; i++) {
      total *= charCount;
    }
    return total;
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  static String _formatFileDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  static Future<Directory> _getDownloadsDirectory() async {
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        return Directory('${downloadsDir.path}/CampManager');
      }
    } catch (_) {}

    return Directory('/storage/emulated/0/Download/CampManager');
  }
}
