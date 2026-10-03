import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:apps_transporte/core/utils/app_colors.dart';
import 'package:apps_transporte/core/widgets/custom_button.dart';
import 'package:apps_transporte/data/datasources/api_service.dart';

class EvidenciaScreen extends StatefulWidget {
  final List<String> trackings;

  const EvidenciaScreen({super.key, required this.trackings});

  @override
  State<EvidenciaScreen> createState() => _EvidenciaScreenState();
}

class _EvidenciaScreenState extends State<EvidenciaScreen> {
  // ==========================================
  // LÓGICA INTACTA (0% CAMBIOS AQUÍ)
  // ==========================================
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _fotos = [];
  bool _isUploading = false;

  int get fotosRequeridas => widget.trackings.length * 2;

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
        final List<XFile> seleccionadas = await _picker.pickMultiImage(
          limit: faltantes,
          imageQuality: 80,
        );

        if (seleccionadas.isNotEmpty) {
          setState(() {
            _fotos.addAll(seleccionadas);
          });
        }
      } else {
        final XFile? foto = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
        );

        if (foto != null) {
          setState(() {
            _fotos.add(foto);
          });
        }
      }
    } catch (e) {
      print("Error al obtener foto: $e");
    }
  }

  void _eliminarFoto(int index) {
    setState(() {
      _fotos.removeAt(index);
    });
  }

  Future<void> _finalizarEntrega() async {
    if (_fotos.length != fotosRequeridas) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Faltan fotos. Necesitas $fotosRequeridas fotos en total.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    final result = await ApiService.registrarEntregaLote(
      trackings: widget.trackings,
      fotos: _fotos,
    );

    setState(() => _isUploading = false);

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Entregas registradas y subidas con éxito!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['error'] ?? result['message'] ?? 'Error desconocido',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ==========================================
  // DISEÑO UI (UX/UI BASADO EN REFERENCIA)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final int faltantes = fotosRequeridas - _fotos.length;
    final bool isComplete = faltantes == 0;

    return Scaffold(
      backgroundColor: const Color(
        0xFFF8F9FA,
      ), // Fondo extra claro coherente con Home
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
            // --- TARJETA DE ESTADO SUPERIOR ---
            Container(
              margin: const EdgeInsets.all(24),
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
                          isComplete ? Icons.check_circle : Icons.camera_alt,
                          color: isComplete
                              ? AppColors.success
                              : AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Barra de progreso visual
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

            // --- BOTONES: CÁMARA Y GALERÍA ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
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
                      color: const Color(0xFF1E1E1E), // Oscuro elegante
                      onTap: faltantes > 0
                          ? () => _obtenerFoto(ImageSource.gallery)
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- GRILLA DE FOTOS TOMADAS ---
            Expanded(
              child: _fotos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_search,
                            size: 64,
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
                          const SizedBox(height: 8),
                          const Text(
                            "Toma 2 fotos por paquete.",
                            style: TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1, // Cuadradas
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
                            // Botón "X" para eliminar foto
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
            ),

            // --- BOTÓN FINAL DE SUBIDA ---
            Container(
              padding: const EdgeInsets.fromLTRB(
                24,
                16,
                24,
                32,
              ), // Padding inferior extra para celulares sin botones
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
                // Solo se activa si las fotos están completas
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

  // ==========================================
  // WIDGET AUXILIAR: BOTONES DE CÁMARA/GALERÍA
  // ==========================================
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
