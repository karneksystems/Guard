import 'dart:convert';
import 'dart:io';

import 'package:rule_engine/rule_engine.dart';
import 'package:test/test.dart';

const casesDir = '../../fixtures/rule-engine/cases';
const packsDir = '../../packs';

Map<String, dynamic> loadPack(String firmId) =>
    jsonDecode(File('$packsDir/$firmId.json').readAsStringSync()) as Map<String, dynamic>;

/// Round-trips through JSON so Dart objects compare as plain maps and lists.
dynamic plain(Object? v) => jsonDecode(jsonEncode(v));

void main() {
  final files = Directory(casesDir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('there are thirteen fixture cases', () {
    expect(files.length, 13);
  });

  for (final file in files) {
    final name = file.uri.pathSegments.last;
    test(name, () {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json.containsKey('expected'), isTrue,
          reason: '$name has no expected block; run reference.py --write');
      final engine = RuleEngine(loadPack);

      final Map<String, dynamic> got;
      if (json.containsKey('inputBefore')) {
        final before = engine.computeWindows(json['inputBefore'] as Map<String, dynamic>);
        final after = engine.computeWindows(json['inputAfter'] as Map<String, dynamic>);
        final r = RuleEngine.reconcile(
          engine.computeLadder((json['inputBefore'] as Map)['userId'] as String, before.windows),
          engine.computeLadder((json['inputAfter'] as Map)['userId'] as String, after.windows),
        );
        got = {
          'cancelledAlertIds': r.cancelledAlertIds,
          'createdAlertIds': r.createdAlertIds,
          'keptAlertIds': r.keptAlertIds,
          'windowsAfter': after.windows.map((w) => w.toJson()).toList(),
        };
      } else {
        final input = json['input'] as Map<String, dynamic>;
        final result = engine.computeWindows(input);
        got = {
          'windows': result.windows.map((w) => w.toJson()).toList(),
          'ladder': engine
              .computeLadder(input['userId'] as String, result.windows)
              .map((r) => r.toJson())
              .toList(),
          'notes': result.notes,
        };
      }

      expect(plain(got), equals(plain(json['expected'])),
          reason: 'Engine output drifted from $name. reference.py is the tie-breaker.');
    });
  }
}
