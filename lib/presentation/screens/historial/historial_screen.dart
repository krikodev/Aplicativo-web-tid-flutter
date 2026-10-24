import 'dart:async';

import 'package:flutter/material.dart';
import 'package:apps_transporte/core/utils/app_colors.dart';
import 'package:apps_transporte/data/datasources/api_service.dart';

class HistorialScreen extends StatefulWidget {
  static const routeName = '/historial';

  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final _buscarController = TextEditingController();

  bool _isLoading = true;
  List<dynamic> _historial = [];
  DateTime _fechaSeleccionada = DateTime.now();
  Timer? _buscarTimer;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  @override
  void dispose() {
    _buscarTimer?.cancel();
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
      return "Hoy";
    }
    return "${date.day}/${date.month}/${date.year}";
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final seleccion = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.accent,
            ),
          ),
          child: child!,
        );
      },
    );

    if (seleccion != null) {
      setState(() => _fechaSeleccionada = seleccion);
      _cargarHistorial();
    }
  }

  void _seleccionarFechaRapida(DateTime fecha) {
    setState(() => _fechaSeleccionada = fecha);
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    final result = await ApiService.getHistorialEntregadas(
      filtro: _buscarController.text.trim(),
      fecha: _formatearFechaBD(_fechaSeleccionada),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _historial = result['success'] == true
          ? (result['data'] ?? [])
          : [];
    });
  }

  void _buscarConRetraso(String value) {
    _buscarTimer?.cancel();
    _buscarTimer = Timer(const Duration(milliseconds: 450), () {
      _cargarHistorial();
    });
  }

  void _mostrarFotos(BuildContext context, String? urlsString) {
    if (urlsString == null || urlsString.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay fotos para esta entrega')),
      );
      return;
    }

    final urls = urlsString
        .split(',')
        .where((url) => url.trim().isNotEmpty)
        .toList();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Evidencias',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
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
                      padding: const EdgeInsets.all(16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          urls[index].trim(),
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
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
                                    Icons.broken_image_outlined,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'No se pudo cargar la foto',
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
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                urls.length == 1
                    ? '1 evidencia'
                    : '${urls.length} evidencias • desliza para ver más',
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mostrarDetalle(BuildContext context, dynamic item) async {
    final tracking = item['traking'] ?? item['tracking'] ?? item['codigo'] ?? 'Sin código';
    final destinatario = item['destinatario'] ?? 'Desconocido';
    final documento = item['documentoDes'] ?? 'No registrado';
    final fechaSalida = item['fecha_salida'] ?? 'N/A';
    final fechaEntrega = item['fecha_entrega'] ?? 'N/A';
    final producto = item['producto'] ?? 'Sin detalle';
    final origen = item['origen'] ?? 'Agencia';
    final destino = item['destino'] ?? 'Agencia';
    final fotosString = item['fotos_evidencia'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Entrega completada',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tracking.toString(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInfoTile(
                  Icons.person_outline,
                  'Destinatario',
                  destinatario.toString(),
                ),
                _buildInfoTile(
                  Icons.badge_outlined,
                  'DNI / Documento',
                  documento.toString(),
                ),
                _buildInfoTile(
                  Icons.route_outlined,
                  'Ruta',
                  '$origen → $destino',
                ),
                _buildInfoTile(
                  Icons.inventory_2_outlined,
                  'Contenido',
                  producto.toString(),
                ),
                _buildInfoTile(
                  Icons.schedule_outlined,
                  'Entrega',
                  fechaEntrega.toString(),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _mostrarFotos(context, fotosString),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Ver evidencias'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.textGrey),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textGrey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFechaChip({
    required String label,
    required DateTime fecha,
    required bool seleccionado,
  }) {
    return GestureDetector(
      onTap: () => _seleccionarFechaRapida(fecha),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: seleccionado ? AppColors.textDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccionado
                ? AppColors.textDark
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: seleccionado ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final ayer = DateTime(hoy.year, hoy.month, hoy.day - 1);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Historial',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_historial.length} entrega${_historial.length == 1 ? '' : 's'} • ${_formatearFechaUI(_fechaSeleccionada)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Elegir fecha',
                    onPressed: () => _seleccionarFecha(context),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(11),
                    ),
                    icon: const Icon(
                      Icons.calendar_today_outlined,
                      size: 20,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),

            // Fechas de acceso rápido.
            SizedBox(
              height: 42,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                children: [
                  _buildFechaChip(
                    label: 'Hoy',
                    fecha: hoy,
                    seleccionado:
                        _fechaSeleccionada.year == hoy.year &&
                        _fechaSeleccionada.month == hoy.month &&
                        _fechaSeleccionada.day == hoy.day,
                  ),
                  const SizedBox(width: 8),
                  _buildFechaChip(
                    label: 'Ayer',
                    fecha: ayer,
                    seleccionado:
                        _fechaSeleccionada.year == ayer.year &&
                        _fechaSeleccionada.month == ayer.month &&
                        _fechaSeleccionada.day == ayer.day,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Buscador sencillo: DNI o tracking.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _buscarController,
                onChanged: _buscarConRetraso,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _cargarHistorial(),
                decoration: InputDecoration(
                  hintText: 'Buscar por DNI o tracking',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textGrey,
                  ),
                  suffixIcon: _buscarController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _buscarController.clear();
                            _cargarHistorial();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: RefreshIndicator(
                color: AppColors.accent,
                onRefresh: _cargarHistorial,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                        ),
                      )
                    : _historial.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 80,
                            ),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.inbox_outlined,
                                  size: 42,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Center(
                                child: Text(
                                  'No hay entregas',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Center(
                                child: Text(
                                  'Prueba otra fecha o busca por DNI/tracking.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textGrey,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                            itemCount: _historial.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              return _buildHistoryCard(
                                context,
                                _historial[index],
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, dynamic item) {
    final tracking =
        item['traking'] ?? item['tracking'] ?? item['codigo'] ?? 'Sin código';
    final destinatario = item['destinatario'] ?? 'Desconocido';
    final fechaEntrega = item['fecha_entrega'] ?? 'N/A';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _mostrarDetalle(context, item),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tracking.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      destinatario.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_outlined,
                          size: 13,
                          color: AppColors.textGrey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            fechaEntrega.toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'ENTREGADO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                  SizedBox(height: 7),
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.textGrey,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
