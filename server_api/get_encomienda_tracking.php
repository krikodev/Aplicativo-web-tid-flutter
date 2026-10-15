<?php
require_once __DIR__ . '/config/api.php';

try {
    $data = tid_json();
    $codigo = tid_text($data, 'codigo_tracking');
    $pdo = tid_db();
    $stmt = $pdo->prepare(
        "SELECT
            CONCAT_WS(' ', u_rem.nombres, u_rem.apellidos) AS remitente,
            u_rem.num_docu AS documentoRem,
            CONCAT_WS(' ', u_des.nombres, u_des.apellidos) AS destinatario,
            u_des.num_docu AS documentoDes,
            tv.nombre AS terminal, t_o.nombre AS origen, t_d.nombre AS destino,
            e.fecha_salida, v.fecha_registro, e.fecha_entrega, e.estado,
            pe.descripcion AS producto, pe.obs AS observacion, e.codigo AS traking
         FROM encomienda e
         LEFT JOIN venta v ON v.id_venta = (
             SELECT MAX(dv.id_venta) FROM dt_venta dv WHERE dv.id_encomienda = e.id_encomienda
         )
         INNER JOIN usuario u_rem ON e.id_remitente = u_rem.id_usuario
         INNER JOIN usuario u_des ON e.id_destinatario = u_des.id_usuario
         LEFT JOIN terminal tv ON v.id_terminal = tv.id_terminal
         LEFT JOIN terminal t_o ON t_o.id_terminal = e.id_terminal_origen
         LEFT JOIN terminal t_d ON t_d.id_terminal = e.id_terminal_destino
         LEFT JOIN producto_encomienda pe ON e.id_encomienda = pe.id_encomienda
         WHERE e.codigo = ? LIMIT 100"
    );
    $stmt->execute([$codigo]);
    $rows = $stmt->fetchAll();
    tid_respond(['success' => count($rows) > 0, 'data' => $rows,
        'message' => count($rows) > 0 ? 'Consulta correcta.' : 'No se encontró encomienda con ese código.']);
} catch (Throwable $error) {
    tid_error($error, 'get_encomienda_tracking.php');
}
