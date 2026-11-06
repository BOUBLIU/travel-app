// Captures d'écran du parcours avec les vraies polices.
// Lancer : flutter test screenshots --update-goldens
// Les images sont écrites dans screenshots/out/.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../test/flow.dart';

Future<void> _font(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'fr_FR';
    await initializeDateFormatting('fr_FR');
    await _font('Inter', [
      for (final w in ['400Regular', '500Medium', '600SemiBold', '700Bold']) 'assets/fonts/Inter_$w.ttf',
    ]);
    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter-dl/flutter';
    await _font('MaterialIcons', ['$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    final home = Platform.environment['HOME'];
    final cupertino = Directory('$home/.pub-cache/hosted/pub.dev')
        .listSync()
        .whereType<Directory>()
        .firstWhere((d) => d.path.contains('cupertino_icons-'));
    await _font('packages/cupertino_icons/CupertinoIcons', ['${cupertino.path}/assets/CupertinoIcons.ttf']);
  });

  testWidgets('captures', (tester) async {
    await runFullFlow(tester, shot: (name) async {
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
    });
  });
}
