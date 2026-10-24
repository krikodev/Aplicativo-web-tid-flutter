import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apps_transporte/core/utils/app_colors.dart';
import 'package:apps_transporte/presentation/routes/app_routes.dart';

// Empezamos por defecto en la pantalla de configuración (o splash)
String initialRoute = AppRoutes.configuracion;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // 1. Verificamos si el usuario ya configuró la empresa (dominio)
  final dominioGuardado = prefs.getString('company_domain');

  // 2. Verificamos si el usuario ya inició sesión (puedes ajustar el nombj de tu variable)
  final estaLogueado = prefs.getBool('is_logged_in') ?? false;

  if (dominioGuardado != null && dominioGuardado.isNotEmpty) {
    if (estaLogueado) {
      // Si ya configuró empresa y ya hizo login, va directo al trabajo
      initialRoute = AppRoutes.mainLayout;
    } else {
      // Si configuró la empresa pero cerró sesión, va al login
      initialRoute = AppRoutes.login;
    }
  }

  runApp(const TransPortaProApp());
}

class TransPortaProApp extends StatelessWidget {
  const TransPortaProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TransPorta Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent),
        fontFamily: 'SFPro',
        scaffoldBackgroundColor: AppColors.background,
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accent,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),

      // RUTAS DINÁMICAS
      initialRoute: initialRoute,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
