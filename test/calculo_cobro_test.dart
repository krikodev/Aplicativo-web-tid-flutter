import 'package:apps_transporte/core/utils/calculo_cobro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('100 a cobrar y 70 recibido = 30 de descuento', () {
    final recibido = CalculoCobro.montoValido('70.00', 100.00);
    expect(recibido, 70);
    expect(CalculoCobro.descuento(100, recibido!), 30);
  });

  test('Cobro completo no tiene descuento', () {
    final recibido = CalculoCobro.montoValido('100', 100);
    expect(recibido, 100);
    expect(CalculoCobro.descuento(100, recibido!), 0);
  });

  test('Admite coma decimal y conserva centavos exactos', () {
    final recibido = CalculoCobro.montoValido('70,02', 100.05);
    expect(recibido, 70.02);
    expect(CalculoCobro.descuento(100.05, recibido!), 30.03);
  });

  test('Rechaza cero, negativos, exceso y más de dos decimales', () {
    for (final texto in ['0', '-1', '100.01', '70.001', 'abc', '']) {
      expect(
        CalculoCobro.montoValido(texto, 100),
        isNull,
        reason: 'No debe aceptarse: $texto',
      );
    }
  });

  test('No calcula con deudas nulas o inválidas', () {
    expect(CalculoCobro.montoValido('10', 0), isNull);
    expect(CalculoCobro.montoValido('10', double.infinity), isNull);
  });

  test('Un descuento de pocos centavos respeta el redondeo', () {
    final recibido = CalculoCobro.montoValido('0.01', 0.03);
    expect(recibido, 0.01);
    expect(CalculoCobro.descuento(0.03, recibido!), 0.02);
  });
}
