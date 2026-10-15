import 'package:apps_transporte/data/datasources/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Normaliza la URL y conserva la carpeta de la API', () {
    final config = ApiConfig.fromBaseUrl(
      '  https://api-tid.net.pe/APIAppDom_Sigtrans///  ',
    );
    expect(config.baseUrl, ApiConfig.defaultBaseUrl);
    expect(
      config.endpoint('login_usuario.php').toString(),
      '${ApiConfig.defaultBaseUrl}login_usuario.php',
    );
    expect(config.headers['X-Company-Domain'], 'tid.net.pe');
  });

  for (final invalid in [
    '',
    'api-tid.net.pe/APIAppDom_Sigtrans/',
    'http://api-tid.net.pe/APIAppDom_Sigtrans/',
    'https://api-tid.net.pe/APIAppDom Sigtrans/',
    r'https:\\api-tid.net.pe\APIAppDom_Sigtrans\',
    'https://user:secret@api-tid.net.pe/APIAppDom_Sigtrans/',
    '${ApiConfig.defaultBaseUrl}?company=tid.net.pe',
    '${ApiConfig.defaultBaseUrl}#login',
    '${ApiConfig.defaultBaseUrl}login_usuario.php',
  ]) {
    test('Rechaza una URL incompleta o inválida: $invalid', () {
      expect(() => ApiConfig.fromBaseUrl(invalid), throwsFormatException);
    });
  }
}
