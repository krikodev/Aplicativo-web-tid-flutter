class ApiConfig {
  // El servidor de API es único para todas las empresas.
  static const String defaultBaseUrl =
      'https://api-tid.net.pe/APIAppDom_Sigtrans/';

  // Dominios autorizados en el servidor PHP.
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
        'El dominio ingresado no está autorizado para esta aplicación.',
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
