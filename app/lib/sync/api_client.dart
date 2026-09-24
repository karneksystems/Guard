import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sync_payload.dart';

class ApiException implements Exception {
  ApiException(this.status, this.body);

  final int status;
  final String body;

  @override
  String toString() => 'ApiException($status): $body';
}

class Registration {
  Registration(this.deviceId, this.token);

  final String deviceId;
  final String token;
}

/// Thin client over backend/routes/api.php. No retries here; the sync service
/// decides when to try again, and the local mirror covers the gap.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client, this.token})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  String? token;

  Map<String, String> _headers({bool auth = true}) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (auth && token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path) => Uri.parse('$baseUrl/api$path');

  Future<Map<String, dynamic>> _json(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw ApiException(r.statusCode, r.body);
    }
    return Future.value(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Registration> register({required String platform, required String tz, required String appVersion}) async {
    final r = await _client.post(_uri('/devices'),
        headers: _headers(auth: false),
        body: jsonEncode({'platform': platform, 'tz': tz, 'app_version': appVersion}));
    final json = await _json(r);
    token = json['token'] as String;
    return Registration(json['deviceId'] as String, token!);
  }

  Future<SyncPayload> sync() async {
    final r = await _client.get(_uri('/sync'), headers: _headers());
    return SyncPayload.fromJson(await _json(r));
  }

  Future<void> updateDevice({String? pushToken, String? notifState, String? tz, String? appVersion}) async {
    final r = await _client.patch(_uri('/device'),
        headers: _headers(),
        body: jsonEncode({
          'push_token': ?pushToken,
          'notif_state': ?notifState,
          'tz': ?tz,
          'app_version': ?appVersion,
        }));
    await _json(r);
  }

  Future<void> putSettings(Map<String, dynamic> settings) async {
    final r = await _client.put(_uri('/settings'), headers: _headers(), body: jsonEncode(settings));
    await _json(r);
  }

  Future<void> putInstruments(List<Map<String, dynamic>> instruments) async {
    final r = await _client.put(_uri('/instruments'),
        headers: _headers(), body: jsonEncode({'instruments': instruments}));
    await _json(r);
  }

  /// Every firm pack's header: id, name, version, verified state, account types.
  Future<List<Map<String, dynamic>>> listPacks() async {
    final r = await _client.get(_uri('/packs'), headers: _headers(auth: false));
    final json = await _json(r);
    return (json['packs'] as List? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getPack(String firmId) async {
    final r = await _client.get(_uri('/packs/$firmId'), headers: _headers(auth: false));
    return _json(r);
  }

  /// A store receipt for the server to verify. Returns the new pro_until, or null.
  Future<DateTime?> postEntitlement({required String platform, required String plan, required String receipt}) async {
    final r = await _client.post(_uri('/entitlement'),
        headers: _headers(), body: jsonEncode({'platform': platform, 'plan': plan, 'receipt': receipt}));
    final json = await _json(r);
    final until = json['proUntil'] as String?;
    return until == null ? null : DateTime.parse(until).toUtc();
  }

  Future<void> postJournal({required String windowId, required String outcome, required DateTime atUtc}) async {
    final r = await _client.post(_uri('/journal'),
        headers: _headers(),
        body: jsonEncode({
          'window_id': windowId,
          'outcome': outcome,
          'at_utc': atUtc.toUtc().toIso8601String(),
        }));
    await _json(r);
  }
}
