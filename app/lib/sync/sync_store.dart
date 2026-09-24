import 'dart:convert';
import 'dart:io';

import 'sync_payload.dart';

/// What the app keeps on the device: the last sync payload, the device
/// credentials, and a small prefs map. Gated app identifiers live in prefs and
/// are never part of the sync payload.
abstract class LocalStore {
  Future<SyncPayload?> latest();
  Future<void> save(SyncPayload payload);
  Future<({String deviceId, String token})?> credentials();
  Future<void> saveCredentials({required String deviceId, required String token});
  Future<Map<String, dynamic>> prefs();
  Future<void> savePrefs(Map<String, dynamic> patch);
}

/// In-memory store for widget tests, which run under a fake clock where real
/// file I/O never completes.
class MemoryStore implements LocalStore {
  SyncPayload? _payload;
  ({String deviceId, String token})? _creds;
  Map<String, dynamic> _prefs = {};

  @override
  Future<SyncPayload?> latest() async => _payload;

  @override
  Future<void> save(SyncPayload payload) async => _payload = payload;

  @override
  Future<({String deviceId, String token})?> credentials() async => _creds;

  @override
  Future<void> saveCredentials({required String deviceId, required String token}) async =>
      _creds = (deviceId: deviceId, token: token);

  @override
  Future<Map<String, dynamic>> prefs() async => Map.unmodifiable(_prefs);

  @override
  Future<void> savePrefs(Map<String, dynamic> patch) async => _prefs = {..._prefs, ...patch};
}

/// File-backed store: JSON files in a directory the platform gives us. Drift
/// replaces this when the journal and history need querying; for the horizon
/// data a file is the right size.
class SyncStore implements LocalStore {
  SyncStore(this.directory);

  final Directory directory;

  File get _payloadFile => File('${directory.path}/sync.json');
  File get _credsFile => File('${directory.path}/device.json');
  File get _prefsFile => File('${directory.path}/prefs.json');

  @override
  Future<SyncPayload?> latest() async {
    if (!await _payloadFile.exists()) return null;
    try {
      final json = jsonDecode(await _payloadFile.readAsString()) as Map<String, dynamic>;
      final fetched = DateTime.tryParse(json['fetchedAtUtc'] as String? ?? '');
      return SyncPayload.fromJson(json, fetchedAt: fetched);
    } on FormatException {
      return null; // a torn write is treated as no cache, never as a crash
    }
  }

  @override
  Future<void> save(SyncPayload payload) => _writeAtomic(_payloadFile, payload.toJson());

  @override
  Future<({String deviceId, String token})?> credentials() async {
    if (!await _credsFile.exists()) return null;
    final json = jsonDecode(await _credsFile.readAsString()) as Map<String, dynamic>;
    return (deviceId: json['deviceId'] as String, token: json['token'] as String);
  }

  @override
  Future<void> saveCredentials({required String deviceId, required String token}) =>
      _writeAtomic(_credsFile, {'deviceId': deviceId, 'token': token});

  @override
  Future<Map<String, dynamic>> prefs() async {
    if (!await _prefsFile.exists()) return const {};
    try {
      return jsonDecode(await _prefsFile.readAsString()) as Map<String, dynamic>;
    } on FormatException {
      return const {};
    }
  }

  /// Merges into the existing prefs.
  @override
  Future<void> savePrefs(Map<String, dynamic> patch) async {
    final merged = {...await prefs(), ...patch};
    await _writeAtomic(_prefsFile, merged);
  }

  Future<void> _writeAtomic(File file, Map<String, dynamic> json) async {
    await directory.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(json), flush: true);
    await tmp.rename(file.path);
  }
}
