import 'dart:convert';
import 'dart:js_interop';

class PushSubscriptionData {
  const PushSubscriptionData({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
  });

  final String endpoint;
  final String p256dh;
  final String auth;
}

@JS('greensPush.isSupported')
external bool _isSupported();

@JS('greensPush.subscribe')
external JSPromise<JSString> _subscribe(JSString vapidPublicKey);

@JS('greensPush.unsubscribe')
external JSPromise<JSBoolean> _unsubscribe();

class PushNotifications {
  static bool get isSupported => _isSupported();

  static Future<PushSubscriptionData> subscribe(String vapidPublicKey) async {
    final raw = (await _subscribe(vapidPublicKey.toJS).toDart).toDart;
    final subscription = jsonDecode(raw) as Map<String, dynamic>;
    final keys = subscription['keys'] as Map<String, dynamic>;
    return PushSubscriptionData(
      endpoint: subscription['endpoint'] as String,
      p256dh: keys['p256dh'] as String,
      auth: keys['auth'] as String,
    );
  }

  static Future<void> unsubscribe() async {
    await _unsubscribe().toDart;
  }
}
