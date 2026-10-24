import 'package:flutter/material.dart';
import 'package:apps_transporte/core/utils/app_colors.dart';
import 'package:apps_transporte/data/datasources/api_service.dart';
import 'cobro_screen.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';
  final void Function(int)? onSelectionChanged;

  const HomeScreen({super.key, this.onSelectionChanged});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final _dniController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _isLoading = false;
  bool _buscarPorTracking = false;
  Timer? _temporizadorBusqueda;
  int _versionBusqueda = 0;
  List<dynamic> _encomiendas = [];
  final Set<String> _trackingsSeleccionados = {};

  @override
  void dispose() {
    _temporizadorBusqueda?.cancel();
    _dniController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _buscar({String? consulta}) async {
    final termino = (consulta ?? _dniController.text).trim();

    if (termino.length < 3) {
      _limpiarResultados();
      return;
    }

    final versionActual = ++_versionBusqueda;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.getEncomiendasPorDni(termino);

      if (!mounted || versionActual != _versionBusqueda) return;

      setState(() {
        _isLoading = false;
        _encomiendas = result['success'] == true ? result['data'] ?? [] : [];
      });

      _trackingsSeleccionados.clear();
      widget.onSelectionChanged?.call(0);
      _searchFocusNode.unfocus();

      if (result['success'] != true && result['message'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'].toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted || versionActual != _versionBusqueda) return;

      setState(() {
        _isLoading = false;
        _encomiendas = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo realizar la búsqueda'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _limpiarResultados() {
    _versionBusqueda++;

    setState(() {
      _encomiendas = [];
      _trackingsSeleccionados.clear();
      _isLoading = false;
    });

    widget.onSelectionChanged?.call(0);
  }

  void _cambiarModo(bool tracking) {
    _temporizadorBusqueda?.cancel();

    setState(() {
      _buscarPorTracking = tracking;
      _dniController.clear();
    });

    _limpiarResultados();
  }

  void _onSearchChanged(String valor) {
    _temporizadorBusqueda?.cancel();

    final termino = valor.trim();

    if (termino.isEmpty) {
      _limpiarResultados();
      return;
    }

    // DNI: búsqueda automática únicamente al completar los 8 dígitos.
    if (!_buscarPorTracking) {
      final soloNumeros = termino.replaceAll(RegExp(r'\D'), '');

      if (soloNumeros.length == 8) {
        _buscar(consulta: soloNumeros);
      } else if (soloNumeros.length > 8) {
        _limpiarResultados();
      } else {
        _limpiarResultados();
      }
      return;
    }

    // Tracking: no hacemos búsquedas parciales.
    // El usuario confirma con el teclado para evitar consultas innecesarias.
  }

  Future<void> continuarEntrega() async {
    if (_trackingsSeleccionados.isEmpty) return;

    // <-- AHORA LLAMA A COBROSCREEN, NO A EVIDENCIAS
    final resultadoEntrega = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CobroScreen(trackings: _trackingsSeleccionados.toList()),
      ),
    );

    if (resultadoEntrega == true) {
      _temporizadorBusqueda?.cancel();
      _dniController.clear();
      _searchFocusNode.unfocus();
      _limpiarResultados();
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
                            "Entregas",
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDEEF0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSearchMode(
                            label: 'DNI',
                            icon: Icons.badge_outlined,
                            selected: !_buscarPorTracking,
                            onTap: () => _cambiarModo(false),
                          ),
                        ),
                        Expanded(
                          child: _buildSearchMode(
                            label: 'Tracking',
                            icon: Icons.qr_code_2_rounded,
                            selected: _buscarPorTracking,
                            onTap: () => _cambiarModo(true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _isLoading
                            ? AppColors.accent.withOpacity(0.35)
                            : Colors.transparent,
                      ),
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
                        Icon(
                          _buscarPorTracking
                              ? Icons.qr_code_2_rounded
                              : Icons.badge_outlined,
                          color: AppColors.textGrey,
                          size: 21,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _dniController,
                            focusNode: _searchFocusNode,
                            keyboardType: _buscarPorTracking
                                ? TextInputType.text
                                : TextInputType.number,
                            textInputAction: TextInputAction.search,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: _buscarPorTracking
                                  ? 'Código de tracking'
                                  : 'DNI del destinatario',
                              hintStyle: const TextStyle(
                                color: AppColors.textGrey,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                            ),
                            onChanged: _onSearchChanged,
                            onSubmitted: (_) => _buscar(),
                          ),
                        ),
                        if (_dniController.text.isNotEmpty && !_isLoading)
                          IconButton(
                            tooltip: 'Limpiar',
                            onPressed: () {
                              _dniController.clear();
                              _limpiarResultados();
                              setState(() {});
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: AppColors.textGrey,
                            ),
                          ),
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                color: AppColors.accent,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!_buscarPorTracking)
                    const Padding(
                      padding: EdgeInsets.only(left: 4, top: 7),
                      child: Text(
                        'La búsqueda inicia al completar 8 dígitos',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ),
                  if (_buscarPorTracking)
                    const Padding(
                      padding: EdgeInsets.only(left: 4, top: 7),
                      child: Text(
                        'Ingresa el código y presiona buscar',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                "Encomiendas",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _encomiendas.isEmpty
                  ? const Center(
                      child: Text(
                        'Busca por DNI o tracking',
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
                          onTap: () async {
                            if (_isLoading) return;
                            _trackingsSeleccionados
                              ..clear()
                              ..add(trackingStr);
                            widget.onSelectionChanged?.call(1);
                            await continuarEntrega();
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

  Widget _buildSearchMode({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? AppColors.textDark : AppColors.textGrey,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.textDark : AppColors.textGrey,
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
                        "Tracking",
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
