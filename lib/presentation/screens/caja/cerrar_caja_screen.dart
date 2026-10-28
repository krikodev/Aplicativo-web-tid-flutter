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

    Widget contenido;

    if (_cargando) {
      contenido = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    } else if (_error != null) {
      contenido = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.error_outline, size: 52, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _cargarCaja,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      );
    } else if (_caja == null) {
      contenido = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 80),
          Icon(Icons.account_balance_wallet_outlined, size: 56, color: Colors.black45),
          SizedBox(height: 16),
          Text(
            'No tienes una caja chica abierta.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      );
    } else {
      contenido = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
        children: [
          _dato('Referencia', _valor(_caja!['referencia'])),
          _dato('Saldo inicial', 'S/ ' + _valor(_caja!['saldo_inicial'])),
          _dato('Fecha de inicio', _valor(_caja!['fecha_inicio'])),
          _dato('Estado', cerrada ? 'CERRADA' : 'ABIERTA'),
          if (cerrada) _dato('Fecha de cierre', _valor(_caja!['fecha_fin'])),
          const SizedBox(height: 10),
          if (!cerrada)
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _cerrando ? null : _cerrarCaja,
                icon: _cerrando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.lock_outline),
                label: Text(_cerrando ? 'Cerrando...' : 'Cerrar caja'),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'La caja ya fue cerrada correctamente.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cerrar caja'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _cargarCaja,
        child: contenido,
      ),
    );
  }
}