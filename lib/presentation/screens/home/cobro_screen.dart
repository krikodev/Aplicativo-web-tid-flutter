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
  double _deudaTotal = 0.0;
  double _descuento = 0.0;
  List<dynamic> _detalles = [];
  final TextEditingController _descuentoCtrl = TextEditingController();

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
        _deudaTotal = (result['deuda_total'] as num).toDouble();
        _detalles = result['detalles'];
        _isLoading = false;
      });

      // SI LA DEUDA ES 0 (YA ESTÁ PAGADO), SALTAMOS A EVIDENCIAS Y EXIGIMOS FIRMA
      if (_deudaTotal == 0) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EvidenciaScreen(
              trackings: widget.trackings,
              montoCobrado: 0.0,
              requiereFirma: true, // <-- EXIGIMOS FIRMA
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Error al obtener deuda'),
          backgroundColor: AppColors.error,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _irATomarFotos() {
    double totalACobrar = _deudaTotal - _descuento;
    if (totalACobrar < 0) totalACobrar = 0;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EvidenciaScreen(
          trackings: widget.trackings,
          montoCobrado: totalACobrar,
          requiereFirma:
              false, // <-- COMO HUBO DEUDA, NO EXIGIMOS FIRMA (Por ahora)
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
                          bool requiereCobro =
                              (item['pago'] == 'PAGO EN DESTINO' ||
                              item['pago'] == 'CREDITO');
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              title: Text(
                                item['descripcion'] ?? 'Producto',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                "Tracking: ${item['codigo']}\nEstado: ${item['pago']}",
                              ),
                              trailing: Text(
                                requiereCobro
                                    ? "S/ ${item['op_total']}"
                                    : "PAGADO",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: requiereCobro
                                      ? AppColors.error
                                      : AppColors.success,
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
