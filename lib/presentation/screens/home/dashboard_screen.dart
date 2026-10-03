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
  Map<String, dynamic>? _summary;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ApiService.getResumen();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _summary = result;
      } else {
        _summary = null;
        _error =
            result['message']?.toString() ?? 'No se pudo consultar el resumen.';
      }
    });
  }

  Widget _metric(String title, dynamic value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 16),
            Text(
              value?.toString() ?? '—',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            Text(title, style: const TextStyle(color: AppColors.textGrey)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recent = _summary?['recent'] as List? ?? [];
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Resumen General',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              Text(
                _summary == null
                    ? 'Consulta de tu terminal'
                    : 'Fecha: ${_summary!['fecha']}',
                style: const TextStyle(color: AppColors.textGrey),
              ),
              const SizedBox(height: 24),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Text(_error!, style: const TextStyle(color: AppColors.error))
              else ...[
                Row(
                  children: [
                    _metric(
                      'Entregados hoy',
                      _summary?['entregados'],
                      Icons.check_circle_outline,
                      AppColors.success,
                    ),
                    const SizedBox(width: 16),
                    _metric(
                      'Pendientes actuales',
                      _summary?['pendientes'],
                      Icons.inventory_2_outlined,
                      AppColors.accent,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pendientes en destino con pago autorizado.',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Últimas entregas de hoy',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (recent.isEmpty)
                  const Text(
                    'Todavía no hay entregas registradas en esta fecha.',
                  ),
                for (final item in recent)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.local_shipping_outlined),
                      title: Text(item['tracking']?.toString() ?? ''),
                      subtitle: Text(
                        '${item['destinatario'] ?? ''}\n${item['fecha_entrega'] ?? ''}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
