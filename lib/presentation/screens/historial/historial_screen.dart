import 'package:flutter/material.dart';
import 'package:apps_transporte/core/utils/app_colors.dart';
// import 'package:apps_transporte/core/widgets/custom_text_field.dart'; // Mantenido por si acaso
import 'package:apps_transporte/data/datasources/api_service.dart';

class HistorialScreen extends StatefulWidget {
  static const routeName = '/historial';

  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  // ==========================================
  // LÓGICA INTACTA (0% CAMBIOS AQUÍ)
  // ==========================================
  final _buscarController = TextEditingController();
  bool _isLoading = true;
  List<dynamic> _historial = [];

  // POR DEFECTO: La fecha de hoy
  DateTime _fechaSeleccionada = DateTime.now();

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  @override
  void dispose() {
    _buscarController.dispose();
    super.dispose();
  }

  String _formatearFechaBD(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String _formatearFechaUI(DateTime date) {
    final hoy = DateTime.now();
    if (date.year == hoy.year &&
        date.month == hoy.month &&
        date.day == hoy.day) {
      return "Hoy (${date.day}/${date.month}/${date.year})";
    }
    return "${date.day}/${date.month}/${date.year}";
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? seleccion = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.textDark),
          ),
          child: child!,
        );
      },
    );

    if (seleccion != null && seleccion != _fechaSeleccionada) {
      setState(() {
        _fechaSeleccionada = seleccion;
      });
      _cargarHistorial();
    }
  }

  Future<void> _cargarHistorial() async {
    setState(() => _isLoading = true);

    final filtro = _buscarController.text.trim();
    final fechaBD = _formatearFechaBD(_fechaSeleccionada);

    final result = await ApiService.getHistorialEntregadas(
      filtro: filtro,
      fecha: fechaBD,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _historial = result['data'] ?? [];
        } else {
          _historial = [];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] ?? 'No se pudo consultar el historial',
              ),
            ),
          );
        }
      });
    }
  }

  void _mostrarFotos(BuildContext context, String? urlsString) {
    if (urlsString == null || urlsString.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay fotos para esta encomienda')),
      );
      return;
    }

    List<String> urls = urlsString
        .split(',')
        .where((url) => url.trim().isNotEmpty)
        .toList();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24), // Bordes más modernos
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Evidencias (${urls.length})",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.textDark,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.softBackground,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textDark,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 400,
                child: PageView.builder(
                  itemCount: urls.length,
                  itemBuilder: (context, index) {
                    return InteractiveViewer(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            urls[index].trim(),
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.accent,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      "Error al cargar imagen",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Desliza para ver más fotos",
                  style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // DISEÑO UI (UX/UI BASADO EN REFERENCIA)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Fondo claro
      body: SafeArea(
        bottom: false, // Permitimos que la lista baje hasta el fondo
        child: Column(
          children: [
            // --- CABECERA HISTORIAL CON CALENDARIO MODERNO ---
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
                          Icons.history,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Mis Entregas",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            _formatearFechaUI(_fechaSeleccionada),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Botón de calendario tipo tarjeta
                  GestureDetector(
                    onTap: () => _seleccionarFecha(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.calendar_month,
                            color: AppColors.accent,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            "Cambiar",
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- BUSCADOR ESTILO PÍLDORA ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
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
                    const Icon(Icons.search, color: AppColors.textGrey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _buscarController,
                        decoration: const InputDecoration(
                          hintText: 'Buscar Tracking o DNI...',
                          hintStyle: TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                        ),
                        onChanged: (value) => _cargarHistorial(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- LISTA DE HISTORIAL ---
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    )
                  : _historial.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: AppColors.textGrey.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Sin entregas el ${_formatearFechaUI(_fechaSeleccionada)}",
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                        left: 24,
                        right: 24,
                        bottom: 120,
                      ), // ¡Espacio para la barra flotante!
                      itemCount: _historial.length,
                      itemBuilder: (context, index) {
                        final item = _historial[index];

                        final tracking =
                            item['traking'] ?? item['codigo'] ?? 'ERR';
                        final destinatario =
                            item['destinatario'] ?? 'Desconocido';
                        final documento =
                            item['documentoDes'] ?? 'No registrado';
                        final fechaSalida = item['fecha_salida'] ?? 'N/A';
                        final fechaEntrega = item['fecha_entrega'] ?? 'N/A';
                        final producto = item['producto'] ?? 'Sin detalle';
                        final origen = item['origen'] ?? 'Agencia';
                        final destino = item['destino'] ?? 'Agencia';
                        final fotosString = item['fotos_evidencia'];

                        return _buildModernHistoryCard(
                          tracking: tracking,
                          destinatario: destinatario,
                          documento: documento,
                          origen: origen,
                          destino: destino,
                          fechaSalida: fechaSalida,
                          fechaEntrega: fechaEntrega,
                          producto: producto,
                          fotosString: fotosString,
                          context: context,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // WIDGET: TARJETA DE HISTORIAL (EXPANDIBLE)
  // ==========================================
  Widget _buildModernHistoryCard({
    required String tracking,
    required String destinatario,
    required String documento,
    required String origen,
    required String destino,
    required String fechaSalida,
    required String fechaEntrega,
    required String producto,
    required String? fotosString,
    required BuildContext context,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Theme(
        // Quitamos las líneas molestas del ExpansionTile por defecto
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: 20,
          ),
          // --- HEADER DE LA TARJETA ---
          title: Row(
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
                    Text(
                      tracking,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      destinatario,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "ENTREGADO",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          // --- CONTENIDO DESPLEGABLE ---
          children: [
            const Divider(height: 24, color: Color(0xFFF3F4F6), thickness: 1.5),

            // Ruta visual Origen -> Destino
            Row(
              children: [
                const Icon(
                  Icons.trip_origin,
                  size: 14,
                  color: AppColors.textGrey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    origen,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_right_alt, color: AppColors.textGrey),
                Expanded(
                  child: Text(
                    destino,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.location_on,
                  size: 14,
                  color: AppColors.accent,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Detalles limpios
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildDetailRow("DNI/Doc:", documento),
                  _buildDetailRow("Contenido:", producto),
                  _buildDetailRow("Salida:", fechaSalida),
                  _buildDetailRow("Entregado:", fechaEntrega),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Botón oscuro para ver fotos
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _mostrarFotos(context, fotosString),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text("Ver Evidencias Fotográficas"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E1E), // Oscuro elegante
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
