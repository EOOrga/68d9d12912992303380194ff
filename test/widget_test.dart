import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ass_sauvegarde_sites/main.dart';

void main() {
  testWidgets('navigates between operations sections', (tester) async {
    await tester.pumpWidget(OpsApp(store: OpsStore.sample(readOnly: true)));

    expect(
      find.text('Pilotage quotidien des rendez-vous, taches, paie et actifs.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Planning'));
    await tester.pumpAndSettle();
    expect(find.text('Rendez-vous'), findsWidgets);
    expect(find.text('Taches'), findsWidgets);

    await tester.tap(find.text('Actifs'));
    await tester.pumpAndSettle();
    expect(find.text('Inventaire terrain'), findsOneWidget);
  });

  testWidgets('adds a local operations record', (tester) async {
    final store = OpsStore(readOnly: true);

    await tester.pumpWidget(OpsApp(store: store));
    await tester.tap(find.byTooltip('Ajouter un enregistrement'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'Inspection portail principal',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(store.items, hasLength(1));
    expect(store.items.single.title, 'Inspection portail principal');
  });
}
