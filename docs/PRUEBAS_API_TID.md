# Verificación de la API y la app TID

Fecha: 15 de octubre de 2026. Rama: `fix/tid-api-production-connection`.

| Comprobación | Resultado |
| --- | --- |
| Sintaxis de 11 PHP y del ejemplo de conexión | Correcta |
| Integración HTTP con PHP 8.3.6 y MariaDB 10.11.14/InnoDB | 20 pruebas aprobadas |
| Flutter 3.41.1, dependencias del lockfile existente | 45 pruebas aprobadas |
| Análisis de servicios, pantallas modificadas de inicio/cobro, configuración, login y pruebas | Sin incidencias |
| `git diff --check` | Correcto |

La integración ejecuta los PHP reales con datos sintéticos en una base local
temporal. Verifica búsqueda por DNI/tracking, consultas por comprobante y
tracking, deuda, entregas con y sin cobro, medios de pago, descuento y redondeo,
caja cerrada, ventas compartidas o ambiguas, importe alterado, estados no
entregables, evidencias, historial y subida de imágenes.

Dos solicitudes simultáneas a una misma encomienda producen una entrega
confirmada y un rechazo, con un solo movimiento. Un trigger de prueba que
impide insertar el movimiento revierte también la actualización de venta y
encomienda. El cliente no recibe el texto del error SQL.

Las pruebas de Flutter comprueban que una deuda recibida como texto numérico
se normalice, que datos incompletos no autoricen una entrega sin cobro, que
un error de conexión mantenga la vista con opción de volver a consultar y
que solo se seleccione una encomienda. Las peticiones HTTP y subidas de
Cloudinary en estas pruebas del cliente están simuladas.

No se ejecutaron entregas, cobros ni subidas contra el servidor oficial.
La base de pruebas reproduce únicamente las columnas aportadas; no certifica
el esquema ni los triggers del hosting. Quedan pendientes la instalación
en el entorno de pruebas, el control de autorización del login, la validación
del reporte de caja y la comprobación del flujo completo en el celular.
El PR debe seguir en borrador hasta revisar esas pruebas antes de `main`.
