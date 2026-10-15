import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apps_transporte/data/datasources/api_config.dart';

class ApiService {
  static const String _cloudName = 'di5gmllfj';
  static const String _uploadPreset = 'transporta_evidencias';

  static const _requestTimeout = Duration(seconds: 20);

  static Map<String, dynamic> _failure(
    String message, {
    required String code,
    int? statusCode,
  }) => {
    'success': false,
    'message': message,
    'error': message,
    'error_code': code,
    if (statusCode != null) 'status_code': statusCode,
  };

  static String? _serverMessage(Map<String, dynamic> data) {
    for (final value in [data['message'], data['error']]) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static Map<String, dynamic> _decodeResponse(http.Response response, Uri url) {
    final status = response.statusCode;
    final successfulHttp = status >= 200 && status < 300;
    Map<String, dynamic>? data;
    try {
      final body = utf8.decode(response.bodyBytes).trim();
      if (body.isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) data = decoded;
      }
    } on FormatException {
      // Un hosting puede devolver HTML incluso cuando responde con HTTP 200.
    }

    if (!successfulHttp) {
      final message = data == null ? null : _serverMessage(data);
      return {
        if (data != null) ...data,
        ..._failure(
          message ??
              (status == 404
                  ? 'No se encontró ${url.pathSegments.last} en la URL '
                        'configurada (HTTP 404).'
                  : 'La API respondió con HTTP $status. Revisa el servidor.'),
          code: 'http_error',
          statusCode: status,
        ),
      };
    }

    if (data == null) {
      return _failure(
        response.bodyBytes.isEmpty
            ? 'La API devolvió una respuesta vacía.'
            : 'La API no devolvió un objeto JSON válido. Revisa la ruta '
                  'configurada y los errores de PHP en el servidor.',
        code: 'invalid_response',
        statusCode: status,
      );
    }
    if (data['success'] == false) {
      final message = _serverMessage(data) ?? 'La API rechazó la solicitud.';
      return {...data, 'message': message, 'error': message};
    }
    return data;
  }

  static bool _isDnsError(String message) {
    final text = message.toLowerCase();
    return text.contains('failed host lookup') ||
        text.contains('name or service not known') ||
        text.contains('no address associated with hostname') ||
        text.contains('temporary failure in name resolution');
  }

  static Map<String, dynamic> _connectionFailure(String message, Uri? url) {
    final host = url?.host ?? 'el servidor';
    if (_isDnsError(message)) {
      return _failure(
        'No se pudo resolver $host (DNS). Verifica el nombre del servidor '
        'y prueba la URL en el navegador del celular con Wi-Fi y datos móviles.',
        code: 'dns_error',
      );
    }
    return _failure(
      'No se pudo conectar con $host. Verifica tu conexión a Internet '
      'y que la API esté disponible.',
      code: 'connection_error',
    );
  }

  static Future<Map<String, dynamic>> _post(
    String endpoint, {
    required Map<String, String> body,
  }) => _sendPost(endpoint, body: body, jsonBody: false);

  static Future<Map<String, dynamic>> _postJson(
    String endpoint, {
    required Map<String, dynamic> body,
  }) => _sendPost(endpoint, body: body, jsonBody: true);

  static Future<Map<String, dynamic>> _sendPost(
    String endpoint, {
    required Map<String, dynamic> body,
    required bool jsonBody,
  }) async {
    Uri? url;
    http.Client? client;
    try {
      final prefs = await SharedPreferences.getInstance();
      final config = ApiConfig.fromBaseUrl(prefs.getString('base_url') ?? '');
      url = config.endpoint(endpoint);
      client = http.Client();
      final response = await client
          .post(
            url,
            headers: {
              ...config.headers,
              'Content-Type': jsonBody
                  ? 'application/json; charset=UTF-8'
                  : 'application/x-www-form-urlencoded',
            },
            body: jsonBody ? jsonEncode(body) : body,
          )
          .timeout(_requestTimeout);
      return _decodeResponse(response, url);
    } on FormatException catch (e) {
      return _failure(e.message, code: 'configuration_error');
    } on TimeoutException {
      final retryMessage = endpoint == 'api_procesar_entrega_cobro.php'
          ? ' Consulta el historial antes de repetir la entrega.'
          : '';
      return _failure(
        'La API no respondió en 20 segundos. Comprueba la conexión y '
        'el servidor.$retryMessage',
        code: 'timeout',
      );
    } on HandshakeException {
      return _failure(
        'No se pudo establecer HTTPS. Revisa el certificado SSL '
        'del servidor y la fecha del celular.',
        code: 'tls_error',
      );
    } on SocketException catch (e) {
      return _connectionFailure(e.message, url);
    } on http.ClientException catch (e) {
      return _connectionFailure(e.message, url);
    } catch (_) {
      return _failure(
        'No se pudo completar la solicitud a la API.',
        code: 'request_error',
      );
    } finally {
      client?.close();
    }
  }

  // --- LOGIN ---
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final decoded = await _post(
      'login_usuario.php',
      body: {'email': email.trim(), 'pass': password},
    );
    if (decoded['success'] != true) return decoded;

    final user = decoded['user'];
    if (user is! Map<String, dynamic> ||
        user['id_usuario'] == null ||
        user['id_usuario'].toString().trim().isEmpty) {
      return _failure(
        'El servidor no devolvió el ID del usuario.',
        code: 'invalid_user',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('id_usuario', user['id_usuario'].toString());
    if (user['id_terminal'] != null) {
      await prefs.setString('id_terminal', user['id_terminal'].toString());
    } else {
      await prefs.remove('id_terminal');
    }
    return decoded;
  }

  // --- OBTENER ENCOMIENDAS POR DNI ---
  static Future<Map<String, dynamic>> getEncomiendasPorDni(String dni) async {
    return _postJson('get_encomiendas_dni.php', body: {'dni': dni.trim()});
  }

  // --- SUBIR FOTO A CLOUDINARY ---
  static Future<String?> _subirFotoCloudinary(XFile foto) async {
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );
    try {
      var request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', foto.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        return jsonDecode(responseData)['secure_url'];
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  // NUEVO: firma y descuento se envían por separado.
  static Future<Map<String, dynamic>> registrarEntregaLote({
    required List<String> trackings,
    required List<XFile> fotos,
    required XFile? firma,
    required double montoCobrado,
    required double descuento,
    required int? idMedioPago,
  }) async {
    if (trackings.length != 1 || trackings.single.trim().isEmpty) {
      return {
        'success': false,
        'error': 'Procesa una sola encomienda por operación.',
      };
    }

    if (fotos.length != 2 || firma == null) {
      return {
        'success': false,
        'error': 'Se requieren dos fotografías y la firma del receptor.',
      };
    }

    if (!montoCobrado.isFinite ||
        !descuento.isFinite ||
        montoCobrado < 0 ||
        descuento < 0) {
      return {
        'success': false,
        'error': 'El monto y el descuento no pueden ser negativos.',
      };
    }
    // NUEVO: validar el medio de pago cuando hay un cobro.
    if (montoCobrado > 0 && ![1, 2, 3].contains(idMedioPago)) {
      return {'success': false, 'error': 'Selecciona EFECTIVO, YAPE o PLIN.'};
    }

    if (montoCobrado == 0 && idMedioPago != null) {
      return {
        'success': false,
        'error': 'No debes seleccionar un medio de pago si no hay cobro.',
      };
    }

    final prefs = await SharedPreferences.getInstance();
    try {
      ApiConfig.fromBaseUrl(prefs.getString('base_url') ?? '');
    } on FormatException catch (e) {
      return _failure(e.message, code: 'configuration_error');
    }

    // MODIFICADO: no usar un usuario predeterminado.
    final idUsuario = prefs.get('id_usuario')?.toString();

    if (idUsuario == null || (int.tryParse(idUsuario) ?? 0) <= 0) {
      return {
        'success': false,
        'error':
            'No se encontró el usuario autenticado. Inicia sesión nuevamente.',
      };
    }

    // NUEVO: subir las fotos por separado.
    final List<String> urlsFotos = [];

    for (final foto in fotos) {
      final urlFoto = await _subirFotoCloudinary(foto);

      if (urlFoto == null) {
        return {
          'success': false,
          'error': 'No se pudo subir una de las fotos de evidencia.',
        };
      }

      urlsFotos.add(urlFoto);
    }

    // La firma se conserva separada de las dos fotografías.
    final urlFirma = await _subirFotoCloudinary(firma);

    if (urlFirma == null) {
      return {
        'success': false,
        'error': 'No se pudo subir la firma del receptor.',
      };
    }

    return _post(
      'api_procesar_entrega_cobro.php',
      body: {
        'trackings': jsonEncode([trackings.single.trim()]),
        'urls_fotos': jsonEncode(urlsFotos),
        'url_firma': urlFirma,
        'monto_cobrado': montoCobrado.toStringAsFixed(2),
        'descuento': descuento.toStringAsFixed(2),
        'id_usuario': idUsuario,
        'id_medio_pago': idMedioPago?.toString() ?? '',
      },
    );
  }

  // --- OBTENER HISTORIAL DE ENTREGADAS ---
  static Future<Map<String, dynamic>> getHistorialEntregadas({
    String filtro = '',
    required String fecha,
  }) async {
    return _postJson(
      'get_historial.php',
      body: {'filtro': filtro.trim(), 'fecha': fecha},
    );
  }

  // --- OBTENER DEUDA ---
  static Future<Map<String, dynamic>> obtenerDeuda(
    List<String> trackings,
  ) async {
    if (trackings.length != 1 || trackings.single.trim().isEmpty) {
      return _failure(
        'Procesa una sola encomienda por operación.',
        code: 'invalid_trackings',
      );
    }
    final codigo = trackings.single.trim();
    final result = await _postJson(
      'api_obtener_deuda.php',
      body: {
        'trackings': [codigo],
      },
    );
    if (result['success'] != true) return result;

    // Una respuesta incompleta nunca debe interpretarse como entrega sin cobro.
    final total = double.tryParse(result['deuda_total']?.toString() ?? '');
    final requiresPayment = result['requiere_cobro'];
    final payment = result['estado_pago'];
    final details = result['detalles'];
    final valid =
        total != null &&
        total.isFinite &&
        total >= 0 &&
        requiresPayment is bool &&
        result['estado_encomienda'] == 'EN DESTINO' &&
        details is List &&
        (requiresPayment
            ? payment == 'PAGO EN DESTINO' && total > 0 && details.length == 1
            : ['PAGADO', 'PAGO EN BLOQUE', 'CREDITO'].contains(payment) &&
                  total == 0 &&
                  details.isEmpty);
    if (!valid) return _invalidDebt();

    final normalizedDetails = <Map<String, dynamic>>[];
    for (final detail in details) {
      if (detail is! Map<String, dynamic>) return _invalidDebt();
      final amount = double.tryParse(detail['total_bruto']?.toString() ?? '');
      if (detail['codigo'] != codigo ||
          (int.tryParse(detail['id_venta']?.toString() ?? '') ?? 0) <= 0 ||
          amount == null ||
          !amount.isFinite ||
          amount != total ||
          detail['estado_venta'] != 'PENDIENTE') {
        return _invalidDebt();
      }
      normalizedDetails.add({...detail, 'total_bruto': amount});
    }
    return {...result, 'deuda_total': total, 'detalles': normalizedDetails};
  }

  static Map<String, dynamic> _invalidDebt() => _failure(
    'La API devolvió una deuda incompleta o inconsistente. Actualiza los PHP del servidor.',
    code: 'invalid_debt_response',
  );
}
