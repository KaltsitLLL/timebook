import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 番茄钟完成通知抽象：可注入以在测试中替换为 Fake。
abstract class NotificationService {
  Future<void> initialize();
  Future<void> show({required int id, required String title, required String body});
}

/// 生产实现：flutter_local_notifications（Android/Windows/iOS）。
class FlutterNotificationService implements NotificationService {
  FlutterNotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);
  }

  @override
  Future<void> show({required int id, required String title, required String body}) =>
      _plugin.show(id, title, body, const NotificationDetails(
        android: AndroidNotificationDetails('focus', '专注提醒'),
        iOS: DarwinNotificationDetails(),
      ));
}