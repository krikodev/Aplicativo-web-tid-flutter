import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _cloudName = 'di5gmllfj';
  static const String _uploadPreset = 'transporta_evidencias';

  static Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    String baseUrl = prefs.getString('base_url') ?? "";
    if (baseUrl.isNotEmpty && !baseUrl.endsWith('/')) {
      baseUrl += '/';
    }
    return baseUrl;
  }

  static Future<String> _getCompanyDomain() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('company_domain') ?? "";
  }

  // --- LOGIN ---
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final baseUrl = await _getBaseUrl();

    if (baseUrl.isEmpty) {
      return {'success': false, 'message': 'Servidor no configurado en la app'};
    }

    final url = Uri.parse("${baseUrl}login_usuario.php");
    final domain = await _getCompanyDomain();

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-Company-Domain': domain,
        },
        body: {'email': email.trim(), 'pass': password},
      );

      if (response.body.trim().isEmpty) {
        return {'success': false, 'message': 'Respuesta vacía del servidor'};
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return {
          'success': false,
          'message': 'Respuesta inesperada del servidor',
        };
      }

      // NUEVO: guardar el ID cuando el login sea correcto.
      if (decoded['success'] == true) {
        final user = decoded['user'];

        if (user is! Map<String, dynamic> ||
            user['id_usuario'] == null ||
            user['id_usuario'].toString().trim().isEmpty) {
          return {
            'success': false,
            'message': 'El servidor no devolvió el ID del usuario',
          };
        }

        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('id_usuario', user['id_usuario'].toString());

        // NUEVO: guardar otros datos útiles de la sesión.
        if (user['id_terminal'] != null) {
          await prefs.setString('id_terminal', user['id_terminal'].toString());
        }
      }

      return decoded;
    } on FormatException {
      return {
        'success': false,
        'message': 'El servidor devolvió una respuesta no válida',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // --- OBTENER ENCOMIENDAS POR DNI ---
  static Future<Map<String, dynamic>> getEncomiendasPorDni(String dni) async {
    final baseUrl = await _getBaseUrl();
    if (baseUrl.isEmpty) {
      return {'success': false, 'message': 'Servidor no configurado'};
    }

    final url = Uri.parse("${baseUrl}get_encomiendas_dni.php");
    final domain = await _getCompanyDomain();

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          'X-Company-Domain': domain,
        },
        body: jsonEncode({"dni": dni.trim()}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          "success": false,
          "message": "Error ${response.statusCode} en el servidor",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Error de conexión: $e"};
    }
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
    } catch (e) {
      print("Error subiendo a Cloudinary: $e");
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
    if (trackings.isEmpty) {
      return {
        'success': false,
        'error': 'No se recibieron códigos de seguimiento.',
      };
    }

    if (fotos.isEmpty) {
      return {'success': false, 'error': 'Debes tomar al menos una foto.'};
    }

    if (montoCobrado < 0 || descuento < 0) {
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

    final baseUrl = await _getBaseUrl();

    if (baseUrl.isEmpty) {
      return {'success': false, 'error': 'Servidor no configurado.'};
    }

    final prefs = await SharedPreferences.getInstance();
    final domain = await _getCompanyDomain();

    // MODIFICADO: no usar un usuario predeterminado.
    final idUsuario =
        prefs.getString('id_usuario') ?? prefs.getInt('id_usuario')?.toString();

    if (idUsuario == null || idUsuario.trim().isEmpty) {
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

    // NUEVO: subir la firma por separado, si se proporcionó.
    String? urlFirma;

    if (firma != null) {
      urlFirma = await _subirFotoCloudinary(firma);

      if (urlFirma == null) {
        return {
          'success': false,
          'error': 'No se pudo subir la firma del receptor.',
        };
      }
    }

    final url = Uri.parse('${baseUrl}api_procesar_entrega_cobro.php');

    try {
      final response = await http.post(
        url,
        headers: {'X-Company-Domain': domain},
        body: {
          'trackings': jsonEncode(trackings),
          'urls_fotos': jsonEncode(urlsFotos),
          'url_firma': urlFirma ?? '',
          'monto_cobrado': montoCobrado.toStringAsFixed(2),
          'descuento': descuento.toStringAsFixed(2),
          'id_usuario': idUsuario,
          'id_medio_pago': idMedioPago?.toString() ?? '',
        },
      );

      // NUEVO: comprobar que la respuesta sea JSON válido.
      if (response.body.trim().isEmpty) {
        return {
          'success': false,
          'error': 'El servidor devolvió una respuesta vacía.',
        };
      }

      // MODIFICADO: validar respuesta JSON y estado HTTP.
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return decoded;
        }

        return {
          ...decoded,
          'success': false,
          'error':
              decoded['error'] ??
              decoded['message'] ??
              'Error HTTP ${response.statusCode}.',
        };
      }
      return {
        'success': false,
        'error': 'La respuesta del servidor tiene un formato inesperado.',
      };
    } on FormatException {
      return {
        'success': false,
        'error': 'El servidor devolvió una respuesta no válida.',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  // --- OBTENER HISTORIAL DE ENTREGADAS ---
  static Future<Map<String, dynamic>> getHistorialEntregadas({
    String filtro = '',
    required String fecha,
  }) async {
    final baseUrl = await _getBaseUrl();
    if (baseUrl.isEmpty) {
      return {'success': false, 'message': 'Servidor no configurado'};
    }

    final url = Uri.parse("${baseUrl}get_historial.php");
    final domain = await _getCompanyDomain();

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          'X-Company-Domain': domain,
        },
        body: jsonEncode({"filtro": filtro.trim(), "fecha": fecha}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          "success": false,
          "message": "Error ${response.statusCode} en el servidor",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Error de conexión: $e"};
    }
  }

  // --- OBTENER DEUDA ---
  static Future<Map<String, dynamic>> obtenerDeuda(
    List<String> trackings,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString('base_url') ?? '';
      final domain = prefs.getString('company_domain') ?? '';

      final urlStr = baseUrl.endsWith('/')
          ? '${baseUrl}api_obtener_deuda.php'
          : '$baseUrl/api_obtener_deuda.php';

      final response = await http.post(
        Uri.parse(urlStr),
        headers: {
          'Content-Type': 'application/json',
          'X-Company-Domain': domain,
        },
        body: jsonEncode({'trackings': trackings}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {
        'success': false,
        'error': 'Error en el servidor al consultar la deuda',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }
}
