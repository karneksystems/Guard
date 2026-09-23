import 'dart:convert';
import 'dart:io';

import 'sync_payload.dart';

/// Local store: the last sync payload and the device credentials, as JSON files
/// in a directory the platform gives us. Drift replaces this when the journal and
/// history need querying; for the horizon data a file is the right size.
///
/// Gated app identifiers are deliberately not stored here; they live with the
/// platform gate module and never travel with the sync payload.
class SyncStore {
  SyncStore(this.directory);

  final Directory directory;

  File get _payloadFile => File('${directory.path}/sync.json');
  File get _credsFile => File('${directory.path}/device.json');

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

  Future<void> save(SyncPayload payload) async {
    await directory.create(recursive: true);
    final tmp = File('${_payloadFile.path}.tmp');
    await tmp.writeAsString(jsonEncode(payload.toJson()), flush: true);
    await tmp.rename(_payloadFile.path);
  }

  Future<({String deviceId, String token})?> credentials() async {
    if (!await _credsFile.exists()) return null;
    final json = jsonDecode(await _credsFile.readAsString()) as Map<String, dynamic>;
    return (deviceId: json['deviceId'] as String, token: json['token'] as String);
  }

  Future<void> saveCredentials({required String deviceId, required String token}) async {
    await directory.create(recursive: true);
    await _credsFile.writeAsString(jsonEncode({'deviceId': deviceId, 'token': token}), flush: true);
  }
}
