import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apps_transporte/core/utils/app_colors.dart';
import 'package:apps_transporte/core/widgets/custom_button.dart';
import 'package:apps_transporte/core/widgets/custom_text_field.dart';
import 'package:apps_transporte/data/datasources/api_config.dart';

class ConfiguracionScreen extends StatefulWidget {
  static const routeName = '/configuracion';

  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _baseUrlController = TextEditingController(
    text: ApiConfig.defaultBaseUrl,
  );
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracionActual();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _cargarConfiguracionActual() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrlGuardada = prefs.getString('base_url') ?? '';

    if (mounted) {
      setState(() {
        if (baseUrlGuardada.isNotEmpty) {
          _baseUrlController.text = baseUrlGuardada;
        }
      });
    }
  }

  Future<void> _guardarConfiguracion() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    final config = ApiConfig.fromBaseUrl(_baseUrlController.text);

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final changed =
          prefs.getString('base_url') != config.baseUrl ||
          prefs.getString('company_domain') != ApiConfig.companyDomain;
      if (changed) {
        await prefs.remove('id_usuario');
        await prefs.remove('id_terminal');
        await prefs.remove('is_logged_in');
      }
      await prefs.setString('company_domain', ApiConfig.companyDomain);
      await prefs.setString('base_url', config.baseUrl);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración guardada. Inicia sesión para probarla.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la configuración.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Configuración",
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.dns_outlined,
                        color: AppColors.accent,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Conexión de Servidor",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ingresa la URL HTTPS de la API de TID.',
                    style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                  ),
                  const SizedBox(height: 32),

                  // NUEVO INPUT: URL del servidor
                  CustomTextField(
                    controller: _baseUrlController,
                    label: 'URL del Servidor API',
                    hintText: ApiConfig.defaultBaseUrl,
                    prefixIcon: const Icon(
                      Icons.link,
                      color: AppColors.textGrey,
                    ),
                    keyboardType: TextInputType.url,
                    validator: (value) {
                      try {
                        ApiConfig.fromBaseUrl(value ?? '');
                        return null;
                      } on FormatException catch (e) {
                        return e.message;
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  const InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Empresa',
                      prefixIcon: Icon(
                        Icons.language,
                        color: AppColors.textGrey,
                      ),
                    ),
                    child: Text(ApiConfig.companyDomain),
                  ),
                  const SizedBox(height: 32),

                  CustomButton(
                    text: 'Guardar configuración',
                    onPressed: _guardarConfiguracion,
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
