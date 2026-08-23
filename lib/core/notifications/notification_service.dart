import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rxdart/rxdart.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../navigation/app_route_intent.dart';

enum NotificationPermissionStatus { notDetermined, authorized, denied }

class LocalNotificationRequest {
  const LocalNotificationRequest({
    required this.id,
    required this.title,
    required this.body,
    this.payload,
  });
  final int id;
  final String title, body;
  final String? payload;
}

abstract interface class LocalNotificationService {
  Stream<AppRouteIntent> get taps;
  Future<void> initialize();
  Future<NotificationPermissionStatus> permissionStatus();
  Future<NotificationPermissionStatus> requestPermission();
  Future<void> show(LocalNotificationRequest request);
  Future<void> schedule(
    LocalNotificationRequest request,
    DateTime localDateTime,
  );
  Future<void> cancel(int id);
  Future<void> cancelAll();
  Future<void> dispose();
}

class FlutterLocalNotificationService implements LocalNotificationService {
  FlutterLocalNotificationService({
    required this.parser,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final AppLinkParser parser;
  final FlutterLocalNotificationsPlugin _plugin;
  final PublishSubject<AppRouteIntent> _taps = PublishSubject();
  bool _initialized = false;
  String? _lastPayload;
  static const channel = AndroidNotificationChannel(
    'starter_general',
    'General',
    description: 'General starter notifications',
    importance: Importance.defaultImportance,
  );
  @override
  Stream<AppRouteIntent> get taps => _taps.stream;
  @override
  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => _accept(response.payload),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      _accept(launch?.notificationResponse?.payload);
    }
    _initialized = true;
  }

  void _accept(String? payload) {
    if (payload == null || payload == _lastPayload) {
      return;
    }
    final intent = parser.parsePayload(payload);
    if (intent != null && !_taps.isClosed) {
      _lastPayload = payload;
      _taps.add(intent);
    }
  }

  NotificationDetails get _details => const NotificationDetails(
    android: AndroidNotificationDetails(
      'starter_general',
      'General',
      channelDescription: 'General starter notifications',
    ),
    iOS: DarwinNotificationDetails(),
  );
  @override
  Future<NotificationPermissionStatus> permissionStatus() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final enabled = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
      return enabled == true
          ? NotificationPermissionStatus.authorized
          : NotificationPermissionStatus.denied;
    }
    return NotificationPermissionStatus.notDetermined;
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    bool? granted;
    if (defaultTargetPlatform == TargetPlatform.android) {
      granted = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      granted = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
    return granted == true
        ? NotificationPermissionStatus.authorized
        : NotificationPermissionStatus.denied;
  }

  @override
  Future<void> show(LocalNotificationRequest request) => _plugin.show(
    id: request.id,
    title: request.title,
    body: request.body,
    notificationDetails: _details,
    payload: request.payload,
  );
  @override
  Future<void> schedule(
    LocalNotificationRequest request,
    DateTime localDateTime,
  ) => _plugin.zonedSchedule(
    id: request.id,
    title: request.title,
    body: request.body,
    scheduledDate: tz.TZDateTime.from(localDateTime, tz.local),
    notificationDetails: _details,
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    payload: request.payload,
  );
  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
  @override
  Future<void> cancelAll() => _plugin.cancelAll();
  @override
  Future<void> dispose() => _taps.close();
}

class MemoryLocalNotificationService implements LocalNotificationService {
  MemoryLocalNotificationService({
    this.permission = NotificationPermissionStatus.notDetermined,
    this.permissionRequestResult = NotificationPermissionStatus.authorized,
  });
  NotificationPermissionStatus permission, permissionRequestResult;
  bool initialized = false;
  final List<LocalNotificationRequest> shown = [];
  final Map<int, LocalNotificationRequest> scheduled = {};
  final PublishSubject<AppRouteIntent> _taps = PublishSubject();
  @override
  Stream<AppRouteIntent> get taps => _taps.stream;
  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<NotificationPermissionStatus> permissionStatus() async => permission;
  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      permission = permissionRequestResult;
  @override
  Future<void> show(LocalNotificationRequest request) async {
    shown.add(request);
  }

  @override
  Future<void> schedule(LocalNotificationRequest request, DateTime time) async {
    scheduled[request.id] = request;
  }

  @override
  Future<void> cancel(int id) async {
    scheduled.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    scheduled.clear();
    shown.clear();
  }

  void simulateTap(AppRouteIntent intent) => _taps.add(intent);
  @override
  Future<void> dispose() => _taps.close();
}
