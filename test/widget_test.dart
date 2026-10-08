import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:local_storage_lab/database_helper.dart';
import 'package:local_storage_lab/main.dart';

class _EmptyHelper extends DatabaseHelper {
  @override
  Future<List<Map<String, dynamic>>> queryAllRows() async => [];

  @override
  Future<int> queryRowCount() async => 0;
}

void main() {
  testWidgets('Roster shows empty state', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: RosterScreen(helper: _EmptyHelper())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Record count: 0'), findsOneWidget);
    expect(find.text('No festival guests yet.'), findsOneWidget);
  });
}
