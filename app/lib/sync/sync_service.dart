import 'api_client.dart';
import 'sync_payload.dart';
import 'sync_store.dart';

/// Registers once, syncs on demand, and always leaves the last good payload in
/// the store. A failed sync is not an error the user sees; Home shows the age of
/// the last sync instead (docs/PUSH-ARCHITECTURE.md, failure modes).
class SyncService {
  SyncService({required this.api, required this.store, required this.platform, required this.tz, required this.appVersion});

  final ApiClient api;
  final LocalStore store;
  final String platform;
  final String tz;
  final String appVersion;

  String? deviceId;

  Future<void> ensureRegistered() async {
    final creds = await store.credentials();
    if (creds != null) {
      deviceId = creds.deviceId;
      api.token = creds.token;
      return;
    }
    final reg = await api.register(platform: platform, tz: tz, appVersion: appVersion);
    deviceId = reg.deviceId;
    await store.saveCredentials(deviceId: reg.deviceId, token: reg.token);
  }

  /// Returns the fresh payload, or the cached one if the network fails, or null
  /// if there has never been a successful sync.
  Future<SyncPayload?> sync() async {
    await ensureRegistered();
    try {
      final payload = await api.sync();
      await store.save(payload);
      return payload;
    } on Exception {
      return store.latest();
    }
  }
}
