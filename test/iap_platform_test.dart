import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadhopper/services/iap_service.dart';

void main() {
  test('iOS maps to the single Gold Star product', () {
    expect(HopperStore.productIdsFor(TargetPlatform.iOS), {'roadhopperstar'});
    expect(HopperStore.starId, 'roadhopperstar');
  });
  test('Android maps to coffee + chocolate only', () {
    expect(HopperStore.productIdsFor(TargetPlatform.android),
        {'roadhoppercoffee', 'roadhopperchocolate'});
    expect(HopperStore.productIdsFor(TargetPlatform.android),
        isNot(contains('roadhopperstar')));
  });
}
