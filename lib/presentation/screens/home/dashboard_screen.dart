import 'package:flutter/material.dart';
import 'package:apps_transporte/core/utils/app_colors.dart';
import 'package:apps_transporte/data/datasources/api_service.dart';

class DashboardScreen extends StatefulWidget {
  static const routeName = '/dashboard';
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _entregas = [];

  @override
  void initState() {
    super.initState();
    _cargarResumen();
  }

  Future<void> _cargarResumen() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final now = DateTime.now();
    final fecha =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      final result = await ApiService.getHistorialEntregadas(fecha: fecha);

      if (!mounted) return;

      if (result['success'] == true) {
        final data = result['data'];
        setState(() {
          _entregas = data is List ? data : [];
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _entregas = [];
          _error = result['message']?.toString() ?? 'No se pudo cargar el resumen.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _entregas = [];
        _error = 'No se pudo cargar el resumen.';
      });
    }
  }

  String _value(dynamic item, List<String> keys) {
    if (item is Map) {
      for (final key in keys) {
        final value = item[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
    }
    return '—';
  }

  String _time(dynamic value) {
    if (value == null) return '';
    final match = RegExp(r'(\d{2}:\d{2})').firstMatch(value.toString());
    return match?.group(1) ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _cargarResumen,
          color: AppColors.accent,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resumen',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Actividad de hoy',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Actualizar',
                      onPressed: _loading ? null : _cargarResumen,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 100),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                )
              else if (_error != null)
                _empty(
                  Icons.cloud_off_outlined,
                  'Sin conexión',
                  _error!,
                  action: 'Reintentar',
                  onTap: _cargarResumen,
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: _metric(
                          Icons.check_circle_outline_rounded,
                          _entregas.length.toString(),
                          'Entregadas',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _metric(
                          Icons.today_rounded,
                          'Hoy',
                          'Fecha actual',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Últimas',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_entregas.isEmpty)
                  _empty(
                    Icons.inbox_outlined,
                    'Sin entregas',
                    'No hay entregas registradas hoy.',
                  )
                else
                  ..._entregas.take(5).map(_delivery),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _delivery(dynamic item) {
    final tracking = _value(item, ['traking', 'tracking', 'codigo']);
    final destinatario = _value(item, ['destinatario']);
    final fecha = _value(item, ['fecha_entrega']);
    final hora = _time(fecha);

    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tracking,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  destinatario,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          if (hora.isNotEmpty)
            Text(
              hora,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty(
    IconData icon,
    String title,
    String message, {
    String? action,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 70, 32, 40),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.textGrey.withOpacity(0.45)),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
          if (action != null && onTap != null) ...[
            const SizedBox(height: 16),
            TextButton(onPressed: onTap, child: Text(action)),
          ],
        ],
      ),
    );
  }
}
