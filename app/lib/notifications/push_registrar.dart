import 'dart:async';

/// The push side of the device: a token to give the backend, and the stream of
/// arriving pushes. The Firebase implementation arrives once a Firebase project
/// exists (needs google-services.json and GoogleService-Info.plist, which only
/// the account holder can create). Until then the fake keeps the wiring honest.
abstract class PushRegistrar {
  /// Current token, or null when push isn't available on this platform yet.
  Future<String?> token();

  /// Every push as it arrives, foreground or background. Each map carries the
  /// data block from backend/app/Push/RungMessage.php, alertId included.
  Stream<Map<String, dynamic>> get messages;
}

class FakeRegistrar implements PushRegistrar {
  FakeRegistrar({this.fakeToken});

  final String? fakeToken;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Future<String?> token() async => fakeToken;

  @override
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  /// Tests call this to simulate a push landing.
  void deliver(Map<String, dynamic> data) => _controller.add(data);
}
