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

class PushNotifications {
  static bool get isSupported => false;

  static Future<PushSubscriptionData> subscribe(String vapidPublicKey) =>
      throw UnsupportedError('Web push is only available in a browser.');

  static Future<void> unsubscribe() async {}
}
