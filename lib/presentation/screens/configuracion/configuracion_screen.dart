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
  String _companyDomain = ApiConfig.defaultCompanyDomain;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracionActual();
  }

  Future<void> _cargarConfiguracionActual() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDomain =
        prefs.getString('company_domain') ?? ApiConfig.defaultCompanyDomain;

    if (!mounted) return;

    setState(() {
      _companyDomain = ApiConfig.companies.containsKey(savedDomain)
          ? savedDomain
          : ApiConfig.defaultCompanyDomain;
    });
  }

  Future<void> _guardarConfiguracion() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    final config = ApiConfig.forCompanyDomain(_companyDomain);
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final changed =
          prefs.getString('company_domain') != config.companyDomain;

      // Si cambia de empresa, no reutilizar la sesión ni el usuario anterior.
      if (changed) {
        await prefs.remove('id_usuario');
        await prefs.remove('id_terminal');
        await prefs.remove('is_logged_in');
      }

      await prefs.setString('company_domain', config.companyDomain);

      // Elimina cualquier URL antigua guardada por versiones anteriores.
      await prefs.remove('base_url');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Empresa guardada. Inicia sesión para continuar.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la empresa.'),
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
          'Configuración',
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
                      Text(
                        'Conexión de empresa',
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
                    'La dirección de la API es fija. Selecciona la empresa '
                    'a la que pertenece tu usuario.',
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'URL fija de la API',
                      prefixIcon: Icon(
                        Icons.link,
                        color: AppColors.textGrey,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    child: SelectableText(
                      ApiConfig.defaultBaseUrl,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _companyDomain,
                    decoration: const InputDecoration(
                      labelText: 'Dominio de la empresa',
                      prefixIcon: Icon(
                        Icons.business_outlined,
                        color: AppColors.textGrey,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    items: ApiConfig.companies.entries
                        .map(
                          (entry) => DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(
                              '${entry.value} (${entry.key})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _companyDomain = value);
                            }
                          },
                    validator: (value) =>
                        value == null || !ApiConfig.companies.containsKey(value)
                            ? 'Selecciona una empresa válida.'
                            : null,
                  ),
                  const SizedBox(height: 28),
                  CustomButton(
                    text: 'Guardar empresa',
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
