import 'package:flutter/material.dart';
import 'package:apps_transporte/core/utils/app_colors.dart';
import 'package:apps_transporte/data/datasources/api_service.dart';
import 'package:apps_transporte/presentation/routes/app_routes.dart';
import 'package:apps_transporte/presentation/screens/home/dashboard_screen.dart';
import 'package:apps_transporte/presentation/screens/home/home_screen.dart';
import 'package:apps_transporte/presentation/screens/historial/historial_screen.dart';

class MainLayout extends StatefulWidget {
  static const routeName = '/main';
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  int _selectedPackagesCount = 0;

  // LLAVE MAESTRA: Nos permite controlar la pantalla de Despacho desde aquí
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const DashboardScreen(), // 0
          HomeScreen(
            // 1
            key: _homeKey,
            onSelectionChanged: (count) {
              // Cuando el usuario marca un paquete, actualizamos el botón central
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _selectedPackagesCount = count);
              });
            },
          ),
          const HistorialScreen(), // 2
          // LA 5TA FUNCIONALIDAD (En blanco por ahora)
          Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ApiService.currentUser?['nombres']?.toString() ??
                          'Usuario',
                    ),
                    const SizedBox(height: 16),
                    const Text('Conexión de solo consulta'),
                    TextButton.icon(
                      onPressed: () async {
                        await ApiService.logout();
                        if (!context.mounted) return;
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.login,
                          (_) => false,
                        );
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar sesión'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await ApiService.logout();
                        if (!context.mounted) return;
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.configuracion,
                          (_) => false,
                        );
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('Cambiar servidor o empresa'),
                    ),
                  ],
                ),
              ),
            ),
          ), // 3
        ],
      ),
      bottomNavigationBar: _buildFloatingBottomNav(),
    );
  }

  Widget _buildFloatingBottomNav() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildNavItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Resumen',
                  index: 0,
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  icon: Icons.local_shipping_outlined,
                  activeIcon: Icons.local_shipping,
                  label: 'Despacho',
                  index: 1,
                ),
              ),

              // EL BOTÓN CAMALEÓN
              _buildIntelligentCenterButton(),

              Expanded(
                child: _buildNavItem(
                  icon: Icons.history_outlined,
                  activeIcon: Icons.history,
                  label: 'Historial',
                  index: 2,
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Perfil',
                  index: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? Colors.white : Colors.white54,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white54,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // =======================================================================
  // DISEÑO UI: BOTÓN INTELIGENTE (ESCANEAR -> ENVIAR)
  // =======================================================================
  Widget _buildIntelligentCenterButton() {
    // Si estamos en la pestaña de Despacho y hay paquetes seleccionados...
    bool isDelivering = _currentIndex == 1 && _selectedPackagesCount > 0;

    return GestureDetector(
      onTap: () {
        if (isDelivering) {
          // DISPARA LA FUNCIÓN DE LA OTRA PANTALLA
          _homeKey.currentState?.continuarEntrega();
        } else {
          // Si no, simplemente nos lleva a la pestaña de Despacho
          setState(() => _currentIndex = 1);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutExpo,
        width: isDelivering ? 110 : 50, // Se expande horizontalmente
        height: 50,
        decoration: BoxDecoration(
          color: isDelivering ? AppColors.success : AppColors.accent,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: (isDelivering ? AppColors.success : AppColors.accent)
                  .withOpacity(0.4),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isDelivering
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Solo lectura",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              )
            : const Icon(
                Icons.document_scanner_outlined,
                color: Colors.white,
                size: 24,
              ),
      ),
    );
  }
}
