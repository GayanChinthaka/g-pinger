import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:g_pinger/main.dart';
import 'package:g_pinger/features/pinger/pinger_service.dart';

void main() {
  testWidgets('App renders the pinger screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const GPingerApp(),
      ),
    );

    expect(find.text('G Pinger'), findsOneWidget);
  });

  test('kDefaultUrls contains expected default URLs', () {
    expect(kDefaultUrls, containsAll([
      'http://192.168.8.1/',
      'https://hutch.lk/',
      'https://wplsp.hutch.lk.prod.hosts.ooklaserver.net:8080',
      'https://oneapp.hutch.lk/',
      'http://google.com/',
    ]));
  });
}
