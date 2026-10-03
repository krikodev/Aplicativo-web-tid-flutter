# Flutter — conexión con API v1 multiempresa

Rama `codex/login-api-multiempresa`. Requiere el backend de consulta de la rama `codex/api-multiempresa-local` en `krikodev/TID---DESARROLLO`, carpeta `mobile-api/`. Sigue primero el README de esa carpeta para iniciar MySQL, generar configuración privada y arrancar PHP.

## Ejecutar localmente

```powershell
git clone --branch codex/login-api-multiempresa https://github.com/krikodev/Aplicativo-web-tid-flutter.git
cd Aplicativo-web-tid-flutter
flutter pub get
flutter run
```

El proyecto requiere Dart 3.10.3 o superior dentro del rango 3.x. Validación del cambio: Flutter 3.38.5 / Dart 3.10.4.

En la pantalla Configuración:

| Entorno | URL del servidor API | Dominio de empresa |
|---|---|---|
| Emulador Android oficial | `http://10.0.2.2:8080/` | `tid.net.pe` |
| Teléfono físico | `http://IP_DE_TU_PC:8080/` | `tid.net.pe` |
| Flutter web | `http://localhost:8080/` | `tid.net.pe` |
| Windows local | `http://127.0.0.1:8080/` | `tid.net.pe` |

El dominio selecciona una empresa registrada en el servidor; no es la URL del backend. La URL debe apuntar a la API nueva, no a la antigua carpeta `apis/` ni a la portada del sistema general. Para Apache puedes usar `http://IP/TID---DESARROLLO/mobile-api/public/` si sus reglas de rewrite están habilitadas.

Para web usa `flutter run -d chrome --web-port 5173` y permite `http://localhost:5173` en `allowed_origins` del backend. La app comprueba health, versión, empresa y esquema antes de guardar. Si falla, conserva la configuración previa.

El teléfono debe compartir Wi-Fi con la PC. `localhost` en el teléfono es el propio teléfono. Usa `ipconfig` y permite el puerto 8080 en el firewall de Windows de la red privada. Mantén abierta la consola que ejecuta PHP.

## Iniciar sesión

Usa correo y contraseña de un usuario interno activo del sistema general, asignado a una terminal. La contraseña se manda tal como la ingresas: no elimina espacios ni exige la longitud de una contraseña nueva. Si el sistema utiliza claves AES distintas en otra instalación, configúralas en el backend de esa empresa.

La sesión se guarda **en memoria**, sin contraseñas ni tokens en SharedPreferences. Cada consulta envía Bearer y dominio. El token vence en 8 horas por defecto; un 401 cierra la sesión y vuelve al login. Al reiniciar por completo la app debes volver a iniciar sesión; el servidor/empresa permanece configurado. Perfil permite cerrar sesión o cambiar servidor/empresa.

## Cambios

- Cliente único de API v1 con timeout de 15 segundos, JSON, errores HTTP del servidor, diagnóstico de respuestas HTML y redirecciones deshabilitadas.
- Validación de URL, puerto, ruta y dominio; comprobación real de servidor antes de guardar.
- Tokens vinculados al servidor y empresa elegidos. No envía tokens de una empresa a otra.
- Navegación protegida, manejo de widgets desmontados y retirada del flag antiguo `is_logged_in`.
- Permiso Internet en Android; HTTP solo en debug y HTTPS requerido en release.
- Consulta por DNI, historial, tracking, comprobante, URLs existentes de evidencia y resumen del servidor. Dashboard ya no muestra cifras ni entregas inventadas.
- Mensajes de error de historial visibles, sin convertir un error de servidor en una lista vacía sin explicación.
- Pruebas del cliente y prueba de la pantalla de configuración; reemplaza el test de contador que no correspondía a esta app.

## Alcance de solo consulta

La API no modifica datos del sistema general. El cliente no sube fotos a Cloudinary ni llama a endpoints de entrega. Si seleccionas paquetes, explica que el registro de la entrega corresponde al sistema general. Los endpoints de escritura antiguos no forman parte de esta integración.

Por defecto las listas muestran la primera página de hasta 50 resultados. La API ofrece paginación hasta 100 por página; una UI para recorrer páginas puede agregarse cuando se requiera. Los resultados se restringen a la terminal según la configuración del backend.

El resumen incluye entregados del día y pendientes actuales con pago autorizado en destino. No representa métricas individuales de un conductor ni una tasa de efectividad de ruta.

## Pruebas

```powershell
flutter test
flutter analyze --no-fatal-infos
```

Las pruebas mock no necesitan MySQL. El flujo real debe verificarse en tu PC con el health del backend y una cuenta interna local. No se generaron usuarios reales ni se desplegó ningún dominio.

La revisión estática no reportó errores ni advertencias. Permanecen avisos informativos de estilo y APIs de color deprecadas en vistas heredadas.
