import 'dart:convert';

import 'package:apps_transporte/presentation/screens/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final ruc in ['10123456789', '20123456789']) {
    testWidgets('La pantalla busca RUC $ruc y muestra crédito', (tester) async {
      SharedPreferences.setMockInitialValues({
        'company_domain': 'tid.net.pe',
      });
      final requests = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'traking': 'TID-001',
                'estado': 'EN DESTINO',
                'estado_pago': 'CREDITO',
                'destinatario': 'Destinatario de prueba',
                'remitente': 'Remitente de prueba',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
        await tester.enterText(find.byType(TextField).first, ruc);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(requests, [
          {'dni': ruc, 'tipo': 'documento'},
        ]);
        expect(find.text('TID-001'), findsOneWidget);
        expect(find.text('Modalidad: CREDITO'), findsOneWidget);
      }, () => client);
    });
  }
}
