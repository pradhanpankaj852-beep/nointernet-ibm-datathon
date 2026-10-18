import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_connections/nearby_connections.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Check Nearby API methods', () {
    final nearby = Nearby();
    expect(nearby.copyFileAndDeleteOriginal, isNotNull);
  });
}
