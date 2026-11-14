/// Cálculos de cobro mostrados en el móvil.
/// La API vuelve a calcular el descuento con el total de la venta en BD.
class CalculoCobro {
  const CalculoCobro._();

  /// Acepta soles con máximo dos decimales, punto o coma.
  /// Devuelve null si está vacío, es inválido, es cero o excede la deuda.
  static double? montoValido(String texto, double total) {
    final valor = texto.trim().replaceAll(',', '.');
    if (!RegExp(r'^[0-9]+(?:\.[0-9]{1,2})?$').hasMatch(valor)) {
      return null;
    }

    if (!total.isFinite || total <= 0) return null;
    final cobrado = double.tryParse(valor);
    if (cobrado == null || !cobrado.isFinite) return null;

    final totalCentimos = (total * 100).round();
    final cobradoCentimos = (cobrado * 100).round();
    if (cobradoCentimos <= 0 || cobradoCentimos > totalCentimos) {
      return null;
    }

    return cobradoCentimos / 100;
  }

  /// Ejemplo: total 100.00 - cobrado 70.00 = descuento 30.00.
  static double descuento(double total, double cobrado) {
    return ((total * 100).round() - (cobrado * 100).round()) / 100;
  }
}
