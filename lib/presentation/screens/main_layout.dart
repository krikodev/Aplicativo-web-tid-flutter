import 'package:flutter/material.dart';
import 'package:apps_transporte/core/utils/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          DashboardScreen(),
          HomeScreen(),
          HistorialScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(33),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(child: _buildNavItem(
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard,
                label: 'Inicio',
                index: 0,
              )),
              Expanded(child: _buildNavItem(
                icon: Icons.local_shipping_outlined,
                activeIcon: Icons.local_shipping,
                label: 'Entregar',
                index: 1,
              )),
              Expanded(child: _buildNavItem(
                icon: Icons.history_outlined,
                activeIcon: Icons.history,
                label: 'Historial',
                index: 2,
              )),
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
    final selected = _currentIndex == index;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selected ? activeIcon : icon,
            color: selected ? Colors.white : Colors.white54,
            size: 23,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
