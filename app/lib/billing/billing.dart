/// One SKU, monthly or yearly. The store SDKs (StoreKit, Play Billing, the
/// Microsoft Store) plug in behind this interface; until the store accounts
/// exist the fake stands in and the backend's fake verifier accepts its receipt.
enum Plan { monthly, yearly }

class Purchase {
  const Purchase({required this.platform, required this.plan, required this.receipt});

  /// apple, google, microsoft, fake
  final String platform;
  final Plan plan;

  /// Opaque store receipt or purchase token, verified server-side.
  final String receipt;
}

abstract class Billing {
  /// Localised prices for display, or null when the store hasn't answered yet.
  Future<({String monthly, String yearly})?> prices();

  /// Null when the user cancelled.
  Future<Purchase?> buy(Plan plan);

  /// Purchases the store still holds for this account.
  Future<List<Purchase>> restore();
}

class FakeBilling implements Billing {
  FakeBilling({this.cancel = false});

  final bool cancel;
  final List<Plan> bought = [];

  @override
  Future<({String monthly, String yearly})?> prices() async => (monthly: '£4.99', yearly: '£39');

  @override
  Future<Purchase?> buy(Plan plan) async {
    if (cancel) return null;
    bought.add(plan);
    return Purchase(platform: 'fake', plan: plan, receipt: 'fake:${plan.name}');
  }

  @override
  Future<List<Purchase>> restore() async =>
      [for (final p in bought) Purchase(platform: 'fake', plan: p, receipt: 'fake:${p.name}')];
}
