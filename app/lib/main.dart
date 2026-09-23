import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'shell/adaptive_shell.dart';
import 'state/guard_state.dart';
import 'sync/api_client.dart';
import 'sync/sync_service.dart';
import 'sync/sync_store.dart';
import 'theme/tokens.dart';

/// Backend base URL, e.g. --dart-define=GUARD_API=https://guard.example.com.
/// Empty means no backend: the app runs on sample data.
const String kApiBaseUrl = String.fromEnvironment('GUARD_API');
const String kAppVersion = '0.1.0';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = GuardState();
  runApp(GuardApp(state: state));
  if (kApiBaseUrl.isNotEmpty) {
    unawaited(_startSync(state));
  }
}

Future<void> _startSync(GuardState state) async {
  final dir = await getApplicationSupportDirectory();
  final store = SyncStore(dir);
  final cached = await store.latest();
  if (cached != null) state.update(cached);

  final service = SyncService(
    api: ApiClient(baseUrl: kApiBaseUrl),
    store: store,
    platform: defaultTargetPlatform.name.toLowerCase(),
    tz: DateTime.now().timeZoneName,
    appVersion: kAppVersion,
  );
  final fresh = await service.sync();
  if (fresh != null) state.update(fresh);
}

class GuardApp extends StatelessWidget {
  const GuardApp({super.key, this.state});

  final GuardState? state;

  @override
  Widget build(BuildContext context) {
    return GuardScope(
      state: state ?? GuardState(),
      child: MaterialApp(
        title: 'Guard',
        debugShowCheckedModeBanner: false,
        theme: GuardTheme.light(),
        darkTheme: GuardTheme.dark(),
        themeMode: ThemeMode.system,
        home: const AdaptiveShell(),
      ),
    );
  }
}
