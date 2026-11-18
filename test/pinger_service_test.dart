import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:g_pinger/features/pinger/pinger_service.dart';

void main() {
  testWidgets('stop then start during an in-flight ping keeps one ping loop',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      // The first request is slow, so it is still in flight when the user
      // stops and restarts. Later requests are fast.
      await Future<void>.delayed(Duration(milliseconds: calls == 1 ? 400 : 10));
      return http.Response('', 200);
    });

    await http.runWithClient(() async {
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        intervalProvider
            .overrideWith((_) => const Duration(milliseconds: 500)),
      ]);
      final notifier = container.read(pingerProvider.notifier);

      notifier.start();
      await tester.pump(const Duration(milliseconds: 50));
      notifier.stop();
      notifier.start();
      await tester.pump(const Duration(milliseconds: 3000));

      // One loop: the restart ping at 50 ms, then one every 510 ms
      // (500 ms interval + 10 ms request) → 560, 1070, 1580, 2090, 2600.
      // The slow first request belongs to the old session and must be dropped.
      expect(calls, 7);
      expect(container.read(pingerProvider).successCount, 6);

      notifier.stop();
      container.dispose();
    }, () => client);
  });

  test('a default URL is not stored again as a custom URL', () async {
    SharedPreferences.setMockInitialValues({
      // Saved by an older version that allowed the duplicate.
      'custom_urls': [kDefaultUrls.last, 'https://example.com/'],
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);

    expect(container.read(customUrlsProvider), ['https://example.com/']);

    await container.read(customUrlsProvider.notifier).add(kDefaultUrls.first);
    expect(container.read(customUrlsProvider), ['https://example.com/']);
  });
}
