import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationSettingsRepository {
  NotificationSettingsRepository({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<Map<String, dynamic>>> fetchSettings() async {
    final response = await _supabase
        .from('notification_settings')
        .select()
        .order('notification_type');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> saveSetting({
    required String notificationType,
    required bool isEnabled,
    required List<int> reminderDays,
    String? messageTemplate,
  }) {
    return _supabase.from('notification_settings').upsert({
      'notification_type': notificationType,
      'is_enabled': isEnabled,
      'reminder_days': reminderDays,
      'message_template': messageTemplate?.trim().isEmpty == true
          ? null
          : messageTemplate?.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> sendTest(String notificationType) async {
    final response = await _supabase.functions.invoke(
      'send-push-notification',
      body: {'notification_type': notificationType},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
