import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const timeout = Duration(seconds: 15);
  static final sessionExpired = ValueNotifier<bool>(false);
  // Inyección del transporte para pruebas sin depender de un servidor real.
  static http.Client client = http.Client();
  static String? _token;
  static String? _sessionCompany;
  static String? _sessionBaseUrl;
  static DateTime? _expiresAt;
  static Map<String, dynamic>? currentUser;

  static String normalizeBaseUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'URL inválida. Usa http://IP:8080/ o https://dominio/ruta/',
      );
    }
    if (kReleaseMode && uri.scheme != 'https') {
      throw const FormatException(
        'La versión final requiere una URL HTTPS. Para pruebas locales usa flutter run.',
      );
    }
    final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    return uri.replace(path: path).toString();
  }

  static String normalizeCompanyDomain(String value) {
    final domain = value.trim().toLowerCase();
    final pattern = RegExp(
      r'^(?=.{1,253}$)[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+$',
    );
    if (!pattern.hasMatch(domain)) {
      throw const FormatException(
        'Ingresa solo el dominio de la empresa, sin https ni rutas.',
      );
    }
    return domain;
  }

  static Future<bool> hasConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      normalizeBaseUrl(prefs.getString('base_url') ?? '');
      normalizeCompanyDomain(prefs.getString('company_domain') ?? '');
      return true;
    } on FormatException {
      return false;
    }
  }

  static Future<Map<String, dynamic>> configure(
    String baseUrl,
    String domain,
  ) async {
    try {
      final normalizedUrl = normalizeBaseUrl(baseUrl);
      final normalizedDomain = normalizeCompanyDomain(domain);
      final result = await _request(
        'GET',
        'v1/health',
        baseUrl: normalizedUrl,
        domain: normalizedDomain,
        authenticated: false,
      );
      if (result['success'] != true) return result;
      final company = result['company'];
      if (result['api_version'] != 'v1' ||
          result['read_only'] != true ||
          company is! Map ||
          company['domain'] != normalizedDomain) {
        return _error(
          'El servidor no corresponde a la API v1 de esta empresa.',
        );
      }
      // No mandar credenciales anteriores al servidor recién elegido.
      await clearSession();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('base_url', normalizedUrl);
      await prefs.setString('company_domain', normalizedDomain);
      return result;
    } on FormatException catch (e) {
      return _error(e.message);
    }
  }

  static bool get hasSession =>
      _token != null &&
      _expiresAt != null &&
      _expiresAt!.isAfter(DateTime.now().toUtc());

  static Future<void> clearSession({bool expired = false}) async {
    _token = null;
    _sessionCompany = null;
    _sessionBaseUrl = null;
    _expiresAt = null;
    currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    // Retira también el booleano antiguo que permitía entrar sin sesión real.
    await prefs.remove('is_logged_in');
    sessionExpired.value = expired;
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    await clearSession();
    final settings = await SharedPreferences.getInstance();
    final originalBase = settings.getString('base_url') ?? '';
    final originalCompany = settings.getString('company_domain') ?? '';
    final result = await _request(
      'POST',
      'v1/auth/login',
      baseUrl: originalBase,
      domain: originalCompany,
      body: {'email': email.trim(), 'password': password},
      authenticated: false,
    );
    if (result['success'] == true) {
      final token = result['access_token'];
      final expires = DateTime.tryParse(result['expires_at']?.toString() ?? '');
      final user = result['user'];
      if (token is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(token) ||
          expires == null ||
          !expires.isAfter(DateTime.now().toUtc()) ||
          user is! Map<String, dynamic>) {
        return _error('El servidor no devolvió una sesión válida.');
      }
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('base_url') != originalBase ||
          prefs.getString('company_domain') != originalCompany) {
        return _error(
          'El servidor cambió durante el login. Intenta nuevamente.',
        );
      }
      _token = token;
      _expiresAt = expires.toUtc();
      _sessionCompany = normalizeCompanyDomain(
        prefs.getString('company_domain') ?? '',
      );
      _sessionBaseUrl = normalizeBaseUrl(prefs.getString('base_url') ?? '');
      currentUser = user;
      sessionExpired.value = false;
    }
    return result;
  }

  static Future<void> logout() async {
    if (hasSession) {
      await _request('POST', 'v1/auth/logout', body: {});
    }
    await clearSession();
  }

  static Future<Map<String, dynamic>> getEncomiendasPorDni(String dni) =>
      _request('GET', 'v1/encomiendas/dni', query: {'dni': dni.trim()});

  static Future<Map<String, dynamic>> getHistorialEntregadas({
    String filtro = '',
    required String fecha,
  }) => _request(
    'GET',
    'v1/encomiendas/historial',
    query: {'filtro': filtro.trim(), 'fecha': fecha},
  );

  static Future<Map<String, dynamic>> getResumen() =>
      _request('GET', 'v1/resumen');

  static Future<Map<String, dynamic>> getTracking(String codigo) => _request(
    'GET',
    'v1/encomiendas/tracking',
    query: {'codigo_tracking': codigo.trim()},
  );

  static Future<Map<String, dynamic>> getComprobante({
    required String serie,
    required String correlativo,
    required String fecha,
  }) => _request(
    'GET',
    'v1/encomiendas/comprobante',
    query: {
      'serie': serie.trim(),
      'correlativo': correlativo.trim(),
      'fecha': fecha,
    },
  );

  static Future<Map<String, dynamic>> getImagenes(String codigo) => _request(
    'GET',
    'v1/encomiendas/imagenes',
    query: {'codigo_tracking': codigo.trim()},
  );

  static Future<Map<String, dynamic>> registrarEntregaLote({
    required List<String> trackings,
    required List<XFile> fotos,
  }) async => _error(
    'Esta conexión es de solo consulta. Registra la entrega en el sistema general.',
  );

  static Map<String, dynamic> _error(String message) => {
    'success': false,
    'message': message,
    'error': message,
  };

  static Future<Map<String, dynamic>> _request(
    String method,
    String endpoint, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    String? baseUrl,
    String? domain,
    bool authenticated = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final base = normalizeBaseUrl(
        baseUrl ?? prefs.getString('base_url') ?? '',
      );
      final company = normalizeCompanyDomain(
        domain ?? prefs.getString('company_domain') ?? '',
      );
      if (authenticated &&
          (!hasSession ||
              _sessionCompany != company ||
              _sessionBaseUrl != base)) {
        await clearSession(expired: true);
        return _error('Inicia sesión nuevamente.')..['status'] = 401;
      }
      final uri = Uri.parse(
        base,
      ).resolve(endpoint).replace(queryParameters: query);
      final headers = <String, String>{
        'Accept': 'application/json',
        'X-Company-Domain': company,
        if (body != null) 'Content-Type': 'application/json',
        if (authenticated) 'Authorization': 'Bearer $_token',
      };
      // Rechaza redirecciones para no enviar tokens a otro servidor.
      final request = http.Request(method, uri)
        ..headers.addAll(headers)
        ..followRedirects = false;
      if (body != null) request.body = jsonEncode(body);
      final response = await (() async {
        final streamed = await client.send(request);
        return http.Response.fromStream(streamed);
      })().timeout(timeout);
      if (authenticated && response.statusCode == 401) {
        await clearSession(expired: true);
      }
      Map<String, dynamic> result;
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! Map<String, dynamic>) throw const FormatException();
        result = decoded;
      } on FormatException {
        return _error(
          'El servidor respondió con contenido inválido (HTTP ${response.statusCode}). Revisa la URL y la configuración PHP.',
        )..['status'] = response.statusCode;
      }
      result['status'] = response.statusCode;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        result['success'] = false;
        result['message'] ??=
            'Error del servidor (HTTP ${response.statusCode}).';
        result['error'] ??= result['message'];
      }
      return result;
    } on TimeoutException {
      return _error(
        'El servidor tardó demasiado. Verifica que PHP esté iniciado y que ambos dispositivos estén en la misma red.',
      );
    } on FormatException catch (e) {
      return _error(
        e.message.isEmpty ? 'Configura el servidor y la empresa.' : e.message,
      );
    } catch (_) {
      return _error(
        'No se pudo conectar al servidor. Revisa IP, puerto, Wi-Fi y firewall.',
      );
    }
  }
}
