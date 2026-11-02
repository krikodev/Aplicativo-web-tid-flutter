class ApiConfig {
  // El servidor de API es único para todas las empresas.
  static const String defaultBaseUrl =
      'https://api-tid.net.pe/APIAppDom_Sigtrans/';

  static const String defaultCompanyDomain = 'tid.net.pe';

  // Solo se permiten empresas que tienen credenciales configuradas en PHP.
  static const Map<String, String> companies = {
    'tid.net.pe': 'TID',
    'laranaexpress.com.pe': 'La Rana Express',
  };

  final Uri baseUri;
  final String companyDomain;

  ApiConfig._(this.baseUri, this.companyDomain);

  factory ApiConfig.forCompanyDomain(String value) {
    final domain = value.trim().toLowerCase();

    if (!companies.containsKey(domain)) {
      throw const FormatException(
        'Selecciona una empresa válida para conectarte.',
      );
    }

    return ApiConfig._(Uri.parse(defaultBaseUrl), domain);
  }

  String get baseUrl => defaultBaseUrl;

  Uri endpoint(String filename) => baseUri.resolve(filename);

  Map<String, String> get headers => {
        'Accept': 'application/json',
        'X-Company-Domain': companyDomain,
      };
}
