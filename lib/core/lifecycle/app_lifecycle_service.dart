import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:rxdart/rxdart.dart';

enum AppLifecycleStatus { foreground, background, inactive, detached }

abstract interface class AppLifecycleService {
  AppLifecycleStatus get current;
  Stream<AppLifecycleStatus> get stream;
  void start();
  Future<void> dispose();
}

class FlutterAppLifecycleService extends WidgetsBindingObserver
    implements AppLifecycleService {
  FlutterAppLifecycleService()
    : _subject = BehaviorSubject.seeded(
        _map(WidgetsBinding.instance.lifecycleState),
      );

  final BehaviorSubject<AppLifecycleStatus> _subject;
  bool _started = false;

  @override
  AppLifecycleStatus get current => _subject.value;

  @override
  Stream<AppLifecycleStatus> get stream => _subject.stream.distinct();

  @override
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final next = _map(state);
    if (next != _subject.value) _subject.add(next);
  }

  @override
  Future<void> dispose() async {
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _started = false;
    await _subject.close();
  }

  static AppLifecycleStatus _map(AppLifecycleState? state) => switch (state) {
    AppLifecycleState.resumed => AppLifecycleStatus.foreground,
    AppLifecycleState.paused ||
    AppLifecycleState.hidden => AppLifecycleStatus.background,
    AppLifecycleState.inactive => AppLifecycleStatus.inactive,
    AppLifecycleState.detached => AppLifecycleStatus.detached,
    null => AppLifecycleStatus.foreground,
  };
}

class FakeAppLifecycleService implements AppLifecycleService {
  FakeAppLifecycleService({
    AppLifecycleStatus initial = AppLifecycleStatus.foreground,
  }) : _subject = BehaviorSubject.seeded(initial);

  final BehaviorSubject<AppLifecycleStatus> _subject;

  @override
  AppLifecycleStatus get current => _subject.value;

  @override
  Stream<AppLifecycleStatus> get stream => _subject.stream.distinct();

  @override
  void start() {}

  void simulate(AppLifecycleStatus state) {
    if (!_subject.isClosed && state != _subject.value) _subject.add(state);
  }

  @override
  Future<void> dispose() => _subject.close();
}
