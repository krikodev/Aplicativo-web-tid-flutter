import 'package:apps_transporte/presentation/screens/configuracion/configuracion_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Configuración inicial pide dominio, no una URL editable', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ConfiguracionScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Dominio'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    final input = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(input.controller?.text, isEmpty);
  });

  testWidgets('Dominio no autorizado impide continuar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ConfiguracionScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'empresa-incorrecta.pe');
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Dominio no válido.'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('company_domain'), false);
  });

  testWidgets('Configurar empresa borra la sesión anterior', (tester) async {
    SharedPreferences.setMockInitialValues({
      'base_url': 'https://old-server.example/api/',
      'company_domain': 'tid.net.pe',
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
      'laranaexpress.com.pe',
    );
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('company_domain'), 'laranaexpress.com.pe');
    expect(prefs.containsKey('base_url'), false);
    expect(prefs.containsKey('id_usuario'), false);
    expect(prefs.containsKey('id_terminal'), false);
    expect(prefs.containsKey('is_logged_in'), false);
    expect(find.text('Login de prueba'), findsOneWidget);
  });
}
