import 'dart:convert';
import 'package:apps_transporte/data/datasources/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  http.Response jsonResponse(String body, int status) => http.Response(
    body,
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  const token =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  Map<String, dynamic> session() => {
    'success': true,
    'access_token': token,
    'expires_at': DateTime.now()
        .toUtc()
        .add(const Duration(hours: 8))
        .toIso8601String(),
    'user': {'id_usuario': 1, 'nombres': 'Operador'},
  };
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'base_url': 'http://10.0.2.2:8080/',
      'company_domain': 'tid.net.pe',
    });
    await ApiService.clearSession();
  });
  tearDown(() => ApiService.client.close());

  test('Normaliza URL conservando el puerto y la carpeta', () {
    expect(
      ApiService.normalizeBaseUrl(
        ' http://192.168.1.20:8080/mobile-api/public ',
      ),
      'http://192.168.1.20:8080/mobile-api/public/',
    );
    expect(
      () => ApiService.normalizeBaseUrl('localhost:8080'),
      throwsFormatException,
    );
    expect(
      () => ApiService.normalizeBaseUrl('http://user:pass@example.com/'),
      throwsFormatException,
    );
    expect(
      () => ApiService.normalizeBaseUrl('http://example.com/?token=x'),
      throwsFormatException,
    );
  });
  test('Normaliza empresa y rechaza URLs como dominio', () {
    expect(ApiService.normalizeCompanyDomain(' TID.NET.PE '), 'tid.net.pe');
    expect(
      () => ApiService.normalizeCompanyDomain('https://tid.net.pe'),
      throwsFormatException,
    );
  });
  test(
    'Prueba conexión antes de guardar y no envía token a otro servidor',
    () async {
      ApiService.client = MockClient((request) async {
        expect(request.url.toString(), 'http://localhost:8080/v1/health');
        expect(request.headers['X-Company-Domain'], 'jrcargo.com.pe');
        expect(request.headers.containsKey('Authorization'), isFalse);
        expect(request.followRedirects, isFalse);
        return jsonResponse(
          jsonEncode({
            'success': true,
            'api_version': 'v1',
            'read_only': true,
            'company': {'domain': 'jrcargo.com.pe'},
          }),
          200,
        );
      });
      expect(
        (await ApiService.configure(
          'http://localhost:8080',
          'jrcargo.com.pe',
        ))['success'],
        true,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('base_url'), 'http://localhost:8080/');
      expect(prefs.getString('company_domain'), 'jrcargo.com.pe');
      expect(ApiService.hasSession, false);
    },
  );
  test('Fallo de conexión conserva la configuración anterior', () async {
    ApiService.client = MockClient(
      (request) async => jsonResponse(
        jsonEncode({'success': false, 'message': 'Empresa no registrada'}),
        404,
      ),
    );
    expect(
      (await ApiService.configure(
        'http://localhost:8080',
        'bad.pe',
      ))['success'],
      false,
    );
    expect(
      (await SharedPreferences.getInstance()).getString('company_domain'),
      'tid.net.pe',
    );
  });
  test('Respuesta de otro producto no se guarda como API', () async {
    ApiService.client = MockClient(
      (request) async => jsonResponse('{"success":true}', 200),
    );
    expect(
      (await ApiService.configure(
        'http://localhost:8080',
        'tid.net.pe',
      ))['success'],
      false,
    );
  });
  test('Login JSON conserva espacios y usa token en consultas', () async {
    ApiService.client = MockClient((request) async {
      if (request.url.path.endsWith('login')) {
        expect(request.headers['Content-Type'], contains('application/json'));
        expect(jsonDecode(request.body)['password'], ' p4ss ');
        return jsonResponse(jsonEncode(session()), 200);
      }
      expect(request.method, 'GET');
      expect(request.headers['Authorization'], 'Bearer $token');
      expect(request.headers['X-Company-Domain'], 'tid.net.pe');
      expect(request.url.queryParameters['dni'], '12345678');
      return jsonResponse('{"success":true,"data":[]}', 200);
    });
    expect(
      (await ApiService.login(' operador@example.com ', ' p4ss '))['success'],
      true,
    );
    expect(ApiService.hasSession, true);
    expect(
      (await ApiService.getEncomiendasPorDni('12345678'))['success'],
      true,
    );
    expect(
      (await SharedPreferences.getInstance()).containsKey('is_logged_in'),
      false,
    );
  });
  test('Sesión inválida no permite entrar', () async {
    ApiService.client = MockClient(
      (request) async => jsonResponse('{"success":true,"user":{}}', 200),
    );
    expect((await ApiService.login('op@example.com', 'abc'))['success'], false);
    expect(ApiService.hasSession, false);
  });
  test('Mensaje 401 del servidor se conserva', () async {
    ApiService.client = MockClient(
      (request) async => jsonResponse(
        '{"success":false,"message":"Credenciales inválidas"}',
        401,
      ),
    );
    final result = await ApiService.login('op@example.com', 'wrong');
    expect(result['message'], 'Credenciales inválidas');
    expect(result['success'], false);
  });
  test('Respuesta HTML genera un diagnóstico claro', () async {
    ApiService.client = MockClient(
      (request) async => jsonResponse('<html>404</html>', 404),
    );
    expect(
      (await ApiService.login('op@example.com', 'abc'))['message'],
      contains('contenido inválido'),
    );
  });
  test('401 en una consulta elimina sesión y avisa a la navegación', () async {
    ApiService.client = MockClient(
      (request) async => request.url.path.endsWith('login')
          ? jsonResponse(jsonEncode(session()), 200)
          : jsonResponse('{"success":false,"message":"Sesión vencida"}', 401),
    );
    await ApiService.login('op@example.com', 'abc');
    expect(
      (await ApiService.getHistorialEntregadas(fecha: '2026-10-03'))['status'],
      401,
    );
    expect(ApiService.hasSession, false);
    expect(ApiService.sessionExpired.value, true);
  });
  test('Respuesta HTML 401 también revoca la sesión local', () async {
    ApiService.client = MockClient(
      (request) async => request.url.path.endsWith('login')
          ? jsonResponse(jsonEncode(session()), 200)
          : jsonResponse('<html>No autorizado</html>', 401),
    );
    await ApiService.login('op@example.com', 'abc');
    expect((await ApiService.getEncomiendasPorDni('12345678'))['status'], 401);
    expect(ApiService.hasSession, false);
    expect(ApiService.sessionExpired.value, true);
  });
  test('No envía token después de cambiar la empresa directamente', () async {
    int sent = 0;
    ApiService.client = MockClient((request) async {
      sent++;
      return jsonResponse(jsonEncode(session()), 200);
    });
    await ApiService.login('op@example.com', 'abc');
    await (await SharedPreferences.getInstance()).setString(
      'company_domain',
      'jrcargo.com.pe',
    );
    expect((await ApiService.getEncomiendasPorDni('12345678'))['status'], 401);
    expect(sent, 1);
  });
  test('Logout revoca el token y elimina la sesión local', () async {
    ApiService.client = MockClient((request) async {
      if (request.url.path.endsWith('logout')) {
        expect(request.headers['Authorization'], 'Bearer $token');
        return jsonResponse('{"success":true}', 200);
      }
      return jsonResponse(jsonEncode(session()), 200);
    });
    await ApiService.login('op@example.com', 'abc');
    await ApiService.logout();
    expect(ApiService.hasSession, false);
  });
  test('Solo consulta no sube fotos ni modifica encomiendas', () async {
    ApiService.client = MockClient(
      (_) async => throw StateError('No debe acceder a la red'),
    );
    expect(
      (await ApiService.registrarEntregaLote(
        trackings: ['ABC'],
        fotos: [],
      ))['success'],
      false,
    );
  });
}
