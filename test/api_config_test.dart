import 'package:apps_transporte/data/datasources/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('La URL siempre es fija y usa el dominio TID ingresado', () {
    final config = ApiConfig.forCompanyDomain(' TID.NET.PE ');

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

  test('Acepta el dominio de La Rana Express escrito manualmente', () {
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
    'tid.net.pe/otra-ruta',
  ]) {
    test('Rechaza el dominio no autorizado: $invalidDomain', () {
      expect(
        () => ApiConfig.forCompanyDomain(invalidDomain),
        throwsFormatException,
      );
    });
  }
}
