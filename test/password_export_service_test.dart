import 'package:flutter_test/flutter_test.dart';
import 'package:camp_manager/services/password_export_service.dart';

void main() {
  group('PasswordExportService', () {
    test('generates the requested number of unique passwords with prefix', () {
      final passwords = PasswordExportService.generateUniquePasswords(
        prefix: 'Ali',
        length: 8,
        type: 'mix',
        count: 5,
      );

      expect(passwords.length, 5);
      expect(passwords.toSet().length, 5);
      for (final password in passwords) {
        expect(password.startsWith('Ali'), isTrue);
      }
    });

    test('respects the selected character type', () {
      final passwords = PasswordExportService.generateUniquePasswords(
        prefix: '',
        length: 4,
        type: 'capital',
        count: 5,
      );

      expect(passwords.length, 5);
      for (final password in passwords) {
        expect(password, matches(RegExp(r'^[A-Z]{4}$')));
      }
    });

    test('returns an empty list when the requested count exceeds possible combinations', () {
      final passwords = PasswordExportService.generateUniquePasswords(
        prefix: '',
        length: 1,
        type: 'number',
        count: 11,
      );

      expect(passwords, isEmpty);
    });

    test('returns an empty list for invalid counts', () {
      final passwords = PasswordExportService.generateUniquePasswords(
        prefix: 'Ali',
        length: 8,
        type: 'mix',
        count: 0,
      );

      expect(passwords, isEmpty);
    });
  });
}
