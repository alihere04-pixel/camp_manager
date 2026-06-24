import 'package:url_launcher/url_launcher.dart';
import '../database/hive_database.dart';
import '../models/user_model.dart';
import '../models/voucher_model.dart';
import 'mikrotik_service.dart';
import 'settings_service.dart';

class WhatsAppService {
  static Future<bool> isMikroTikConnected() async {
    return await MikroTikService.checkConnection();
  }

  static Future<List<Voucher>> getUnusedVouchers(int count) async {
    final voucherBox = HiveDatabase.getVouchersBox();
    final allUnused = voucherBox.values.where((v) => !v.isUsed).toList();
    if (allUnused.length >= count) {
      return allUnused.take(count).toList();
    }
    return allUnused;
  }

  static Future<void> markVoucherAsUsed(String voucherId, String userId) async {
    final voucherBox = HiveDatabase.getVouchersBox();
    final voucher = voucherBox.get(voucherId);
    if (voucher != null) {
      final updatedVoucher = voucher.copyWith(
        isUsed: true,
        assignedToUserId: userId,
        assignedAt: DateTime.now(),
      );
      await voucherBox.put(voucherId, updatedVoucher);
    }
  }

  static Future<Map<String, dynamic>> sendPasswordToUser(User user) async {
    try {
      
      
      List<String> passwords = [];
      List<Voucher> usedVouchers = [];
      String source = '';
      
      final userBox = HiveDatabase.getUsersBox();
      
      final availableVouchers = await getUnusedVouchers(user.passwordCount);
      
      if (availableVouchers.length >= user.passwordCount) {
        for (int i = 0; i < user.passwordCount; i++) {
          final voucher = availableVouchers[i];
          passwords.add(voucher.code);
          usedVouchers.add(voucher);
        }
        source = 'pdf';
      } else if (availableVouchers.isNotEmpty) {
        for (final voucher in availableVouchers) {
          passwords.add(voucher.code);
          usedVouchers.add(voucher);
        }
        source = 'mixed';
        
        final remaining = user.passwordCount - availableVouchers.length;
        final mikrotikConnected = await isMikroTikConnected();
        
        if (mikrotikConnected) {
          final length = SettingsService.passwordLength;
          final type = SettingsService.passwordType;
          
          for (int i = 0; i < remaining; i++) {
            final newPassword = MikroTikService.generateRandomPassword(length, type);
            passwords.add(newPassword);
          }
          source = 'mixed';
        } else {
          return {
            'success': false,
            'source': 'none',
            'message': 'Not enough vouchers. Need ${user.passwordCount} but only ${availableVouchers.length} available.',
          };
        }
      } else {
        final mikrotikConnected = await isMikroTikConnected();
        
        if (mikrotikConnected) {
          final length = SettingsService.passwordLength;
          final type = SettingsService.passwordType;
          
          for (int i = 0; i < user.passwordCount; i++) {
            final newPassword = MikroTikService.generateRandomPassword(length, type);
            passwords.add(newPassword);
          }
          source = 'mikrotik';
        } else {
          return {
            'success': false,
            'source': 'none',
            'message': 'No vouchers available. Please import PDF or connect MikroTik.',
          };
        }
      }
      
      // Username = Password rakhna hai
// MikroTik me Name aur Password same honge


      
      for (int i = 0; i < usedVouchers.length; i++) {
        final voucher = usedVouchers[i];
        await markVoucherAsUsed(voucher.id, user.id);
      }
      
      final mikrotikConnected = await isMikroTikConnected();
      final profile = SettingsService.mikrotikProfile;  // ✅ PROFILE USE KARO
      
      if (mikrotikConnected) {
        for (int i = 0; i < passwords.length; i++) {

  await MikroTikService.createHotspotUser(
    username: passwords[i],
    password: passwords[i],

    // agar comment nahi chahiye to empty
    comment: '',

    profile: profile,
  );

}
      }
      
      final allPasswords = passwords.join(', ');
      final existingUser = userBox.get(user.id);
      if (existingUser != null) {
        existingUser.voucherCode = allPasswords;
        existingUser.voucherUsername = passwords.join(', ');
        existingUser.syncedWithMikrotik = true;
        await existingUser.save();
      } else {
        user.voucherCode = allPasswords;
        user.voucherUsername = passwords.join(', ');
        user.syncedWithMikrotik = true;
        await userBox.put(user.id, user);
      }
      
      final message = _buildMultiplePasswordsMessage(user, passwords);
      final encodedMessage = Uri.encodeComponent(message);
      final cleanPhone = user.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      final whatsappUrl = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');
      
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.platformDefault);
        return {
          'success': true,
          'source': source,
          'passwordsCount': passwords.length,
          'message': '${passwords.length} passwords sent to ${user.name}',
        };
      }
      
      return {
        'success': false,
        'source': source,
        'message': 'Failed to send WhatsApp message',
      };
    } catch (e) {
      
      return {
        'success': false,
        'source': 'error',
        'message': 'Error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> sendPasswordsToUsers(List<User> users) async {
    int successCount = 0;
    int pdfCount = 0;
    int mikrotikCount = 0;
    int failedCount = 0;
    final List<String> failedUsers = [];
    
    for (final user in users) {
      final result = await sendPasswordToUser(user);
      await Future.delayed(const Duration(seconds: 2));
      
      if (result['success'] == true) {
        successCount++;
        if (result['source'] == 'pdf') pdfCount++;
        if (result['source'] == 'mikrotik') mikrotikCount++;
      } else {
        failedCount++;
        failedUsers.add(user.name);
      }
    }
    
    return {
      'success': successCount > 0,
      'total': users.length,
      'sent': successCount,
      'pdfCount': pdfCount,
      'mikrotikCount': mikrotikCount,
      'failed': failedCount,
      'failedUsers': failedUsers,
    };
  }

  static String _buildMultiplePasswordsMessage(User user, List<String> passwords) {
    if (passwords.length == 1) {
      return "🔐 Your password is: *${passwords[0]}*";
    } else {
      String msg = "🔐 *Your ${passwords.length} Passwords:*\n\n";
      for (int i = 0; i < passwords.length; i++) {
        msg += "${i+1}. *${passwords[i]}*\n";
      }
      return msg;
    }
  }
}