import 'package:flutter/material.dart';
import 'package:apps_transporte/presentation/screens/configuracion/configuracion_screen.dart';
import 'package:apps_transporte/presentation/screens/login/login_screen.dart';
import 'package:apps_transporte/presentation/screens/main_layout.dart';
import 'package:apps_transporte/presentation/screens/historial/historial_screen.dart';
import 'package:apps_transporte/presentation/screens/home/home_screen.dart';

class AppRoutes {
  static const String configuracion = ConfiguracionScreen.routeName;
  static const String login = LoginScreen.routeName;

  // NUEVA RUTA PRINCIPAL (El menú inferior)
  static const String mainLayout = MainLayout.routeName;

  static const String home = HomeScreen.routeName;
  static const String historial = HistorialScreen.routeName;

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case configuracion:
        return MaterialPageRoute(builder: (_) => const ConfiguracionScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      // AGREGAMOS EL CASO PARA EL MENÚ INFERIOR
      case mainLayout:
        return MaterialPageRoute(builder: (_) => const MainLayout());

      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case historial:
        return MaterialPageRoute(builder: (_) => const HistorialScreen());
      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Ruta no encontrada'))),
        );
    }
  }
}
