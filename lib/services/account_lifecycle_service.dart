import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:inzone/config/api_config.dart';

class AccountLifecycleResult {
  final bool success;
  final String message;

  const AccountLifecycleResult({required this.success, required this.message});
}

class AccountLifecycleService {
  Future<AccountLifecycleResult> requestAccountDeletion(String uid) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.endpoint('/user/request-account-deletion')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'UID': uid}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final success = data['success'] == true;

      if (!success || (response.statusCode < 200 || response.statusCode >= 300)) {
        final message = data['error']?.toString() ?? 'Failed to request account deletion.';
        return AccountLifecycleResult(success: false, message: message);
      }

      return const AccountLifecycleResult(
        success: true,
        message: 'Deletion requested. Your account is scheduled for permanent purge in 30 days.',
      );
    } catch (e) {
      return AccountLifecycleResult(
        success: false,
        message: 'Failed to request account deletion: $e',
      );
    }
  }

  Future<AccountLifecycleResult> deactivateAccount(String uid) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.endpoint('/user/deactivate-account')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'UID': uid}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final success = data['success'] == true;

      if (!success || (response.statusCode < 200 || response.statusCode >= 300)) {
        final message = data['error']?.toString() ?? 'Failed to deactivate account.';
        return AccountLifecycleResult(success: false, message: message);
      }

      return const AccountLifecycleResult(
        success: true,
        message: 'Account deactivated successfully.',
      );
    } catch (e) {
      return AccountLifecycleResult(
        success: false,
        message: 'Failed to deactivate account: $e',
      );
    }
  }

  Future<AccountLifecycleResult> reactivateAccount(
    String uid, {
    bool cancelPendingDeletion = true,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.endpoint('/user/reactivate-account')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'UID': uid,
          'cancelPendingDeletion': cancelPendingDeletion,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final success = data['success'] == true;

      if (!success || (response.statusCode < 200 || response.statusCode >= 300)) {
        final message = data['error']?.toString() ?? 'Failed to reactivate account.';
        return AccountLifecycleResult(success: false, message: message);
      }

      return const AccountLifecycleResult(
        success: true,
        message: 'Account reactivated successfully.',
      );
    } catch (e) {
      return AccountLifecycleResult(
        success: false,
        message: 'Failed to reactivate account: $e',
      );
    }
  }
}
