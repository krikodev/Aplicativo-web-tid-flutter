import 'package:flutter/material.dart';
import 'package:apps_transporte/data/datasources/api_service.dart';
import 'package:apps_transporte/core/utils/app_colors.dart';
import 'package:apps_transporte/presentation/routes/app_routes.dart';

// Empezamos por defecto en la pantalla de configuración (o splash)
String initialRoute = AppRoutes.configuracion;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // El token permanece en memoria; al reiniciar se requiere login.
  initialRoute = await ApiService.hasConfiguration()
      ? AppRoutes.login
      : AppRoutes.configuracion;

  runApp(const TransPortaProApp());
}

final navigatorKey = GlobalKey<NavigatorState>();

class TransPortaProApp extends StatefulWidget {
  const TransPortaProApp({super.key});

  @override
  State<TransPortaProApp> createState() => _TransPortaProAppState();
}

class _TransPortaProAppState extends State<TransPortaProApp> {
  @override
  void initState() {
    super.initState();
    ApiService.sessionExpired.addListener(_onSessionExpired);
  }

  void _onSessionExpired() {
    if (!ApiService.sessionExpired.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppRoutes.login,
          (_) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    ApiService.sessionExpired.removeListener(_onSessionExpired);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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
