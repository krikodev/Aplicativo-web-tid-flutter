# Archivos corregidos para la API TID

La app usa `https://api-tid.net.pe/APIAppDom_Sigtrans/` y envía
`X-Company-Domain: tid.net.pe`. Solo se admite esta empresa.

## Causa del error al continuar

`api_obtener_deuda.php` y la entrega adjunta abrían otra conexión con
`transporte`, `root` y contraseña vacía. La búsqueda sí utilizaba la conexión
del hosting. Ahora todos los PHP que consultan la base cargan el mismo
`config/conexion.php`. `localhost` es correcto si MySQL está en el propio
servidor; lo incorrecto era conservar las credenciales de XAMPP.

También se corrigen el carácter `>` fuera de PHP en la búsqueda, la `a`
suelta después de `e.fecha_entrega` en la consulta por tracking, las URLs
`10.0.2.2` de imágenes, los preflight OPTIONS y los errores SQL expuestos.
Los nombres de campos del cliente, incluido `traking`, se conservan.

## Instalar los PHP

1. Haz una copia de los archivos actuales del hosting.
2. Conserva **tu `APIAppDom_Sigtrans/config/conexion.php` que ya conecta** y
   `login_usuario.php`. Este paquete no contiene tus credenciales ni sustituye
   el login. `conexion.php` debe crear la variable PDO `$pdo` sin imprimir texto.
3. Copia el contenido de `APIAppDom_Sigtrans/` del ZIP en esa carpeta del
   hosting, manteniendo las subcarpetas `config/` e `img/`. En el repositorio,
   esos mismos archivos están en `server_api/`.
4. No subas `tests/`, `schema.sql` ni informes de prueba al directorio público.
   No importes el esquema sintético en la base oficial.
5. Guarda los PHP como UTF-8 sin BOM. No agregues `?>` al final.

**Primero sube los PHP a un entorno de pruebas con una copia de la base.**
Después comprueba el flujo con la app de esta rama antes de usarlo en producción.
La rama de GitHub no instala automáticamente los PHP en tu hosting.

| Archivo | Función y nombre en tu hosting |
| --- | --- |
| `config/api.php` | Nuevo: JSON, CORS, dominio TID y carga de tu conexión |
| `config/entregas.php` | Nuevo: validaciones comunes de deuda y cobro |
| `api_obtener_deuda.php` | Reemplazar con este nombre: lo llama Flutter |
| `api_procesar_entrega_cobro.php` | Reemplazar con este nombre: lo llama Flutter |
| `get_encomiendas_dni.php` | Reemplazar con este nombre: lo llama Flutter |
| `get_historial.php` | Reemplazar con este nombre: lo llama Flutter |
| `api_procesar_entrega.php` | Versión del PHP antiguo que solo actualizaba el estado |
| `get_encomienda_comprobante.php` | Consulta por serie, correlativo y fecha |
| `get_encomienda_tracking.php` | Consulta por `codigo_tracking` |
| `get_imagenes.php` | Lista los archivos antiguos de `img/` con URL HTTPS |
| `subir_imagen.php` | Subida antigua a `img/`, con validación y nombres únicos |
| `img/.htaccess` | Para Apache: desactiva listado y acceso a scripts en esta carpeta |

Los cinco últimos endpoints de consulta/subida/entrega antigua llegaron sin
nombre de archivo. Los nombres de esta tabla son descriptivos: si en tu hosting
se llaman distinto, copia su contenido sobre el nombre original que llame tu
cliente. La app Flutter actual llama únicamente a los cuatro endpoints marcados,
al login y a Cloudinary para subir fotos y firma. `get_imagenes.php` lista las
fotos de `img/`; las de Cloudinary se consultan mediante `fotos_evidencia` en el
historial. No se migra ni borra ninguna imagen existente.

`config/conexion.php.example` es un ejemplo opcional con variables de entorno,
por si necesitas reconstruir la conexión. **No hace falta usarlo cuando tu
conexión actual ya funciona.** No lo renombres sin configurar las variables.
PHP 7.4+ y extensiones `pdo_mysql` y `fileinfo`; las pruebas se ejecutaron en
PHP 8.3.6 y MariaDB 10.11.14. Para atomicidad, las tablas modificadas deben ser
InnoDB. Los nombres de columnas se basan en los PHP que proporcionaste; no se
inspeccionó la base oficial ni sus triggers.

## Comportamiento de la entrega

- Una encomienda por operación, únicamente en estado `EN DESTINO`.
- `PAGADO`, `PAGO EN BLOQUE` y `CREDITO`: entrega sin cobro, conservando modalidad.
- `PAGO EN DESTINO`: requiere una única venta `PENDIENTE` con `id_pago IS NULL`,
  medio de pago activo y caja chica abierta del usuario recibido.
- Si la venta agrupa varias encomiendas se bloquea el cobro móvil para revisión;
  cobrar el total de esa venta al seleccionar solo un paquete sería ambiguo.
- Dos fotos distintas y firma, con URLs HTTPS. Se guardan las tres URLs en
  `fotos_evidencia`, separadas por comas, como espera el historial actual.
- El servidor recalcula el importe en centavos. `venta.total` se trata como el
  saldo actual; el nuevo descuento se resta una vez y se acumula a `descuento`.
  Se conserva la distribución proporcional de los importes de la versión adjunta,
  comprobando que sumen el total. No se inserta una venta nueva ni se suma
  manualmente `caja_chica.saldo_final`.
- Venta, encomienda y movimiento se guardan en una transacción. El movimiento
  utiliza `id_terminal_destino`, en lugar del valor fijo `0` del archivo adjunto.
  Un fallo revierte todo. Una segunda entrega del mismo código se rechaza.
- El endpoint antiguo de entrega delega en la entrega completa y exige sus
  campos; debe retirarse cualquier otra copia que permita saltarse el cobro.

La app permite seleccionar un solo paquete, acepta tracking alfanumérico y
mantiene la pantalla de cobro cuando hay un error, con opción de volver a
consultar. Una respuesta de deuda incompleta nunca se interpreta como importe
cero. Si una entrega agota el tiempo de espera, consulta el historial antes de
repetirla: la transacción podría haberse confirmado en el servidor.

## Comprobación en el hosting

Una consulta sintética no modifica registros:

```powershell
$headers = @{ 'X-Company-Domain' = 'tid.net.pe' }
$body = @{ dni = 'TIDDEBUGNOMATCH' } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri 'https://api-tid.net.pe/APIAppDom_Sigtrans/get_encomiendas_dni.php' -Headers $headers -ContentType 'application/json; charset=UTF-8' -Body $body
```

Debe devolver JSON sin texto sobrante y `data: []` si no hay coincidencias.
En la copia de pruebas comprueba una entrega pagada, otra con cobro y descuento,
caja cerrada y un segundo intento de entrega. Revisa venta, fotos, firma,
movimiento y el reporte de caja del sistema. Los IDs `1/2/3` para
EFECTIVO/YAPE/PLIN y `id_forma_pago = 1` se conservan del cliente y del PHP
adjunto; confirma que esa correspondencia sea la de tu base oficial.

## Ejecutar las pruebas locales

Las pruebas crean una base temporal `tid_test_*`, usan datos ficticios y eliminan
solo esa base al terminar. Se rechazan hosts remotos y DSN con una base existente.
Requieren Python 3.9+, PHP CLI con `pdo_mysql`/`fileinfo` y MySQL/MariaDB local.
El usuario local de pruebas necesita permisos para crear y eliminar esa base.

```bash
export TID_TEST_DSN='mysql:host=127.0.0.1;port=3306'
export TID_TEST_USER='usuario_local_de_pruebas'
export TID_TEST_PASSWORD='clave_local_de_pruebas'
python3 server_api/tests/integration_test.py
flutter test
```

Se prueban consultas reales, cobro y descuento, modalidades sin cobro,
redondeos, caja cerrada, importe alterado, ventas ambiguas, fallos con rollback,
entregas concurrentes, historial e imágenes. Los detalles técnicos de errores
quedan en el log PHP y el cliente recibe JSON con `success`, `message` y `error`.

## Alcance pendiente de verificar

Las pruebas no acceden ni modifican tus registros oficiales. Falta validar en
el hosting real su esquema, triggers y reporte de caja y completar la prueba
en el celular antes de integrar a `main`. El login no fue proporcionado para
esta revisión: el dominio y el `id_usuario` enviados por el cliente no acreditan
una sesión. La autorización de entregas y descuentos debe comprobarse en el
servidor con la sesión o token que emita ese login.
