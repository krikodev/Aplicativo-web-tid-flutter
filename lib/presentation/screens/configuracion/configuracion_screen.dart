import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apps_transporte/core/utils/app_colors.dart';
import 'package:apps_transporte/core/widgets/custom_button.dart';
import 'package:apps_transporte/core/widgets/custom_text_field.dart';

class ConfiguracionScreen extends StatefulWidget {
  static const routeName = '/configuracion';

  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final _dominioController = TextEditingController();
  final _baseUrlController =
      TextEditingController(); // NUEVO: Controlador para la URL
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracionActual();
  }

  @override
  void dispose() {
    _dominioController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _cargarConfiguracionActual() async {
    final prefs = await SharedPreferences.getInstance();
    final dominioGuardado = prefs.getString('company_domain') ?? '';
    final baseUrlGuardada = prefs.getString('base_url') ?? '';

    if (mounted) {
      setState(() {
        _dominioController.text = dominioGuardado;
        _baseUrlController.text = baseUrlGuardada;
      });
    }
  }

  Future<void> _guardarConfiguracion() async {
    final dominio = _dominioController.text.trim().toLowerCase();
    final baseUrl = _baseUrlController.text.trim();

    if (dominio.isEmpty || baseUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa ambos campos.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('company_domain', dominio);
    await prefs.setString(
      'base_url',
      baseUrl,
    ); // ESTO FALTABA, AHORA SÍ SE GUARDA

    setState(() => _isLoading = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configuración enlazada con éxito.'),
        backgroundColor: AppColors.success,
      ),
    );

    Navigator.pushReplacementNamed(context, '/login');
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
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.dns_outlined, color: AppColors.accent, size: 28),
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
                  "Configura la URL de tu API y el dominio de tu empresa.",
                  style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                ),
                const SizedBox(height: 32),

                // NUEVO INPUT: URL del servidor
                CustomTextField(
                  controller: _baseUrlController,
                  label: 'URL del Servidor API',
                  hintText: 'ej: http://192.168.1.20/apis/',
                  prefixIcon: const Icon(Icons.link, color: AppColors.textGrey),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),

                // INPUT ORIGINAL: Dominio
                CustomTextField(
                  controller: _dominioController,
                  label: 'Dominio',
                  hintText: 'ej: jrcargo.com.pe',
                  prefixIcon: const Icon(
                    Icons.language,
                    color: AppColors.textGrey,
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 32),

                CustomButton(
                  text: 'Guardar y Enlazar',
                  onPressed: _guardarConfiguracion,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
