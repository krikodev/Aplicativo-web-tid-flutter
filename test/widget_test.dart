import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apps_transporte/main.dart';
import 'package:apps_transporte/presentation/routes/app_routes.dart';

void main() {
  testWidgets('Muestra configuración cuando no hay servidor configurado', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    initialRoute = AppRoutes.configuracion;
    await tester.pumpWidget(const TransPortaProApp());
    await tester.pumpAndSettle();
    expect(find.text('URL del Servidor API'), findsOneWidget);
    expect(find.text('Guardar y Enlazar'), findsOneWidget);
  });
}
