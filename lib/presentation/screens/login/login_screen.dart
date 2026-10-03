import 'package:flutter/material.dart';
import 'package:apps_transporte/core/utils/assets.dart';
import 'package:apps_transporte/core/utils/app_colors.dart';
import 'package:apps_transporte/core/utils/validators.dart';
import 'package:apps_transporte/core/widgets/custom_button.dart';
import 'package:apps_transporte/core/widgets/custom_text_field.dart';
import 'package:apps_transporte/data/datasources/api_service.dart';
import 'package:apps_transporte/presentation/routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await ApiService.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pushReplacementNamed(context, AppRoutes.mainLayout);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Error de credenciales'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Fondo claro moderno
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 32.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // LOGO
                  Image.asset(Assets.logoSplash, width: 120, height: 120),
                  const SizedBox(height: 32),

                  // TARJETA DE LOGIN
                  Container(
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
                        const Text(
                          "TransPorta Pro",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Ingresa tus credenciales",
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textGrey,
                          ),
                        ),
                        const SizedBox(height: 32),

                        CustomTextField(
                          controller: _emailController,
                          label: 'Correo',
                          hintText: 'ejemplo@correo.com',
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            color: AppColors.textGrey,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.validateEmail,
                        ),
                        const SizedBox(height: 20),

                        CustomTextField(
                          controller: _passwordController,
                          label: 'Contraseña',
                          hintText: '••••••••',
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: AppColors.textGrey,
                          ),
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textGrey,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          validator: Validators.validatePassword,
                        ),
                        const SizedBox(height: 32),

                        CustomButton(
                          text: 'Ingresar',
                          onPressed: _submit,
                          isLoading: _isLoading,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // CONFIGURACIÓN TÉCNICA
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.configuracion),
                    icon: const Icon(
                      Icons.settings,
                      color: Colors.grey,
                      size: 16,
                    ),
                    label: const Text(
                      'Configurar Servidor',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
