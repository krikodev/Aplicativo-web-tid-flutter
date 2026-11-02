import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apps_transporte/core/utils/app_colors.dart';
import 'package:apps_transporte/core/widgets/custom_button.dart';
import 'package:apps_transporte/data/datasources/api_config.dart';

class ConfiguracionScreen extends StatefulWidget {
  static const routeName = '/configuracion';

  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _domainController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracionInicial();
  }

  @override
  void dispose() {
    _domainController.dispose();
    super.dispose();
  }

  Future<void> _cargarConfiguracionInicial() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDomain = prefs.getString('company_domain');

    if (!mounted) return;

    // En una instalación nueva el dominio debe ingresarse manualmente.
    if (savedDomain != null && ApiConfig.companies.containsKey(savedDomain)) {
      _domainController.text = savedDomain;
    }
  }

  String? _validarDominio(String? value) {
    try {
      ApiConfig.forCompanyDomain(value ?? '');
      return null;
    } on FormatException {
      return 'Dominio no válido.';
    }
  }

  Future<void> _guardarConfiguracion() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    final config = ApiConfig.forCompanyDomain(_domainController.text);

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // Esta pantalla es de configuración inicial del dispositivo.
      // Siempre elimina cualquier sesión anterior antes de asociarlo a una empresa.
      await prefs.remove('id_usuario');
      await prefs.remove('id_terminal');
      await prefs.remove('is_logged_in');

      await prefs.setString('company_domain', config.companyDomain);

      // Elimina URL editables guardadas por versiones antiguas.
      await prefs.remove('base_url');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Empresa configurada. Inicia sesión con tu usuario.'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pushReplacementNamed(context, '/login');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la configuración inicial.'),
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
          'Configurar empresa',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                      Expanded(
                        child: Text(
                          'Dominio de empresa',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _domainController,
                    keyboardType: TextInputType.url,
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Dominio',
                      hintText: 'tid.net.pe',
                      prefixIcon: Icon(
                        Icons.business_outlined,
                        color: AppColors.textGrey,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    validator: _validarDominio,
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'Guardar',
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
