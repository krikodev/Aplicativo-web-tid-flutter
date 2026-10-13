import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';
import 'package:apps_transporte/core/utils/app_colors.dart';
import 'package:apps_transporte/core/widgets/custom_button.dart';
import 'package:apps_transporte/data/datasources/api_service.dart';

class EvidenciaScreen extends StatefulWidget {
  final List<String> trackings;
  final double montoCobrado;
  final bool requiereFirma;
  final double descuento;
  final int? idMedioPago;

  const EvidenciaScreen({
    super.key,
    required this.trackings,
    required this.montoCobrado,
    required this.requiereFirma,
    this.descuento = 0.0,
    this.idMedioPago,
  });

  @override
  State<EvidenciaScreen> createState() => _EvidenciaScreenState();
}

class _EvidenciaScreenState extends State<EvidenciaScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _fotos = [];
  bool _isUploading = false;

  // Controlador de la firma (Líneas más gruesas y suaves)
  final SignatureController _firmaController = SignatureController(
    penStrokeWidth: 4,
    penColor: AppColors.textDark,
    exportBackgroundColor: Colors.white,
  );

  int get fotosRequeridas => widget.trackings.length * 2;

  @override
  void dispose() {
    _firmaController.dispose();
    super.dispose();
  }

  Future<void> _obtenerFoto(ImageSource source) async {
    final int faltantes = fotosRequeridas - _fotos.length;
    if (faltantes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ya tienes las $fotosRequeridas fotos necesarias.'),
          backgroundColor: AppColors.success,
        ),
      );
      return;
    }
    try {
      if (source == ImageSource.gallery) {
        final seleccionadas = await _picker.pickMultiImage(
          limit: faltantes,
          imageQuality: 80,
        );
        if (seleccionadas.isNotEmpty)
          setState(() => _fotos.addAll(seleccionadas));
      } else {
        final foto = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
        );
        if (foto != null) setState(() => _fotos.add(foto));
      }
    } catch (e) {
      print("Error foto: $e");
    }
  }

  void _eliminarFoto(int index) => setState(() => _fotos.removeAt(index));

  // MODIFICADO: finalizar entrega con fotos y firma separadas.
  Future<void> _finalizarEntrega() async {
    if (_fotos.length != fotosRequeridas) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Faltan fotos. Necesitas $fotosRequeridas.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // MODIFICADO: validar la firma solo cuando sea obligatoria.
    if (widget.requiereFirma && _firmaController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El cliente debe escribir su firma en el recuadro blanco.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    XFile? archivoFirma;

    // MODIFICADO: crear un archivo independiente para la firma.
    if (widget.requiereFirma) {
      try {
        final Uint8List? firmaBytes = await _firmaController.toPngBytes();

        if (firmaBytes == null || firmaBytes.isEmpty) {
          throw Exception('No se pudo generar la imagen de la firma.');
        }

        final tempDir = await getTemporaryDirectory();
        final archivo = await File(
          '${tempDir.path}/firma_${DateTime.now().millisecondsSinceEpoch}.png',
        ).create();

        await archivo.writeAsBytes(firmaBytes);

        archivoFirma = XFile(archivo.path);
      } catch (e) {
        if (!mounted) return;

        setState(() => _isUploading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar la firma. Inténtalo nuevamente.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    // MODIFICADO: fotos contiene únicamente fotografías de evidencia.
    // NUEVO: la firma se envía por el parámetro firma.
    try {
      // MODIFICADO: enviar los datos reales recibidos desde CobroScreen.
      final result = await ApiService.registrarEntregaLote(
        trackings: widget.trackings,
        fotos: List<XFile>.from(_fotos),
        firma: archivoFirma,
        montoCobrado: widget.montoCobrado,
        descuento: widget.descuento,

        // NUEVO: enviar el medio seleccionado en DETALLE COBRO.
        idMedioPago: widget.idMedioPago,
      );

      if (!mounted) return;

      setState(() => _isUploading = false);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Entregas registradas con éxito!'),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['error'] ?? 'Error desconocido al registrar la entrega.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isUploading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ocurrió un error al procesar la entrega.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int faltantes = fotosRequeridas - _fotos.length;
    final bool isComplete = faltantes == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Evidencias de Entrega",
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              // Cambiamos a ListView para que puedas scrollear hacia la firma
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                children: [
                  // --- TARJETA DE ESTADO ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Progreso de Fotos",
                                  style: TextStyle(
                                    color: AppColors.textGrey,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${_fotos.length} de $fotosRequeridas capturadas",
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isComplete
                                    ? AppColors.success.withOpacity(0.1)
                                    : AppColors.accent.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isComplete
                                    ? Icons.check_circle
                                    : Icons.camera_alt,
                                color: isComplete
                                    ? AppColors.success
                                    : AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: fotosRequeridas > 0
                                ? _fotos.length / fotosRequeridas
                                : 0,
                            backgroundColor: AppColors.softBackground,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isComplete ? AppColors.success : AppColors.accent,
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- BOTONES DE CÁMARA/GALERÍA ---
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.camera_alt_outlined,
                          label: "Cámara",
                          color: AppColors.accent,
                          onTap: faltantes > 0
                              ? () => _obtenerFoto(ImageSource.camera)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.photo_library_outlined,
                          label: "Galería",
                          color: const Color(0xFF1E1E1E),
                          onTap: faltantes > 0
                              ? () => _obtenerFoto(ImageSource.gallery)
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- GRILLA DE FOTOS ---
                  if (_fotos.isEmpty)
                    SizedBox(
                      height: 150,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_search,
                            size: 48,
                            color: AppColors.textGrey.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Aún no hay fotos.",
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(), // Evita scroll doble
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1,
                          ),
                      itemCount: _fotos.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.file(
                                  File(_fotos[index].path),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => _eliminarFoto(index),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                  // --- CUADRO DE FIRMA EN PANTALLA (SOLO SI REQUIERE) ---
                  if (widget.requiereFirma) ...[
                    const SizedBox(height: 32),
                    const Text(
                      "Firma del Cliente Requerida",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.accent.withOpacity(0.5),
                          width: 2,
                        ), // Borde llamativo
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Signature(
                          controller: _firmaController,
                          height: 200,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _firmaController.clear(),
                        icon: const Icon(
                          Icons.cleaning_services,
                          color: AppColors.error,
                          size: 18,
                        ),
                        label: const Text(
                          "Limpiar Firma",
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // --- BOTÓN DE CONFIRMAR ENTREGA ---
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: CustomButton(
                text: _isUploading
                    ? 'Subiendo Evidencias...'
                    : 'Confirmar Entrega',
                onPressed: isComplete ? _finalizarEntrega : () {},
                isLoading: _isUploading,
                backgroundColor: isComplete
                    ? AppColors.success
                    : AppColors.textGrey.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final bool isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isEnabled ? color : color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
