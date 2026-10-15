import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:apps_transporte/data/datasources/api_config.dart';
import 'package:apps_transporte/data/datasources/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Map<String, dynamic>> loginWith(MockClient client) => http.runWithClient(
  () => ApiService.login(' user@example.com ', 'test-password'),
  () => client,
);

http.Response jsonResponse(Map<String, dynamic> value, [int status = 200]) =>
    http.Response(
      jsonEncode(value),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'base_url': ApiConfig.defaultBaseUrl,
      'company_domain': 'old-company.example',
    });
  });

  test('El login envía tid.net.pe y guarda los IDs del usuario', () async {
    final result = await loginWith(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          '${ApiConfig.defaultBaseUrl}login_usuario.php',
        );
        expect(request.headers['X-Company-Domain'], 'tid.net.pe');
        expect(request.headers['Accept'], 'application/json');
        expect(request.bodyFields, {
          'email': 'user@example.com',
          'pass': 'test-password',
        });
        return jsonResponse({
          'success': true,
          'user': {'id_usuario': 42, 'id_terminal': 3},
        });
      }),
    );
    expect(result['success'], true);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('id_usuario'), '42');
    expect(prefs.getString('id_terminal'), '3');
  });

  test('Un rechazo de PHP con error también se muestra como message', () async {
    final result = await loginWith(
      MockClient(
        (_) async => jsonResponse({
          'success': false,
          'error': 'El dominio no está registrado.',
        }),
      ),
    );
    expect(result['success'], false);
    expect(result['message'], 'El dominio no está registrado.');
  });

  test('HTTP 500 nunca crea sesión aunque el JSON diga success', () async {
    final result = await loginWith(
      MockClient(
        (_) async => jsonResponse({
          'success': true,
          'user': {'id_usuario': 42},
        }, 500),
      ),
    );
    expect(result['success'], false);
    expect(result['status_code'], 500);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('id_usuario'), false);
  });

  test('Un HTTP 404 informa el endpoint que no se encontró', () async {
    final result = await loginWith(
      MockClient((_) async => http.Response('<html>Not found</html>', 404)),
    );
    expect(result['error_code'], 'http_error');
    expect(result['message'], contains('login_usuario.php'));
    expect(result['message'], contains('404'));
  });

  for (final body in ['', '<html>PHP error</html>', '[]']) {
    test('Controla respuestas vacías, HTML o JSON sin objeto: $body', () async {
      final result = await loginWith(
        MockClient((_) async => http.Response(body, 200)),
      );
      expect(result['success'], false);
      expect(result['error_code'], 'invalid_response');
    });
  }

  test('Identifica el error DNS de la captura', () async {
    final result = await loginWith(
      MockClient((request) async {
        throw http.ClientException(
          "ClientException with SocketException: Failed host lookup: 'api-tid.net.pe'",
          request.url,
        );
      }),
    );
    expect(result['error_code'], 'dns_error');
    expect(result['message'], contains('api-tid.net.pe'));
  });

  test('Distingue una conexión rechazada de un error DNS', () async {
    final result = await loginWith(
      MockClient((_) async {
        throw const SocketException('Connection refused');
      }),
    );
    expect(result['error_code'], 'connection_error');
  });

  test('Informa un certificado HTTPS inválido', () async {
    final result = await loginWith(
      MockClient((_) async {
        throw const HandshakeException('CERTIFICATE_VERIFY_FAILED');
      }),
    );
    expect(result['error_code'], 'tls_error');
  });

  testWidgets('Una petición sin respuesta termina al alcanzar el plazo', (
    tester,
  ) async {
    var requests = 0;
    final result = loginWith(
      MockClient((_) {
        requests++;
        return Completer<http.Response>().future;
      }),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 21));
    expect((await result)['error_code'], 'timeout');
    expect(requests, 1);
  });

  test('Una URL inválida se rechaza antes de enviar la petición', () async {
    SharedPreferences.setMockInitialValues({'base_url': 'not-a-url'});
    final result = await loginWith(
      MockClient((_) async {
        fail('No debe contactar al servidor con una URL inválida.');
      }),
    );
    expect(result['error_code'], 'configuration_error');
  });

  test('No guarda una sesión cuando falta el ID del usuario', () async {
    final result = await loginWith(
      MockClient((_) async => jsonResponse({'success': true, 'user': {}})),
    );
    expect(result['error_code'], 'invalid_user');
  });

  test('No reutiliza el terminal de una sesión anterior', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('id_terminal', 'old-terminal');
    await loginWith(
      MockClient(
        (_) async => jsonResponse({
          'success': true,
          'user': {'id_usuario': '42'},
        }),
      ),
    );
    expect(prefs.containsKey('id_terminal'), false);
  });

  test('Las consultas conservan rutas, JSON y el dominio de TID', () async {
    final requests = <http.Request>[];
    await http.runWithClient(
      () async {
        await ApiService.getEncomiendasPorDni(' 12345678 ');
        await ApiService.getHistorialEntregadas(
          filtro: ' ABC ',
          fecha: '2026-10-14',
        );
        await ApiService.obtenerDeuda(['TID-001']);
      },
      () => MockClient((request) async {
        requests.add(request);
        return jsonResponse({'success': true});
      }),
    );
    expect(requests.map((r) => r.url.pathSegments.last), [
      'get_encomiendas_dni.php',
      'get_historial.php',
      'api_obtener_deuda.php',
    ]);
    for (final request in requests) {
      expect(request.headers['X-Company-Domain'], 'tid.net.pe');
      expect(request.headers['content-type'], contains('application/json'));
    }
    expect(jsonDecode(requests[0].body), {'dni': '12345678'});
    expect(jsonDecode(requests[1].body), {
      'filtro': 'ABC',
      'fecha': '2026-10-14',
    });
    expect(jsonDecode(requests[2].body), {
      'trackings': ['TID-001'],
    });
  });

  test(
    'La entrega conserva fotos, firma, cobro, descuento e ID numérico',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('id_usuario', 42);
      final temp = await Directory.systemTemp.createTemp('tid-api-test-');
      try {
        final file = File('${temp.path}/evidence.png');
        await file.writeAsBytes([137, 80, 78, 71]);
        var uploads = 0;
        http.Request? delivery;
        final result = await http.runWithClient(
          () => ApiService.registrarEntregaLote(
            trackings: ['TID-001'],
            fotos: [XFile(file.path), XFile(file.path)],
            firma: XFile(file.path),
            montoCobrado: 20,
            descuento: 2,
            idMedioPago: 1,
          ),
          () => MockClient((request) async {
            if (request.url.host == 'api.cloudinary.com') {
              uploads++;
              return jsonResponse({
                'secure_url': 'https://example.com/photo-$uploads.png',
              });
            }
            delivery = request;
            return jsonResponse({'success': true});
          }),
        );
        expect(result['success'], true);
        expect(uploads, 3);
        expect(
          delivery!.url.pathSegments.last,
          'api_procesar_entrega_cobro.php',
        );
        expect(delivery!.headers['X-Company-Domain'], 'tid.net.pe');
        expect(delivery!.bodyFields, {
          'trackings': '["TID-001"]',
          'urls_fotos':
              '["https://example.com/photo-1.png","https://example.com/photo-2.png"]',
          'url_firma': 'https://example.com/photo-3.png',
          'monto_cobrado': '20.00',
          'descuento': '2.00',
          'id_usuario': '42',
          'id_medio_pago': '1',
        });
      } finally {
        await temp.delete(recursive: true);
      }
    },
  );
}
