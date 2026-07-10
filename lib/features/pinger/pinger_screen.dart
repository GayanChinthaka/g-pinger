import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';

import '../../core/models/ping_state.dart';
import '../about/about_screen.dart';
import '../donate/donate_screen.dart';
import '../settings/settings_screen.dart';
import 'pinger_service.dart';

const _kCustomOption = 'Custom URL...';

// ── Screen ──────────────────────────────────────────────────────────────────

class PingerScreen extends ConsumerWidget {
  const PingerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pingState = ref.watch(pingerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('G Pinger'),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Menu',
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()));
                case 'donate':
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const DonateScreen()));
                case 'about':
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'donate',
                child: ListTile(
                  leading: Icon(Icons.favorite_outline),
                  title: Text('Donate'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'about',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('About Us'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const _PingButton(),
            const SizedBox(height: 32),
            // Stats card fades from dim to full after first ping
            AnimatedOpacity(
              opacity: pingState.lastPingTime == null ? 0.6 : 1.0,
              duration: const Duration(milliseconds: 400),
              child: _StatsCard(state: pingState),
            ),
            const SizedBox(height: 24),
            const _SettingsSection(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Ping button ──────────────────────────────────────────────────────────────

class _PingButton extends ConsumerStatefulWidget {
  const _PingButton();

  @override
  ConsumerState<_PingButton> createState() => _PingButtonState();
}

class _PingButtonState extends ConsumerState<_PingButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late final AnimationController _ringController;

  static const _neonColor = Color(0xFF00E5FF);

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  void _restartRing(Duration interval) {
    _ringController.duration = interval;
    _ringController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isActive = ref.watch(pingerProvider.select((s) => s.isActive));
    final interval = ref.watch(intervalProvider);

    // Reset the neon ring every time a new ping fires, and stop it once
    // pinging is turned off, so it always represents time-to-next-ping.
    ref.listen<PingState>(pingerProvider, (previous, next) {
      if (!next.isActive) {
        _ringController.stop();
        _ringController.value = 0;
        return;
      }
      final justStarted = !(previous?.isActive ?? false);
      final pingJustFired = next.lastPingTime != previous?.lastPingTime;
      if (justStarted || pingJustFired) _restartRing(interval);
    });

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        if (ref.read(hapticFeedbackProvider)) Vibration.vibrate(duration: 50);
        ref.read(pingerProvider.notifier).toggle();
      },
      child: SizedBox(
        width: 216,
        height: 216,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _ringController,
              builder: (context, _) => CustomPaint(
                size: const Size(216, 216),
                painter: _NeonRingPainter(
                  progress: _ringController.value,
                  color: _neonColor,
                ),
              ),
            ),
            AnimatedScale(
              scale: _isPressed ? 0.93 : 1.0,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? Colors.red.shade600 : Colors.green.shade600,
                  boxShadow: [
                    BoxShadow(
                      // ignore: deprecated_member_use
                      color: (isActive ? Colors.red : Colors.green).withOpacity(0.35),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isActive ? Icons.stop_rounded : Icons.play_arrow_rounded,
                        key: ValueKey(isActive),
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isActive ? 'STOP' : 'START',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A glowing neon arc that sweeps a full circle once per ping interval,
// tracing progress toward the next ping while pinging is active.
class _NeonRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _NeonRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - 4,
    );
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);

    final corePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweepAngle, false, corePaint);
  }

  @override
  bool shouldRepaint(covariant _NeonRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// ── Stats card ───────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final PingState state;
  const _StatsCard({required this.state});

  String get _statusText {
    if (state.isInFlight) return 'Pinging...';
    return switch (state.status) {
      PingStatus.idle => 'Idle',
      PingStatus.pinging => 'Pinging...',
      PingStatus.success => 'Success',
      PingStatus.failed => 'Failed',
    };
  }

  Color _statusColor(BuildContext context) {
    if (state.isInFlight) return Theme.of(context).colorScheme.primary;
    return switch (state.status) {
      PingStatus.idle => Theme.of(context).colorScheme.outline,
      PingStatus.pinging => Theme.of(context).colorScheme.primary,
      PingStatus.success => Colors.green.shade600,
      PingStatus.failed => Colors.red.shade600,
    };
  }

  String get _latencyText =>
      state.latencyMs == null ? '-- ms' : '${state.latencyMs} ms';

  String get _lastPingText {
    final t = state.lastPingTime;
    if (t == null) return '--:--:--';
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _StatRow(
              label: 'Status',
              value: _statusText,
              valueColor: _statusColor(context),
              isBold: true,
            ),
            const Divider(height: 24),
            _StatRow(label: 'Latency', value: _latencyText),
            const SizedBox(height: 10),
            _StatRow(label: 'Last ping', value: _lastPingText),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Success',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      Text(
                        '${state.successCount}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Failed',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      Text(
                        '${state.failCount}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _StatRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: valueColor,
            fontWeight: isBold ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }
}

// ── Settings section ─────────────────────────────────────────────────────────

class _SettingsSection extends ConsumerStatefulWidget {
  const _SettingsSection();

  @override
  ConsumerState<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends ConsumerState<_SettingsSection> {
  @override
  Widget build(BuildContext context) {
    final isActive = ref.watch(pingerProvider.select((s) => s.isActive));
    final interval = ref.watch(intervalProvider);
    final targetUrl = ref.watch(targetUrlProvider);
    final customUrls = ref.watch(customUrlsProvider);
    final allIntervals = ref.watch(allIntervalsProvider);
    // Ensure the current interval is always selectable even if stale.
    final dropdownInterval =
        allIntervals.any((d) => d.inSeconds == interval.inSeconds)
            ? interval
            : const Duration(seconds: 10);

    final allUrls = [...kDefaultUrls, ...customUrls];
    if (!allUrls.contains(targetUrl)) allUrls.insert(0, targetUrl);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // ── Interval picker ──────────────────────────────────────
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Ping Interval',
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                enabled: !isActive,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Duration>(
                  value: dropdownInterval,
                  isExpanded: true,
                  isDense: true,
                  onChanged: isActive
                      ? null
                      : (val) {
                          if (val == null) return;
                          ref.read(intervalProvider.notifier).state = val;
                          ref
                              .read(sharedPreferencesProvider)
                              .setInt('interval_seconds', val.inSeconds);
                        },
                  items: allIntervals
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(formatInterval(d)),
                          ))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ── URL picker ───────────────────────────────────────────
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Target URL',
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                enabled: !isActive,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: targetUrl,
                  isExpanded: true,
                  isDense: true,
                  onChanged: isActive
                      ? null
                      : (val) async {
                          if (val == null) return;
                          if (val == _kCustomOption) {
                            await _showCustomUrlDialog();
                            // Force rebuild so dropdown reverts to targetUrl
                            // if the dialog was dismissed without saving.
                            if (mounted) setState(() {});
                          } else {
                            ref.read(targetUrlProvider.notifier).state = val;
                            ref
                                .read(sharedPreferencesProvider)
                                .setString('target_url', val);
                          }
                        },
                  items: [
                    ...allUrls.map(
                      (url) => DropdownMenuItem(
                        value: url,
                        child: Text(
                          url,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    const DropdownMenuItem(
                      value: _kCustomOption,
                      child: Text(
                        _kCustomOption,
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isActive)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Stop pinging to change settings',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomUrlDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom URL'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://example.com/',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            validator: (val) {
              final trimmed = val?.trim() ?? '';
              if (trimmed.isEmpty) return 'Enter a URL';
              try {
                final uri = Uri.parse(trimmed);
                if (!uri.hasScheme ||
                    !['http', 'https'].contains(uri.scheme)) {
                  return 'URL must start with http:// or https://';
                }
                if (!uri.hasAuthority || uri.host.isEmpty) {
                  return 'Invalid URL — no host found';
                }
              } catch (_) {
                return 'Invalid URL format';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (!mounted || result == null || result.isEmpty) return;

    await ref.read(customUrlsProvider.notifier).add(result);
    ref.read(targetUrlProvider.notifier).state = result;
    ref.read(sharedPreferencesProvider).setString('target_url', result);
  }
}
