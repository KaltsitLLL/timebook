import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 番茄钟完成通知抽象：可注入以在测试中替换为 Fake。
abstract class NotificationService {
  Future<void> initialize();
  Future<void> show({required int id, required String title, required String body});

  /// 每日定时提醒。实现走 flutter_local_notifications。
  Future<void> scheduleDaily(
      {required int id,
      required String title,
      required String body,
      required TimeOfDay time});
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

  @override
  Future<void> scheduleDaily(
      {required int id,
      required String title,
      required String body,
      required TimeOfDay time}) async {
    // 精确到 [time] 的每日定点触发需 `timezone` 包 + tz.initializeTimeZones +
    // zonedSchedule；为避免新增较重时区依赖（且本项目了无 tz），退化为
    // periodicallyShow(daily) 每天重复触发，触发时刻由系统按首次调度驱走。
    await _plugin.periodicallyShow(
      id,
      title,
      body,
      RepeatInterval.daily,
      const NotificationDetails(
        android: AndroidNotificationDetails('bookkeeping', '记账提醒'),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}