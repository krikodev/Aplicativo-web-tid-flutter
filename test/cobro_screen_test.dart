import 'dart:convert';

import 'package:apps_transporte/presentation/screens/home/cobro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'company_domain': 'tid.net.pe'});
  });

  testWidgets('100 a cobrar, usuario escribe 70 y ve descuento 30', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: CobroScreen(trackings: ['TID-001'])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total a cobrar:'), findsOneWidget);
      expect(find.text('¿Cuánto cobra realmente? (S/):'), findsOneWidget);
      expect(find.text('S/ 100.00'), findsWidgets);
      expect(find.text('S/ 0.00'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '70.00');
      await tester.pump();

      expect(find.text('S/ 30.00'), findsOneWidget);
      expect(find.text('Cobrar S/ 70.00 y Tomar Foto'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '110');
      await tester.pump();
      expect(find.text('Ingresa el importe cobrado'), findsOneWidget);
    }, () => MockClient((request) async {
      expect(request.url.pathSegments.last, 'api_obtener_deuda.php');
      return http.Response(
        jsonEncode({
          'success': true,
          'deuda_total': 100,
          'requiere_cobro': true,
          'detalles': [
            {
              'codigo': 'TID-001',
              'id_venta': 10,
              'estado_venta': 'PENDIENTE',
              'total_bruto': 100
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }));
  });

  testWidgets('Crédito sin cobro pasa directamente a foto y firma', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: CobroScreen(trackings: ['TID-CREDITO'])),
      );
      await tester.pumpAndSettle();
      expect(find.text('Foto y firma de entrega'), findsOneWidget);
      expect(find.text('Fotografía de entrega'), findsOneWidget);
      expect(find.text('Firma del receptor (obligatoria)'), findsOneWidget);
    }, () => MockClient((request) async {
      return http.Response(
        jsonEncode({
          'success': true,
          'deuda_total': 0,
          'requiere_cobro': false,
          'estado_pago': 'CREDITO',
          'detalles': [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }));
  });
}
