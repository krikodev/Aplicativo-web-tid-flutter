class ApiConfig {
  static const companyDomain = 'tid.net.pe';
  static const defaultBaseUrl = 'https://api-tid.net.pe/APIAppDom_Sigtrans/';

  final Uri baseUri;

  ApiConfig._(this.baseUri);

  factory ApiConfig.fromBaseUrl(String value) {
    final input = value.trim();
    if (input.isEmpty) {
      throw const FormatException('Configura la URL de la API de TID.');
    }
    if (RegExp(r'\s').hasMatch(input) || input.contains('\\')) {
      throw const FormatException(
        'La URL no debe contener espacios ni barras invertidas.',
      );
    }

    final uri = Uri.tryParse(input);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException(
        'Ingresa una URL HTTPS completa, por ejemplo '
        'https://api-tid.net.pe/APIAppDom_Sigtrans/.',
      );
    }
    if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
      throw const FormatException(
        'La URL de la API no debe incluir credenciales, parámetros ni #.',
      );
    }
    if (uri.path.toLowerCase().contains('.php')) {
      throw const FormatException(
        'Ingresa la carpeta de la API, sin login_usuario.php ni otro archivo.',
      );
    }

    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    return ApiConfig._(uri.replace(path: '$path/'));
  }

  String get baseUrl => baseUri.toString();

  Uri endpoint(String filename) => baseUri.resolve(filename);

  Map<String, String> get headers => {
    'Accept': 'application/json',
    'X-Company-Domain': companyDomain,
  };
}
