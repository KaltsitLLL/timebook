import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/focus/data/focus_repository.dart';
import 'package:timebook/features/focus/notifications/notification_service.dart';
import 'package:timebook/features/focus/presentation/focus_providers.dart';
import 'package:timebook/features/focus/presentation/focus_screen.dart';

import '../../helpers/db.dart';

/// 记录 show/initialize 调用的 Fake，验证完成通知路径。
class FakeNotificationService implements NotificationService {
  int initializeCount = 0;
  final List<({int id, String title, String body})> notifications = [];

  @override
  Future<void> initialize() async {
    initializeCount++;
  }

  @override
  Future<void> show(
      {required int id, required String title, required String body}) async {
    notifications.add((id: id, title: title, body: body));
  }
}

void main() {
  setUpAll(initTestSqlite);

  test('NotificationService 抽象可注入：initialize + show 被记录', () async {
    final fake = FakeNotificationService();
    await fake.initialize();
    await fake.show(id: 9, title: '番茄完成 🍅', body: '休息一下吧');
    expect(fake.initializeCount, 1);
    expect(fake.notifications, hasLength(1));
    expect(fake.notifications.single.id, 9);
    expect(fake.notifications.single.title, contains('番茄'));
  });

  testWidgets('专注完成触发系统通知（title 含番茄）', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = FocusRepository(db);
    final fake = FakeNotificationService();
    var fakeNow = DateTime(2026, 9, 12, 9, 0, 0);
    final container = ProviderContainer(overrides: [
      focusDatabaseProvider.overrideWithValue(db),
      focusRepositoryProvider.overrideWithValue(repo),
      focusClockProvider.overrideWithValue(() => fakeNow),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            home: Scaffold(
                body: FocusScreen(notification: fake)))));
    await tester.pumpAndSettle();

    // 开始 25min 专注，推进超过时长触发完成
    await tester.tap(find.byKey(const Key('focus_start')));
    await tester.pump();
    fakeNow = fakeNow.add(const Duration(seconds: 1501));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    // 专注完成弹确认框，点「取消」以关闭
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(fake.notifications, isNotEmpty);
    expect(fake.notifications.first.title, contains('番茄'));
  });

  testWidgets('短休结束触发通知（title 为短休结束）', (tester) async {
    final db = AppDatabase.forTesting(inMemoryExecutor());
    final repo = FocusRepository(db);
    final fake = FakeNotificationService();
    var fakeNow = DateTime(2026, 9, 12, 9, 0, 0);
    final container = ProviderContainer(overrides: [
      focusDatabaseProvider.overrideWithValue(db),
      focusRepositoryProvider.overrideWithValue(repo),
      focusClockProvider.overrideWithValue(() => fakeNow),
    ]);
    addTearDown(db.close);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            home: Scaffold(body: FocusScreen(notification: fake)))));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mode_short')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('focus_start')));
    await tester.pump();

    fakeNow = fakeNow.add(const Duration(seconds: 301));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(fake.notifications, isNotEmpty);
    expect(fake.notifications.first.title, '短休结束');
  });
}