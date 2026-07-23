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

  // ✅ SHARE PDF — 6 CARDS PER ROW, 72 PER PAGE (SAVE TO DEVICE JESA)
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
document.pageSettings.margins.all = 0;
    final now = DateTime.now().toLocal();

    // Fonts

    final profileFont = PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold);
    final serialFont = PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold);
    final labelFont = PdfStandardFont(PdfFontFamily.helvetica, 8);
    final codeFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);

    // Card dimensions
    const double margin = 8;
    const double cardWidth = 80;
    const double cardHeight = 50;
    const double horizontalGap = 8;
    const double verticalGap = 5;
    const int cardsPerRow = 6;

    // Header height (fixed space for header)
    const double headerHeight = 70;

    // Page dimensions
    final pageWidth = document.pageSettings.size.width;
    final pageHeight = document.pageSettings.size.height;

    // Track current page and position
    PdfPage currentPage = document.pages.add();
    double y = headerHeight;
    int cardsOnPage = 0;

    void drawHeader(PdfPage page) {
      double yy = 14;
      // Left: Profile
      final profileText = 'Profile: $profile';
      page.graphics.drawString(
        profileText,
        profileFont,
        bounds: Rect.fromLTWH(margin, yy, 200, 12),
      );
      // Right: Generated date/time (same line)
      final generatedText = 'Generated: ${_formatDate(now)}  ${_formatTime(now)}';
      final generatedWidth = profileFont.measureString(generatedText).width;
      page.graphics.drawString(
        generatedText,
        profileFont,
        bounds: Rect.fromLTWH(pageWidth - generatedWidth - margin, yy, generatedWidth, 12),
      );
    }
    // Draw header on first page
    drawHeader(currentPage);

      for (var i = 0; i < passwords.length; i++) {
    final voucherCode = passwords[i].length > 5
        ? passwords[i].substring(0, 5)
        : passwords[i];

    final row = cardsOnPage ~/ cardsPerRow;
    final col = cardsOnPage % cardsPerRow;

       // ⭐ PERFECT CENTER FIX — PAGE MARGIN ZERO + HEADER BALANCED
    final double totalCardsWidth = cardsPerRow * cardWidth;
    final double totalGaps = (cardsPerRow - 1) * horizontalGap;
    final double totalWidth = totalCardsWidth + totalGaps;

    // ⭐ TRUE CENTER — Syncfusion hidden margin removed
    final double startX = ((pageWidth - totalWidth) / 2);

    final x = startX + (col * (cardWidth + horizontalGap));
    final cardY = y + (row * (cardHeight + verticalGap));

    // Card border
    final borderBounds = Rect.fromLTWH(x, cardY, cardWidth, cardHeight);
    currentPage.graphics.drawRectangle(
      bounds: borderBounds,
      pen: PdfPen(PdfColor(180, 180, 180), width: 0.5),
    );

    // Serial number
    currentPage.graphics.drawString(
      '[${i + 1}]',
      serialFont,
      bounds: Rect.fromLTWH(x + 3, cardY + 2, 20, 10),
    );

    // "Kode Voucher" label
    currentPage.graphics.drawString(
      'Kode Voucher',
      labelFont,
      bounds: Rect.fromLTWH(x + 3, cardY + 14, 50, 10),
    );

    // Voucher code
    currentPage.graphics.drawString(
      voucherCode,
      codeFont,
      bounds: Rect.fromLTWH(x + 3, cardY + 26, cardWidth - 6, 16),
    );

    cardsOnPage++;

    // ✅ CHECK IF PAGE IS FULL (72 cards OR page height full)
    if ((cardsOnPage >= 72 || (cardY + cardHeight > pageHeight - 25)) && i < passwords.length - 1) {
      // Create new page
      currentPage = document.pages.add();
      drawHeader(currentPage);
      y = headerHeight;
      cardsOnPage = 0;
    }
  }
    final bytes = await document.save();
    document.dispose();

    final downloadsDirectory = await _getDownloadsDirectory();
    await downloadsDirectory.create(recursive: true);

    final fileName = 'Password_List_${_formatFileDate(now)}_${_formatTime(now).replaceAll(':', '-').replaceAll(' ', '')}.pdf';
    final file = File('${downloadsDirectory.path}/$fileName');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles([XFile(file.path)], subject: 'Password List');

    return file.path;
  }

  // ✅ HELPER METHODS
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