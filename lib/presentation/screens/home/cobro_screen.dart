import 'package:flutter/material.dart';
import 'package:apps_transporte/core/utils/app_colors.dart';
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
  String? _error;
  double _deudaTotal = 0.0;
  double _descuento = 0.0;
  bool _requiereCobro = false;
  int? _idMedioPago;
  List<dynamic> _detalles = [];
  final TextEditingController _descuentoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDeuda();
  }

  Future<void> _cargarDeuda() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await ApiService.obtenerDeuda(widget.trackings);

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        // MODIFICADO: leer los datos del nuevo formato PHP.
        _deudaTotal = (result['deuda_total'] as num).toDouble();

        _requiereCobro = result['requiere_cobro'] == true;

        _detalles = result['detalles'] is List
            ? result['detalles'] as List
            : [];

        _isLoading = false;
      });

      // MODIFICADO: si no requiere cobro, pasar directamente a evidencias.
      if (!_requiereCobro) {
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
        _error =
            result['error'] ?? result['message'] ?? 'Error al obtener deuda';
      });
    }
  }

  // MODIFICADO: validar descuento y medio de pago.
  void _irATomarFotos() {
    if (_descuento < 0) {
      _mostrarError('El descuento no puede ser negativo.');
      return;
    }

    if (_descuento > 0 && _descuento >= _deudaTotal) {
      _mostrarError('El descuento debe ser menor al total de la encomienda.');
      return;
    }

    // NUEVO: exigir medio de pago cuando hay un cobro.
    if (_idMedioPago == null) {
      _mostrarError('Selecciona el medio de pago utilizado.');
      return;
    }

    final totalACobrar = double.parse(
      (_deudaTotal - _descuento).toStringAsFixed(2),
    );

    if (totalACobrar <= 0) {
      _mostrarError('El importe a cobrar debe ser mayor que cero.');
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EvidenciaScreen(
          trackings: widget.trackings,
          montoCobrado: totalACobrar,
          requiereFirma: true,

          // NUEVO: pasar los datos para completar el registro.
          descuento: _descuento,
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
    _descuentoCtrl.dispose();
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
              ? AppColors.accent.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado
                ? AppColors.accent
                : Colors.grey.withValues(alpha: 0.3),
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
    double totalACobrar = _deudaTotal - _descuento;
    if (totalACobrar < 0) totalACobrar = 0;

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
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _cargarDeuda,
                      child: const Text('Volver a consultar deuda'),
                    ),
                  ],
                ),
              ),
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
                              color: Colors.grey.withValues(alpha: 0.2),
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
                                    "Deuda Total:",
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
                                "Aplicar Descuento (S/):",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _descuentoCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                    Icons.money_off,
                                    color: AppColors.accent,
                                  ),
                                  hintText: "0.00",
                                  filled: true,
                                  fillColor: AppColors.softBackground,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _descuento = double.tryParse(value) ?? 0.0;
                                  });
                                },
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
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: CustomButton(
                      text:
                          'Cobrar S/ ${totalACobrar.toStringAsFixed(2)} y Tomar Fotos',
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
