import 'package:apps_transporte/data/datasources/api_config.dart';
import 'package:apps_transporte/presentation/screens/configuracion/configuracion_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('La configuración muestra la URL de TID y la empresa fija', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ConfiguracionScreen()));
    await tester.pumpAndSettle();
    final input = tester.widget<EditableText>(find.byType(EditableText));
    expect(input.controller.text, ApiConfig.defaultBaseUrl);
    expect(find.text('tid.net.pe'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
  });

  testWidgets('Una URL inválida no se guarda ni navega al login', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ConfiguracionScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'invalid-url');
    await tester.ensureVisible(find.text('Guardar configuración'));
    await tester.tap(find.text('Guardar configuración'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Ingresa una URL HTTPS completa'),
      findsOneWidget,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('base_url'), false);
  });

  testWidgets('Cambiar de servidor elimina la sesión anterior', (tester) async {
    SharedPreferences.setMockInitialValues({
      'base_url': 'https://old-server.example/api/',
      'company_domain': 'old-company.example',
      'id_usuario': '42',
      'id_terminal': '3',
      'is_logged_in': true,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: const ConfiguracionScreen(),
        routes: {
          '/login': (_) => const Scaffold(body: Text('Login de prueba')),
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      ApiConfig.defaultBaseUrl,
    );
    await tester.ensureVisible(find.text('Guardar configuración'));
    await tester.tap(find.text('Guardar configuración'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('base_url'), ApiConfig.defaultBaseUrl);
    expect(prefs.getString('company_domain'), 'tid.net.pe');
    expect(prefs.containsKey('id_usuario'), false);
    expect(prefs.containsKey('id_terminal'), false);
    expect(prefs.containsKey('is_logged_in'), false);
    expect(find.text('Login de prueba'), findsOneWidget);
  });
}
