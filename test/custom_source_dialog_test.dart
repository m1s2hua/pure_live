import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/dialogs/custom_source_dialog.dart';
import 'package:pure_live/modules/live_play/states/live_play_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, Map<String, dynamic>> translations;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    translations = {
      for (final language in ['zh', 'en'])
        language: jsonDecode(await File('assets/translations/$language.json').readAsString()) as Map<String, dynamic>,
    };
  });

  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets('an invalid URL is reported without starting playback', (tester) async {
    final calls = <String>[];
    await _openHost(tester, translations: translations, applySource: (url) async {
      calls.add(url);
      return true;
    });
    await _showDialog(tester);

    await tester.tap(find.byKey(const ValueKey('custom-source-confirm')));
    await tester.pump();

    expect(calls, isEmpty);
    expect(find.byKey(const ValueKey('custom-source-error')), findsOneWidget);
    expect(find.text('Replace playback source'), findsOneWidget);
  });

  testWidgets('a successful replacement closes the dialog', (tester) async {
    final calls = <String>[];
    await _openHost(tester, translations: translations, applySource: (url) async {
      calls.add(url);
      return true;
    });
    await _showDialog(tester);

    await tester.enterText(find.byKey(const ValueKey('custom-source-url-field')), 'https://fixture/live.flv');
    await tester.tap(find.byKey(const ValueKey('custom-source-confirm')));
    await tester.pumpAndSettle();

    expect(calls, ['https://fixture/live.flv']);
    expect(find.text('Replace playback source'), findsNothing);
  });

  testWidgets('a rejected replacement stays open and reports the failure', (tester) async {
    await _openHost(tester, translations: translations, applySource: (_) async => false);
    await _showDialog(tester);

    await tester.enterText(find.byKey(const ValueKey('custom-source-url-field')), 'https://fixture/live.flv');
    await tester.tap(find.byKey(const ValueKey('custom-source-confirm')));
    await tester.pump();

    expect(find.byKey(const ValueKey('custom-source-error')), findsOneWidget);
    expect(find.text('Replace playback source'), findsOneWidget);
  });
}

Future<void> _openHost(
  WidgetTester tester, {
  required Map<String, Map<String, dynamic>> translations,
  required CustomSourceApplier applySource,
  String language = 'en',
}) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('zh'), Locale('en')],
      startLocale: Locale(language),
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: _LoadedTranslations(translations),
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  key: const ValueKey('open-custom-source'),
                  onPressed: () => CustomSourceDialog.show(
                    context: context,
                    controller: _FakeLivePlayController(),
                    applySource: applySource,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _showDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open-custom-source')));
  await tester.pumpAndSettle();
}

class _LoadedTranslations extends AssetLoader {
  const _LoadedTranslations(this.translations);
  final Map<String, Map<String, dynamic>> translations;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => translations[locale.languageCode]!;
}

class _FakeLivePlayController extends GetxController implements LivePlayController {
  @override
  final Rx<LivePlayState> state = const LivePlayState().obs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
