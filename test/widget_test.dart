// test/widget_test.dart
//
// Smoke test for top-level SilkstoneGreensApp widget.
// Full UI integration tests requiring a Supabase backend are tracked
// separately in .github/specs/development-log.md.
//
// Model unit tests live in test/models_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:greens_app/main.dart';

void main() {
  test('SilkstoneGreensApp widget can be instantiated', () {
    const app = SilkstoneGreensApp();
    expect(app, isNotNull);
  });
}
