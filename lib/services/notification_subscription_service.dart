import 'package:supabase_flutter/supabase_flutter.dart';

import 'push_notifications.dart';

class NotificationSubscriptionService {
  NotificationSubscriptionService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<void> enableForMember(String memberId) async {
    if (!PushNotifications.isSupported) {
      throw UnsupportedError(
        'This browser does not support push notifications.',
      );
    }
    final configuration = await _supabase.functions.invoke(
      'push-configuration',
    );
    final vapidPublicKey =
        (configuration.data as Map<String, dynamic>)['vapid_public_key']
            as String?;
    if (vapidPublicKey == null || vapidPublicKey.isEmpty) {
      throw StateError('Push notifications have not been configured yet.');
    }

    final subscription = await PushNotifications.subscribe(vapidPublicKey);
    await _supabase.rpc(
      'register_push_subscription',
      params: {
        'p_endpoint': subscription.endpoint,
        'p_p256dh': subscription.p256dh,
        'p_auth': subscription.auth,
        'p_user_agent': 'Flutter web',
      },
    );
    await _supabase.functions.invoke(
      'send-push-notification',
      body: {'notification_type': 'test', 'target_member_id': memberId},
    );
  }
}
