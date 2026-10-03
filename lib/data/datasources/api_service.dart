import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _cloudName = 'di5gmllfj';
  static const String _uploadPreset = 'transporta_evidencias';

  // 👇 1. NUEVA FUNCIÓN: Lee la IP o URL que escribiste en la pantalla de configuración
  static Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    String baseUrl = prefs.getString('base_url') ?? "";
    if (baseUrl.isNotEmpty && !baseUrl.endsWith('/')) {
      baseUrl += '/';
    }
    return baseUrl;
  }

  // 2. EXTRAER EL DOMINIO DE LA MEMORIA
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
    if (baseUrl.isEmpty)
      return {'success': false, 'message': 'Servidor no configurado en la app'};

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

      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // --- OBTENER ENCOMIENDAS POR DNI ---
  static Future<Map<String, dynamic>> getEncomiendasPorDni(String dni) async {
    final baseUrl = await _getBaseUrl();
    if (baseUrl.isEmpty)
      return {'success': false, 'message': 'Servidor no configurado'};

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

  // --- REGISTRAR ENTREGA LOTE ---
  static Future<Map<String, dynamic>> registrarEntregaLote({
    required List<String> trackings,
    required List<XFile> fotos,
  }) async {
    List<String> urlsFotos = [];

    if (fotos.isEmpty) {
      return {"success": false, "error": "Debes tomar al menos una foto."};
    }

    for (var foto in fotos) {
      String? url = await _subirFotoCloudinary(foto);
      if (url != null) {
        urlsFotos.add(url);
      } else {
        return {"success": false, "error": "Error al subir una de las fotos."};
      }
    }

    final baseUrl = await _getBaseUrl();
    if (baseUrl.isEmpty)
      return {'success': false, 'error': 'Servidor no configurado'};

    final url = Uri.parse("${baseUrl}entregar_encomiendas.php");
    final domain = await _getCompanyDomain();

    try {
      final response = await http.post(
        url,
        headers: {'X-Company-Domain': domain},
        body: {
          'trackings': jsonEncode(trackings),
          'urls_fotos': jsonEncode(urlsFotos),
        },
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión local: $e'};
    }
  }

  // --- OBTENER HISTORIAL DE ENTREGADAS ---
  static Future<Map<String, dynamic>> getHistorialEntregadas({
    String filtro = '',
    required String fecha,
  }) async {
    final baseUrl = await _getBaseUrl();
    if (baseUrl.isEmpty)
      return {'success': false, 'message': 'Servidor no configurado'};

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
}
