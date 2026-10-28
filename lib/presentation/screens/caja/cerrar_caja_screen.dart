import 'package:flutter/material.dart';
import 'package:apps_transporte/data/datasources/api_service.dart';

class CerrarCajaScreen extends StatefulWidget {
  const CerrarCajaScreen({super.key});

  @override
  State<CerrarCajaScreen> createState() => _CerrarCajaScreenState();
}

class _CerrarCajaScreenState extends State<CerrarCajaScreen> {
  Map<String, dynamic>? _caja;
  bool _cargando = true;
  bool _cerrando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarCaja();
  }

  Future<void> _cargarCaja() async {
    setState(() { _cargando = true; _error = null; });
    final r = await ApiService.obtenerCajaAbierta();
    if (!mounted) return;
    if (r['success'] == true) {
      final caja = r['caja'];
      setState(() {
        _caja = r['caja_abierta'] == true && caja is Map<String, dynamic>
            ? Map<String, dynamic>.from(caja)
            : null;
        _cargando = false;
      });
    } else {
      setState(() {
        _error = r['error']?.toString() ?? r['message']?.toString() ?? 'No se pudo consultar la caja.';
        _cargando = false;
      });
    }
  }

  Future<void> _cerrarCaja() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar caja'),
        content: const Text('¿Estás seguro de cerrar la caja chica? Después de cerrarla no podrás registrar nuevos cobros en esta caja.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar caja')),
        ],
      ),
    );
    if (confirmar != true || _caja == null || _cerrando) return;
    setState(() => _cerrando = true);
    final r = await ApiService.cerrarCaja();
    if (!mounted) return;
    if (r['success'] == true) {
      final caja = r['caja'];
      setState(() {
        _caja = caja is Map<String, dynamic> ? Map<String, dynamic>.from(caja) : _caja;
        _cerrando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caja cerrada correctamente.')));
    } else {
      setState(() => _cerrando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r['error']?.toString() ?? r['message']?.toString() ?? 'No se pudo cerrar la caja.')));
    }
  }

  String _v(dynamic v) => v == null || v.toString().trim().isEmpty ? '-' : v.toString();

  Widget _dato(String titulo, dynamic valor) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Expanded(child: Text(titulo, style: const TextStyle(color: Colors.black54, fontSize: 13))),
      Text(_v(valor), textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final cerrada = _caja?['estado']?.toString() == '0';
    return Scaffold(
      appBar: AppBar(title: const Text('Cerrar caja'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _cargarCaja,
        child: _cargando
            ? const ListView(physics: AlwaysScrollableScrollPhysics(), children: [SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))])
            : _error != null
                ? ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(24), children: [
                    const SizedBox(height: 80),
                    const Icon(Icons.error_outline, size: 52, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Center(child: Text(_error!, textAlign: TextAlign.center)),
                    const SizedBox(height: 16),
                    Center(child: OutlinedButton.icon(onPressed: _cargarCaja, icon: const Icon(Icons.refresh), label: const Text('Reintentar'))),
                  ]
                  )
                : _caja == null
                    ? ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(24), children: const [
                        SizedBox(height: 80),
                        Icon(Icons.account_balance_wallet_outlined, size: 56, color: Colors.black45),
                        SizedBox(height: 16),
                        Center(child: Text('No tienes una caja chica abierta.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                      ])
                    : ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 20, 16, 120), children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(18)),
                          child: Row(children: [
                            const Icon(Icons.account_balance_wallet, color: Colors.white, size: 30),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('Caja chica', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 3),
                              Text(_v(_caja!['referencia']), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
                            ])),
                          ]),
                        ),
                        const SizedBox(height: 18),
                        _dato('Saldo inicial', 'S/ ${_v(_caja!['saldo_inicial'])}'),
                        _dato('Fecha de inicio', _v(_caja!['fecha_inicio'])),
                        _dato('Estado', cerrada ? 'CERRADA' : 'ABIERTA'),
                        if (cerrada) _dato('Fecha de cierre', _v(_caja!['fecha_fin'])),
                        const SizedBox(height: 8),
                        if (!cerrada)
                          SizedBox(height: 52, child: FilledButton.icon(onPressed: _cerrando ? null : _cerrarCaja, icon: _cerrando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.lock_outline), label: Text(_cerrando ? 'Cerrando...' : 'Cerrar caja')))
                        else
                          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)), child: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 10), Expanded(child: Text('La caja ya fue cerrada correctamente.', style: TextStyle(fontWeight: FontWeight.w600)))])),
                      ],
      ),
    );
  }
}