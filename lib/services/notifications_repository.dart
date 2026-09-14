import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsRepository {
  NotificationsRepository({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<Map<String, dynamic>>> fetchRecent({int limit = 20}) async {
    final response = await _supabase
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<int> fetchUnreadCount() async {
    final response = await _supabase
        .from('notifications')
        .select('id')
        .isFilter('read_at', null);
    return (response as List).length;
  }

  Future<void> markRead(String id) => _supabase
      .from('notifications')
      .update({'read_at': DateTime.now().toIso8601String()})
      .eq('id', id);

  Future<void> markAllRead() async {
    await _supabase
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .isFilter('read_at', null);
  }

  Future<void> clearAll() =>
        _supabase
          .from('notifications')
          .delete()
          .neq('id', '00000000-0000-0000-0000-000000000000');
}
