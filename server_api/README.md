# Corregir la respuesta JSON de la búsqueda

La comprobación del 14 de octubre de 2026 con una búsqueda sintética que no
corresponde a un DNI devolvió HTTP 200 y este cuerpo:

```text
{"success":true,"data":[]}>
```

El carácter `>` después del objeto provoca el error de JSON de Flutter. En el
código proporcionado, el archivo termina con `?>>`: el primer `?>` cierra PHP
y el último `>` se envía como texto. La respuesta de una búsqueda vacía sí era
JSON válido porque esa rama ejecutaba `exit` antes de llegar al final del archivo.

El archivo corregido omite el cierre de PHP y termina la ejecución después de
enviar una respuesta. También evita que datos de texto con UTF-8 inválido hagan
fallar la serialización y registra las excepciones en el log de PHP.

## Instalar en el hosting

| Archivo de este repositorio | Archivo que debes reemplazar en el servidor |
| --- | --- |
| `server_api/get_encomiendas_dni.php` | `APIAppDom_Sigtrans/get_encomiendas_dni.php` |

Reemplaza únicamente ese archivo con su versión corregida, guardada en UTF-8
sin BOM. La ubicación física de la carpeta depende del hosting. El archivo
`config/conexion.php` sigue siendo el que ya existe en el servidor; no contiene
credenciales en este repositorio. Descargar la rama de Flutter no despliega
este PHP en el hosting.

En XAMPP puedes verificar la sintaxis antes de subirlo:

```powershell
C:\xampp\php\php.exe -l .\server_api\get_encomiendas_dni.php
```

## Comprobar después de reemplazarlo

Ejecuta en PowerShell una búsqueda con datos sintéticos:

```powershell
$headers = @{ 'X-Company-Domain' = 'tid.net.pe' }
$body = @{ dni = 'TIDDEBUGNOMATCH' } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri 'https://api-tid.net.pe/APIAppDom_Sigtrans/get_encomiendas_dni.php' -Headers $headers -ContentType 'application/json; charset=UTF-8' -Body $body
```

La respuesta debe ser un objeto con `success = True` y una lista `data` vacía
si no existe una coincidencia con ese prefijo. Después prueba la búsqueda en
el celular con un destinatario o tracking que tenga encomiendas elegibles.

Se mantienen las condiciones originales:

- Búsqueda desde tres caracteres por prefijo del DNI del destinatario o del
  código de tracking, con el mismo parámetro JSON `dni`.
- Estado `EN DESTINO`.
- Pago `PAGADO`, `PAGO EN BLOQUE`, `PAGO EN DESTINO` o `CREDITO`.
- Máximo de veinte resultados, conservando el orden y los nombres de campos.

Un objeto JSON válido con `data: []` indica que no hay coincidencias con estas
condiciones. Un HTTP 500 con `Error al buscar encomiendas` requiere consultar
el log de errores de PHP para ver la causa; no se muestra SQL ni información
interna de conexión en la app.
