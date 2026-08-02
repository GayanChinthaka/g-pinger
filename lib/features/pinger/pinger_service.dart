import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/ping_state.dart';

// ── Public constants ─────────────────────────────────────────────────────────

const kDefaultUrls = [
  'http://192.168.8.1/',
  'https://hutch.lk/',
  'http://google.com/',
];

const kDefaultIntervalDurations = [
  Duration(seconds: 5),
  Duration(seconds: 10),
  Duration(seconds: 15),
  Duration(seconds: 30),
  Duration(seconds: 60),
  Duration(seconds: 300),
];

const kTimeoutOptions = [
  Duration(seconds: 3),
  Duration(seconds: 5),
  Duration(seconds: 10),
  Duration(seconds: 15),
  Duration(seconds: 30),
];

String formatInterval(Duration d) {
  final s = d.inSeconds;
  if (s < 60) return '${s}s';
  if (s % 60 == 0) return '${s ~/ 60}m';
  return '${s ~/ 60}m ${s % 60}s';
}

// ── Private pref keys ────────────────────────────────────────────────────────

const _kIntervalKey = 'interval_seconds';
const _kTargetUrlKey = 'target_url';
const _kCustomUrlsKey = 'custom_urls';
const _kCustomIntervalsKey = 'custom_intervals';
const _kPingTimeoutKey = 'ping_timeout_seconds';
const _kHapticKey = 'haptic_feedback';
const _kResetOnStartKey = 'reset_on_start';

// ── Shared-prefs singleton ──────────────────────────────────────────────────

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('Override sharedPreferencesProvider in ProviderScope'),
);

// ── Settings providers ──────────────────────────────────────────────────────

final intervalProvider = StateProvider<Duration>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return Duration(seconds: prefs.getInt(_kIntervalKey) ?? 10);
});

final targetUrlProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString(_kTargetUrlKey) ?? kDefaultUrls.first;
});

final pingTimeoutProvider = StateProvider<Duration>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return Duration(seconds: prefs.getInt(_kPingTimeoutKey) ?? 5);
});

final hapticFeedbackProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(_kHapticKey) ?? true;
});

final resetOnStartProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(_kResetOnStartKey) ?? false;
});

// ── URL management ───────────────────────────────────────────────────────────

final customUrlsProvider =
    StateNotifierProvider<CustomUrlsNotifier, List<String>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CustomUrlsNotifier(prefs);
});

class CustomUrlsNotifier extends StateNotifier<List<String>> {
  final SharedPreferences _prefs;

  CustomUrlsNotifier(this._prefs)
      : super(_prefs.getStringList(_kCustomUrlsKey) ?? const []);

  Future<void> add(String url) async {
    if (state.contains(url)) return;
    state = [...state, url];
    await _prefs.setStringList(_kCustomUrlsKey, state);
  }

  Future<void> remove(String url) async {
    state = state.where((u) => u != url).toList();
    await _prefs.setStringList(_kCustomUrlsKey, state);
  }
}

// ── Interval management ──────────────────────────────────────────────────────

final customIntervalsProvider =
    StateNotifierProvider<CustomIntervalsNotifier, List<Duration>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CustomIntervalsNotifier(prefs);
});

class CustomIntervalsNotifier extends StateNotifier<List<Duration>> {
  final SharedPreferences _prefs;

  CustomIntervalsNotifier(this._prefs)
      : super(
          (_prefs.getStringList(_kCustomIntervalsKey) ?? [])
              .map((s) => Duration(seconds: int.tryParse(s) ?? 0))
              .where((d) => d.inSeconds > 0)
              .toList(),
        );

  Future<void> add(Duration d) async {
    final isDefault =
        kDefaultIntervalDurations.any((e) => e.inSeconds == d.inSeconds);
    if (isDefault || state.any((e) => e.inSeconds == d.inSeconds)) return;
    state = [...state, d]
      ..sort((a, b) => a.inSeconds.compareTo(b.inSeconds));
    await _save();
  }

  Future<void> remove(Duration d) async {
    state = state.where((e) => e.inSeconds != d.inSeconds).toList();
    await _save();
  }

  Future<void> _save() async {
    await _prefs.setStringList(
      _kCustomIntervalsKey,
      state.map((d) => d.inSeconds.toString()).toList(),
    );
  }
}

// Derived provider: all intervals (defaults + custom), sorted.
final allIntervalsProvider = Provider<List<Duration>>((ref) {
  final custom = ref.watch(customIntervalsProvider);
  final all = [
    ...kDefaultIntervalDurations,
    ...custom.where(
        (d) => !kDefaultIntervalDurations.any((e) => e.inSeconds == d.inSeconds)),
  ];
  all.sort((a, b) => a.inSeconds.compareTo(b.inSeconds));
  return all;
});

// ── Pinger ──────────────────────────────────────────────────────────────────

final pingerProvider =
    StateNotifierProvider<PingerNotifier, PingState>(PingerNotifier.new);

class PingerNotifier extends StateNotifier<PingState> {
  final Ref _ref;
  Timer? _timer;

  // Native foreground service: keeps the process alive while the app is in
  // the background and shows the ongoing notification with a Stop action.
  static const _serviceChannel =
      MethodChannel('com.pokerlanka.gpinger/pinger_service');

  PingerNotifier(this._ref) : super(const PingState()) {
    _serviceChannel.setMethodCallHandler((call) async {
      if (call.method == 'stopFromNotification') stop(notifyService: false);
    });
  }

  void toggle() => state.isActive ? stop() : start();

  void start() {
    _timer?.cancel();
    final shouldReset = _ref.read(resetOnStartProvider);
    final base = shouldReset ? const PingState() : state;
    state = base.copyWith(status: PingStatus.pinging, isActive: true);
    _invokeService('start', {'text': 'Pinging ${_ref.read(targetUrlProvider)}'});
    _runPing();
  }

  void stop({bool notifyService = true}) {
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(
      status: PingStatus.idle,
      isActive: false,
      isInFlight: false,
    );
    if (notifyService) _invokeService('stop');
  }

  void _updateNotification() {
    final latency = state.latencyMs != null ? '${state.latencyMs} ms' : 'failed';
    final mark = state.status == PingStatus.success ? '✓' : '✗';
    _invokeService('update', {
      'text': '$mark $latency · ${state.successCount} ok / ${state.failCount} failed',
    });
  }

  Future<void> _invokeService(String method, [Map<String, Object?>? args]) async {
    try {
      await _serviceChannel.invokeMethod(method, args);
    } on MissingPluginException {
      // Not running on Android (e.g. tests) — pinging still works in-process.
    } on PlatformException {
      // Service call failed — keep pinging in-process without a notification.
    }
  }

  void _scheduleNextPing() {
    if (!mounted || !state.isActive) return;
    final interval = _ref.read(intervalProvider);
    _timer = Timer(interval, () => _runPing());
  }

  void resetCounts() {
    if (state.isActive) return; // only allow when stopped
    state = const PingState();
  }

  Future<void> _runPing() async {
    if (!mounted || !state.isActive || state.isInFlight) return;

    final urlString = _ref.read(targetUrlProvider);
    final Uri uri;
    try {
      uri = Uri.parse(urlString);
      if (!uri.hasScheme || !['http', 'https'].contains(uri.scheme)) {
        throw const FormatException('invalid scheme');
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        status: PingStatus.failed,
        lastPingTime: DateTime.now(),
        failCount: state.failCount + 1,
        isInFlight: false,
        clearLatency: true,
      );
      _updateNotification();
      _scheduleNextPing();
      return;
    }

    state = state.copyWith(isInFlight: true);
    final startTime = DateTime.now();
    final timeout = _ref.read(pingTimeoutProvider);

    try {
      await http.head(uri).timeout(timeout);
      if (!mounted || !state.isActive) return;
      final latency = DateTime.now().difference(startTime).inMilliseconds;
      state = state.copyWith(
        status: PingStatus.success,
        latencyMs: latency,
        lastPingTime: DateTime.now(),
        successCount: state.successCount + 1,
        isInFlight: false,
      );
      _updateNotification();
    } catch (_) {
      if (!mounted || !state.isActive) return;
      state = state.copyWith(
        status: PingStatus.failed,
        lastPingTime: DateTime.now(),
        failCount: state.failCount + 1,
        isInFlight: false,
        clearLatency: true,
      );
      _updateNotification();
    }
    _scheduleNextPing();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _invokeService('stop');
    _serviceChannel.setMethodCallHandler(null);
    super.dispose();
  }
}
