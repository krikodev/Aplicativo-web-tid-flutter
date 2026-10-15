import 'dart:convert';

import 'package:apps_transporte/data/datasources/api_config.dart';
import 'package:apps_transporte/data/datasources/api_service.dart';
import 'package:apps_transporte/presentation/screens/home/cobro_screen.dart';
import 'package:apps_transporte/presentation/screens/home/evidencia_screen.dart';
import 'package:apps_transporte/presentation/screens/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> debtResponse({bool paid = false}) => {
  'success': true,
  'deuda_total': paid ? 0 : '118.00',
  'requiere_cobro': !paid,
  'estado_pago': paid ? 'PAGADO' : 'PAGO EN DESTINO',
  'estado_encomienda': 'EN DESTINO',
  'detalles': paid
      ? []
      : [
          {
            'codigo': 'TID-TEST-001',
            'id_venta': '100',
            'total_bruto': '118.00',
            'estado_venta': 'PENDIENTE',
          },
        ],
};

http.Response response(Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'base_url': ApiConfig.defaultBaseUrl,
      'id_usuario': '42',
    });
  });

  test('Normaliza los importes de deuda recibidos como texto', () async {
    final result = await http.runWithClient(
      () => ApiService.obtenerDeuda(['TID-TEST-001']),
      () => MockClient((_) async => response(debtResponse())),
    );
    expect(result['success'], true);
    expect(result['deuda_total'], 118.0);
    expect(result['detalles'][0]['total_bruto'], 118.0);
  });

  for (final changes in <Map<String, dynamic>>[
    {'deuda_total': null},
    {'deuda_total': 'NaN'},
    {'deuda_total': -1},
    {'deuda_total': 0},
    {'requiere_cobro': 'true'},
    {'requiere_cobro': false},
    {'estado_encomienda': 'EN RUTA'},
    {'detalles': []},
    {
      'detalles': [
        {'codigo': 'OTRO', 'id_venta': 100, 'total_bruto': 118},
      ],
    },
  ]) {
    test('Rechaza una deuda inconsistente: $changes', () async {
      final result = await http.runWithClient(
        () => ApiService.obtenerDeuda(['TID-TEST-001']),
        () =>
            MockClient((_) async => response({...debtResponse(), ...changes})),
      );
      expect(result['success'], false);
      expect(result['error_code'], 'invalid_debt_response');
    });
  }

  test('Una respuesta sin datos no autoriza una entrega sin cobro', () async {
    final result = await http.runWithClient(
      () => ApiService.obtenerDeuda(['TID-TEST-001']),
      () => MockClient((_) async => response({'success': true})),
    );
    expect(result['success'], false);
  });

  test('Solo consulta una encomienda por operación', () async {
    final result = await http.runWithClient(
      () => ApiService.obtenerDeuda(['A', 'B']),
      () => MockClient((_) async {
        fail('No debe contactar al servidor con varias encomiendas.');
      }),
    );
    expect(result['error_code'], 'invalid_trackings');
  });

  test('Exige dos fotos y firma antes de subir evidencias', () async {
    final result = await http.runWithClient(
      () => ApiService.registrarEntregaLote(
        trackings: ['TID-TEST-001'],
        fotos: [XFile('/synthetic/photo.png')],
        firma: null,
        montoCobrado: 0,
        descuento: 0,
        idMedioPago: null,
      ),
      () => MockClient((_) async {
        fail('No debe subir fotos si faltan evidencias.');
      }),
    );
    expect(result['success'], false);
  });

  testWidgets('Un error de BD mantiene la vista y permite volver a consultar', (
    tester,
  ) async {
    var requests = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(home: CobroScreen(trackings: ['TID-TEST-001'])),
        );
        await tester.pumpAndSettle();
        expect(find.text('Error de conexión BD'), findsOneWidget);
        expect(find.byType(CobroScreen), findsOneWidget);
        expect(find.byType(EvidenciaScreen), findsNothing);
        await tester.tap(find.text('Volver a consultar deuda'));
        await tester.pumpAndSettle();
        expect(requests, 2);
        expect(find.text('Error de conexión BD'), findsNothing);
        expect(find.text('Detalle de Cobro'), findsOneWidget);
      },
      () => MockClient((_) async {
        requests++;
        return response(
          requests == 1
              ? {'success': false, 'message': 'Error de conexión BD'}
              : debtResponse(),
        );
      }),
    );
  });

  testWidgets('Una encomienda pagada pasa a evidencias sin cobro', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: CobroScreen(trackings: ['TID-TEST-001'])),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EvidenciaScreen), findsOneWidget);
      expect(
        tester
            .widget<EvidenciaScreen>(find.byType(EvidenciaScreen))
            .montoCobrado,
        0,
      );
    }, () => MockClient((_) async => response(debtResponse(paid: true))));
  });

  testWidgets('Seleccionar otro paquete conserva una sola selección', (
    tester,
  ) async {
    final selections = <int>[];
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(home: HomeScreen(onSelectionChanged: selections.add)),
        );
        await tester.enterText(find.byType(TextField), 'TID');
        await tester.pump(const Duration(milliseconds: 301));
        await tester.pumpAndSettle();
        await tester.tap(find.text('TID-TEST-001'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('TID-TEST-002'));
        await tester.pumpAndSettle();
        expect(selections.sublist(selections.length - 2), [1, 1]);
      },
      () => MockClient(
        (_) async => response({
          'success': true,
          'data': [
            for (final code in ['TID-TEST-001', 'TID-TEST-002'])
              {
                'traking': code,
                'destinatario': 'Sintético',
                'remitente': 'Prueba',
                'estado': 'EN DESTINO',
              },
          ],
        }),
      ),
    );
  });
}
