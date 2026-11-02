import 'package:apps_transporte/data/datasources/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Usa siempre la URL fija de la API y envía el dominio TID', () {
    final config = ApiConfig.forCompanyDomain('tid.net.pe');

    expect(
      config.baseUrl,
      'https://api-tid.net.pe/APIAppDom_Sigtrans/',
    );
    expect(
      config.endpoint('login_usuario.php').toString(),
      'https://api-tid.net.pe/APIAppDom_Sigtrans/login_usuario.php',
    );
    expect(config.headers['X-Company-Domain'], 'tid.net.pe');
  });

  test('Permite seleccionar La Rana Express sin cambiar la URL de API', () {
    final config = ApiConfig.forCompanyDomain('laranaexpress.com.pe');

    expect(
      config.baseUrl,
      'https://api-tid.net.pe/APIAppDom_Sigtrans/',
    );
    expect(config.headers['X-Company-Domain'], 'laranaexpress.com.pe');
  });

  for (final invalidDomain in [
    '',
    'www.laranaexpress.com.pe',
    'https://laranaexpress.com.pe',
    'empresa-no-registrada.com',
  ]) {
    test('Rechaza el dominio no autorizado: $invalidDomain', () {
      expect(
        () => ApiConfig.forCompanyDomain(invalidDomain),
        throwsFormatException,
      );
    });
  }
}
