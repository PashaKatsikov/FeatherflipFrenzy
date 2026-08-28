/// In-game event sink. Attribution and AppsFlyer live in the yard-flow
/// tracker so this class never starts a second SDK or stores a plaintext key.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  Future<void> prepare() async {}

  Future<void> start() async {}

  void logEvent(String name, [Map<String, dynamic>? values]) {
    assert(() {
      // ignore: avoid_print
      print('[FF.COOP] game event $name $values');
      return true;
    }());
  }
}
