# Conectar la aplicación Flutter a la API de TID

| Configuración | Valor |
| --- | --- |
| URL base | `https://api-tid.net.pe/APIAppDom_Sigtrans/` |
| Empresa | `tid.net.pe` |
| Encabezado en cada petición | `X-Company-Domain: tid.net.pe` |
| Login | `POST https://api-tid.net.pe/APIAppDom_Sigtrans/login_usuario.php` |
| Datos del login | Formulario con `email` y `pass` |

La app usa la URL base para contactar al servidor. El PHP usa el encabezado
`X-Company-Domain` para seleccionar la configuración de TID. Son valores
distintos: no se debe enviar `api-tid.net.pe` ni una URL completa como empresa.

## Diagnóstico de la captura

`Failed host lookup: api-tid.net.pe` significa que el celular no pudo resolver
el nombre del servidor a una dirección IP. En esa petición todavía no se había
ejecutado `login_usuario.php` ni la conexión a MySQL. El mensaje por sí solo no
permite distinguir entre un problema del DNS del teléfono, su red o el DNS
público del dominio.

En la comprobación del 14 de octubre de 2026, el DNS público de Google devolvió
un registro A para `api-tid.net.pe`. La ruta `login_usuario.php` fue accesible
por HTTPS, con validación normal de certificados:

| Petición de lectura, sin credenciales | Respuesta observada |
| --- | --- |
| GET sin `X-Company-Domain` | HTTP 200: `success: false`, dominio no detectado |
| GET con `X-Company-Domain: tid.net.pe` | HTTP 400: `success: false`, `Datos incompletos` |

Estas comprobaciones confirman la accesibilidad de la ruta y que reconoce el
encabezado. No prueban un login válido ni operaciones de entrega o cobro.

Además, el repositorio original tenía permiso de Internet en los manifiestos
de `debug` y `profile`, pero no en `android/app/src/main/AndroidManifest.xml`.
Esta rama añade el permiso al manifiesto principal para incluirlo en el APK
de producción.

## Probar desde el celular

1. Abre en Chrome del mismo celular
   `https://api-tid.net.pe/APIAppDom_Sigtrans/login_usuario.php`.
   Una respuesta JSON que diga que no se detectó el dominio es esperable:
   Chrome no envía el encabezado de empresa de la app.
2. Si Chrome tampoco abre la URL, repite con datos móviles y con Wi-Fi.
   Si funciona en una red y falla en la otra, revisa el DNS de esa red. Si
   configuraste un DNS privado o una VPN, prueba temporalmente con DNS
   automático y sin la VPN, y después restablece tu configuración habitual.
3. En la aplicación, abre **Configurar Servidor**, ingresa la URL base de la
   tabla y guarda. La empresa se muestra fija como `tid.net.pe`.
4. Cierra completamente y vuelve a abrir la aplicación, y prueba el login.
   Si sigue apareciendo el error DNS, compara con la prueba de Chrome en esa
   misma red. Los ajustes de Flutter no crean registros DNS en el hosting.

## Verificar desde Windows

En PowerShell:

```powershell
nslookup api-tid.net.pe
nslookup api-tid.net.pe 8.8.8.8
curl.exe -i -H "X-Company-Domain: tid.net.pe" "https://api-tid.net.pe/APIAppDom_Sigtrans/login_usuario.php"
```

El último comando no envía usuario ni contraseña; un HTTP 400 con
`Datos incompletos` confirma que se llegó a ese endpoint y que pasó la
comprobación del encabezado. No reemplaces la URL por una IP ni desactives la
validación HTTPS para resolver un error DNS.

## Cambios de esta rama

- Dominio de empresa fijo para TID en todas las peticiones a la API PHP.
- URL HTTPS validada y barra final normalizada, conservando la carpeta
  `APIAppDom_Sigtrans`.
- Errores diferenciados para DNS, conexión, certificado, tiempo de espera,
  estado HTTP y respuestas vacías o que no son objetos JSON.
- Compatibilidad con respuestas PHP que usan `error` o `message`.
- El login guarda los datos del usuario sólo tras una respuesta HTTP válida
  con `success: true` e ID de usuario; elimina un terminal anterior si la API
  no devuelve uno nuevo.
- Las consultas y las entregas conservan los nombres de los endpoints y
  campos existentes. No se reintenta automáticamente una entrega o un cobro.
- Cambiar la configuración elimina los IDs de la sesión anterior.

Si MySQL está en el mismo servidor que ejecuta PHP, `host = localhost` es
correcto: se refiere al servidor PHP, no al celular. Si la base de datos está
en otro servidor, usa el host indicado por el proveedor. No publiques las
contraseñas de la base de datos en este repositorio.

## Compilar y validar

En tu carpeta del proyecto:

```powershell
git fetch origin
git switch --track origin/fix/tid-api-production-connection
flutter pub get
flutter test
flutter run
```

Si ya tienes la rama local, usa `git switch fix/tid-api-production-connection`.
Para generar el APK de producción con el permiso corregido:

```powershell
flutter build apk --release
```

Instala el APK generado y vuelve a comprobar la configuración antes del login.
Las pruebas automatizadas usan respuestas simuladas; no registran entregas,
no cobran y no usan credenciales reales.
