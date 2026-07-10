import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';

import '../pinger/pinger_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final customUrls = ref.watch(customUrlsProvider);
    final customIntervals = ref.watch(customIntervalsProvider);
    final pingTimeout = ref.watch(pingTimeoutProvider);
    final haptic = ref.watch(hapticFeedbackProvider);
    final resetOnStart = ref.watch(resetOnStartProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── URLs ────────────────────────────────────────────────────
          _SectionHeader('Target URLs'),
          // Default URLs (read-only)
          ...kDefaultUrls.map(
            (url) => ListTile(
              leading: const Icon(Icons.lock_outline, size: 20),
              title: Text(url, style: theme.textTheme.bodyMedium),
              dense: true,
            ),
          ),
          // Custom URLs (deletable)
          ...customUrls.map(
            (url) => Dismissible(
              key: ValueKey('url-$url'),
              direction: DismissDirection.endToStart,
              background: _DismissBackground(),
              confirmDismiss: (_) => _confirmDelete(context, '"$url"'),
              onDismissed: (_) => _deleteUrl(url),
              child: ListTile(
                leading: const Icon(Icons.link, size: 20),
                title: Text(url, style: theme.textTheme.bodyMedium),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () async {
                    if (await _confirmDelete(context, '"$url"') ?? false) {
                      _deleteUrl(url);
                    }
                  },
                ),
                dense: true,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Add custom URL'),
            onTap: () => _showAddUrlDialog(context),
          ),
          const Divider(),

          // ── Intervals ────────────────────────────────────────────────
          _SectionHeader('Ping Intervals'),
          ...kDefaultIntervalDurations.map(
            (d) => ListTile(
              leading: const Icon(Icons.timer_outlined, size: 20),
              title: Text(formatInterval(d), style: theme.textTheme.bodyMedium),
              dense: true,
            ),
          ),
          ...customIntervals.map(
            (d) => Dismissible(
              key: ValueKey('interval-${d.inSeconds}'),
              direction: DismissDirection.endToStart,
              background: _DismissBackground(),
              confirmDismiss: (_) =>
                  _confirmDelete(context, '"${formatInterval(d)}"'),
              onDismissed: (_) => _deleteInterval(d),
              child: ListTile(
                leading: const Icon(Icons.timer, size: 20),
                title:
                    Text(formatInterval(d), style: theme.textTheme.bodyMedium),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () async {
                    if (await _confirmDelete(
                            context, '"${formatInterval(d)}"') ??
                        false) {
                      _deleteInterval(d);
                    }
                  },
                ),
                dense: true,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Add custom interval'),
            onTap: () => _showAddIntervalDialog(context),
          ),
          const Divider(),

          // ── Ping Settings ────────────────────────────────────────────
          _SectionHeader('Ping Settings'),
          // Timeout
          ListTile(
            title: const Text('Ping Timeout'),
            subtitle: const Text('Max wait per request'),
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<Duration>(
                value: pingTimeout,
                items: kTimeoutOptions
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(formatInterval(d)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  ref.read(pingTimeoutProvider.notifier).state = val;
                  prefs.setInt('ping_timeout_seconds', val.inSeconds);
                },
              ),
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
          SwitchListTile(
            title: const Text('Haptic Feedback'),
            subtitle: const Text('Vibrate on button press'),
            value: haptic,
            onChanged: (v) {
              ref.read(hapticFeedbackProvider.notifier).state = v;
              prefs.setBool('haptic_feedback', v);
              if (v) Vibration.vibrate(duration: 50);
            },
          ),
          const Divider(indent: 16, endIndent: 16),
          SwitchListTile(
            title: const Text('Reset Counters on Start'),
            subtitle: const Text('Clear success/fail counts each new session'),
            value: resetOnStart,
            onChanged: (v) {
              ref.read(resetOnStartProvider.notifier).state = v;
              prefs.setBool('reset_on_start', v);
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── URL helpers ──────────────────────────────────────────────────────────

  void _deleteUrl(String url) async {
    await ref.read(customUrlsProvider.notifier).remove(url);
    // If deleted URL was selected, fall back to first default.
    if (ref.read(targetUrlProvider) == url) {
      ref.read(targetUrlProvider.notifier).state = kDefaultUrls.first;
      ref.read(sharedPreferencesProvider).setString('target_url', kDefaultUrls.first);
    }
  }

  Future<void> _showAddUrlDialog(BuildContext context) async {
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
              final s = val?.trim() ?? '';
              if (s.isEmpty) return 'Enter a URL';
              try {
                final uri = Uri.parse(s);
                if (!['http', 'https'].contains(uri.scheme)) {
                  return 'Must start with http:// or https://';
                }
                if (uri.host.isEmpty) return 'Invalid URL';
              } catch (_) {
                return 'Invalid URL format';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
  }

  // ── Interval helpers ─────────────────────────────────────────────────────

  void _deleteInterval(Duration d) async {
    await ref.read(customIntervalsProvider.notifier).remove(d);
    // If deleted interval was selected, fall back to 10 s.
    if (ref.read(intervalProvider).inSeconds == d.inSeconds) {
      const fallback = Duration(seconds: 10);
      ref.read(intervalProvider.notifier).state = fallback;
      ref.read(sharedPreferencesProvider).setInt('interval_seconds', 10);
    }
  }

  Future<void> _showAddIntervalDialog(BuildContext context) async {
    final controller = TextEditingController();
    String unit = 'seconds';

    final result = await showDialog<Duration>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          int? parsed = int.tryParse(controller.text.trim());
          Duration? preview;
          if (parsed != null && parsed > 0) {
            final secs = unit == 'minutes' ? parsed * 60 : parsed;
            if (secs <= 3600) preview = Duration(seconds: secs);
          }

          return AlertDialog(
            title: const Text('Add Custom Interval'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Value',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: unit,
                            isDense: true,
                            items: const [
                              DropdownMenuItem(
                                  value: 'seconds', child: Text('Seconds')),
                              DropdownMenuItem(
                                  value: 'minutes', child: Text('Minutes')),
                            ],
                            onChanged: (v) =>
                                setDialogState(() => unit = v ?? unit),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (preview != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Preview: ${formatInterval(preview)}',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: preview == null
                    ? null
                    : () => Navigator.pop(ctx, preview),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );

    controller.dispose();
    if (!mounted || result == null) return;
    await ref.read(customIntervalsProvider.notifier).add(result);
  }

  // ── Shared helpers ───────────────────────────────────────────────────────

  Future<bool?> _confirmDelete(BuildContext context, String label) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove item?'),
        content: Text('Remove $label from the list?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _DismissBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      color: Theme.of(context).colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(
        Icons.delete_outline,
        color: Theme.of(context).colorScheme.onErrorContainer,
      ),
    );
  }
}
