import 'package:flutter/material.dart';
import 'package:apps_transporte/core/utils/app_colors.dart';
import 'package:apps_transporte/data/datasources/api_service.dart';
import 'evidencia_screen.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';
  // NUEVO: Canal de comunicación con la barra inferior
  final void Function(int)? onSelectionChanged;

  const HomeScreen({super.key, this.onSelectionChanged});

  @override
  // NUEVO: Hacemos la clase pública quitando el "_" al inicio
  State<HomeScreen> createState() => HomeScreenState();
}

// Clase pública para que el MainLayout la pueda ejecutar
class HomeScreenState extends State<HomeScreen> {
  final _dniController = TextEditingController();
  bool _isLoading = false;
  List<dynamic> _encomiendas = [];
  final Set<String> _trackingsSeleccionados = {};

  @override
  void dispose() {
    _dniController.dispose();
    super.dispose();
  }

  Future<void> _buscarPorDni() async {
    final dni = _dniController.text.trim();
    if (dni.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa un DNI')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _encomiendas = [];
      _trackingsSeleccionados.clear();
    });
    if (widget.onSelectionChanged != null) widget.onSelectionChanged!(0);

    final result = await ApiService.getEncomiendasPorDni(dni);

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      setState(() {
        _encomiendas = result['data'] ?? [];
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Error al buscar')),
      );
    }
  }

  // NUEVO: Esta función ahora la llamará el botón central
  Future<void> continuarEntrega() async {
    if (_trackingsSeleccionados.isEmpty) return;

    final resultadoEntrega = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EvidenciaScreen(trackings: _trackingsSeleccionados.toList()),
      ),
    );

    if (resultadoEntrega == true) {
      _trackingsSeleccionados.clear();
      if (widget.onSelectionChanged != null) widget.onSelectionChanged!(0);
      _buscarPorDni();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- CABECERA ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_shipping,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Despacho Rápido",
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textGrey,
                            ),
                          ),
                          Text(
                            "Búsqueda por DNI",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.notifications_none,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),

            // --- BUSCADOR ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                padding: const EdgeInsets.only(
                  left: 8,
                  right: 8,
                  top: 4,
                  bottom: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.search, color: AppColors.textGrey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _dniController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Ingresar DNI...',
                          hintStyle: TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _buscarPorDni(),
                      ),
                    ),
                    GestureDetector(
                      onTap: _buscarPorDni,
                      child: Container(
                        width: 45,
                        height: 45,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E1E1E),
                          shape: BoxShape.circle,
                        ),
                        child: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                                size: 18,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                "Paquetes Pendientes",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- LISTA ---
            Expanded(
              child: _encomiendas.isEmpty
                  ? const Center(
                      child: Text(
                        'Ingresa un DNI para ver los paquetes.',
                        style: TextStyle(color: AppColors.textGrey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                        left: 24,
                        right: 24,
                        bottom: 120,
                      ),
                      itemCount: _encomiendas.length,
                      itemBuilder: (context, index) {
                        final item = _encomiendas[index];
                        final String trackingStr =
                            item['traking']?.toString() ?? 'ERR';
                        final bool isSelected = _trackingsSeleccionados
                            .contains(trackingStr);

                        return _buildModernCard(
                          trackingStr: trackingStr,
                          destinatario: item['destinatario'] ?? 'Desconocido',
                          remitente: item['remitente'] ?? 'Desconocido',
                          estado: item['estado']?.toString() ?? 'Pendiente',
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              if (isSelected)
                                _trackingsSeleccionados.remove(trackingStr);
                              else
                                _trackingsSeleccionados.add(trackingStr);
                            });
                            // Le avisamos al menú cuántos hay seleccionados
                            if (widget.onSelectionChanged != null) {
                              widget.onSelectionChanged!(
                                _trackingsSeleccionados.length,
                              );
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernCard({
    required String trackingStr,
    required String destinatario,
    required String remitente,
    required String estado,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.accent.withOpacity(0.15)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.inventory_2,
                    color: AppColors.textDark,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "ID de Paquete",
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textGrey,
                        ),
                      ),
                      Text(
                        trackingStr,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.accent,
                    child: Icon(Icons.check, color: Colors.white, size: 18),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.softBackground,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      estado.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.radio_button_checked,
                            color: AppColors.accent,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              remitente,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 22.0, top: 2),
                        child: Text(
                          "Origen",
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    "- - - -",
                    style: TextStyle(color: Colors.black26, letterSpacing: 2),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              destinatario,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.location_on,
                            color: AppColors.textGrey,
                            size: 16,
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.only(right: 22.0, top: 2),
                        child: Text(
                          "Destino",
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
