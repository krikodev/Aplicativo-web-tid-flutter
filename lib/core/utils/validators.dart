class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu correo electrónico';
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(value)) {
      return 'Por favor ingresa un correo electrónico válido';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu contraseña';
    }
    return null;
  }

  // Validador para la IP/Ruta del servidor
  static String? validateServerUrl(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa la ruta del API';
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      return 'La ruta debe empezar con http:// o https://';
    }
    return null;
  }
}
