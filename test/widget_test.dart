import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lan_secure_messenger/main.dart';

void main() {
  testWidgets('renders the messenger bootstrap screen', (tester) async {
    await tester.pumpWidget(const LanSecureMessengerApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
