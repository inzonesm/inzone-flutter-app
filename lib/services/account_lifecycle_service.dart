import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:inzone/config/api_config.dart';

class AccountLifecycleResult {
  final bool success;
  final String message;

  const AccountLifecycleResult({required this.success, required this.message});
}

class AccountLifecycleService {
  Future<http.Response> _postWithFallback(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final body = jsonEncode(payload);
    final headers = {'Content-Type': 'application/json'};

    try {
      return await http.post(
        Uri.parse(ApiConfig.endpoint(path)),
        headers: headers,
        body: body,
      );
    } catch (_) {
      return await http.post(
        Uri.parse('${ApiConfig.productionBackendUrl}$path'),
        headers: headers,
        body: body,
      );
    }
  }

  Future<AccountLifecycleResult> requestAccountDeletion(String uid) async {
    try {
      final response = await _postWithFallback(
        '/user/request-account-deletion',
        {'UID': uid},
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
      final response = await _postWithFallback(
        '/user/deactivate-account',
        {'UID': uid},
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
      final response = await _postWithFallback(
        '/user/reactivate-account',
        {
          'UID': uid,
          'cancelPendingDeletion': cancelPendingDeletion,
        },
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
