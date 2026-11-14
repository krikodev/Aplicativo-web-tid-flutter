import 'package:flutter/material.dart';
import 'package:apps_transporte/core/utils/app_colors.dart';
import 'package:apps_transporte/core/utils/calculo_cobro.dart';
import 'package:apps_transporte/core/widgets/custom_button.dart';
import 'package:apps_transporte/data/datasources/api_service.dart';
import 'evidencia_screen.dart';

class CobroScreen extends StatefulWidget {
  final List<String> trackings;
  const CobroScreen({super.key, required this.trackings});

  @override
  State<CobroScreen> createState() => _CobroScreenState();
}

class _CobroScreenState extends State<CobroScreen> {
  bool _isLoading = true;
  double _deudaTotal = 0.0;
  bool _requiereCobro = false;
  int? _idMedioPago;
  List<dynamic> _detalles = [];
  final TextEditingController _montoCobradoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDeuda();
  }

  Future<void> _cargarDeuda() async {
    final result = await ApiService.obtenerDeuda(widget.trackings);

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        // MODIFICADO: leer los datos del nuevo formato PHP.
        _deudaTotal = ((result['deuda_total'] ?? 0) as num).toDouble();
        _montoCobradoCtrl.text = _deudaTotal.toStringAsFixed(2);

        _requiereCobro = result['requiere_cobro'] == true;

        _detalles = result['detalles'] is List
            ? result['detalles'] as List
            : [];

        _isLoading = false;
      });

      // MODIFICADO: si no requiere cobro, pasar directamente a evidencias.
      if (!_requiereCobro || _deudaTotal <= 0) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EvidenciaScreen(
              trackings: widget.trackings,
              montoCobrado: 0.0,
              requiereFirma: true,
            ),
          ),
        );
      }
    } else {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Error al obtener deuda'),
          backgroundColor: AppColors.error,
        ),
      );

      Navigator.pop(context);
    }
  }

  // El operario introduce cuánto cobró. El descuento no se edita.
  void _irATomarFotos() {
    final montoCobrado = CalculoCobro.montoValido(
      _montoCobradoCtrl.text,
      _deudaTotal,
    );
    if (montoCobrado == null) {
      _mostrarError('Ingresa un monto mayor a cero, no superior al total y con máximo 2 decimales.');
      return;
    }

    if (_idMedioPago == null) {
      _mostrarError('Selecciona el medio de pago utilizado.');
      return;
    }

    final descuento = CalculoCobro.descuento(_deudaTotal, montoCobrado);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EvidenciaScreen(
          trackings: widget.trackings,
          montoCobrado: montoCobrado,
          requiereFirma: true,
          descuento: descuento,
          idMedioPago: _idMedioPago!,
        ),
      ),
    );
  }

  // NUEVO: mostrar errores de validación.
  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: AppColors.error),
    );
  }

  // NUEVO: liberar el controlador.
  @override
  void dispose() {
    _montoCobradoCtrl.dispose();
    super.dispose();
  }

  // NUEVO: componente reutilizable para seleccionar medio de pago.
  Widget _buildMedioPago({
    required int id,
    required String nombre,
    required IconData icono,
  }) {
    final bool seleccionado = _idMedioPago == id;

    return InkWell(
      onTap: () {
        setState(() {
          _idMedioPago = id;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: seleccionado
              ? AppColors.accent.withOpacity(0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado
                ? AppColors.accent
                : Colors.grey.withOpacity(0.3),
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icono, color: AppColors.accent, size: 26),
            const SizedBox(height: 8),
            Text(
              nombre,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: seleccionado ? AppColors.accent : AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Icon(
              seleccionado ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: seleccionado ? AppColors.accent : AppColors.textGrey,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final montoCobrado = CalculoCobro.montoValido(
      _montoCobradoCtrl.text,
      _deudaTotal,
    );
    final descuento = montoCobrado == null
        ? null
        : CalculoCobro.descuento(_deudaTotal, montoCobrado);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Detalle de Cobro",
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const Text(
                          "Nota de Venta / Paquetes",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textGrey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._detalles.map((item) {
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              title: Text(
                                'Encomienda ${item['codigo'] ?? widget.trackings.first}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Venta: ${item['id_venta'] ?? '-'}\n'
                                'Estado: ${item['estado_venta'] ?? '-'}',
                              ),
                              trailing: Text(
                                'S/ ${((item['total_bruto'] ?? 0) as num).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Total a cobrar:",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                                  Text(
                                    "S/ ${_deudaTotal.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 30),
                              const Text(
                                "¿Cuánto cobra realmente? (S/):",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _montoCobradoCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                    Icons.payments_outlined,
                                    color: AppColors.accent,
                                  ),
                                  hintText: "Ejemplo: 70.00",
                                  filled: true,
                                  fillColor: AppColors.softBackground,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Descuento automático:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                                  Text(
                                    descuento == null
                                        ? '—'
                                        : 'S/ ${descuento.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ],
                              ),
                              if (montoCobrado == null)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    'El importe debe ser mayor que cero y no superar el total.',
                                    style: TextStyle(
                                      color: AppColors.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              // NUEVO: selector del medio de pago.
                              const SizedBox(height: 20),
                              const Text(
                                'Medio de pago:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // NUEVO: opciones EFECTIVO, YAPE y PLIN.
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMedioPago(
                                      id: 1,
                                      nombre: 'EFECTIVO',
                                      icono: Icons.payments_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildMedioPago(
                                      id: 2,
                                      nombre: 'YAPE',
                                      icono: Icons.smartphone,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildMedioPago(
                                      id: 3,
                                      nombre: 'PLIN',
                                      icono: Icons.phone_android,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: CustomButton(
                      text:
                          montoCobrado == null
                              ? 'Ingresa el importe cobrado'
                              : 'Cobrar S/ ${montoCobrado.toStringAsFixed(2)} y Tomar Foto',
                      backgroundColor: AppColors.accent,
                      onPressed: _irATomarFotos,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
