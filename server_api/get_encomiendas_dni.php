<?php
require_once __DIR__ . '/config/api.php';

try {
    $data = tid_json();
    $termino = tid_text($data, 'dni');
    if (strlen($termino) < 3) {
        tid_respond(['success' => true, 'data' => []]);
    }
    $pdo = tid_db();
    $stmt = $pdo->prepare(
        "SELECT e.codigo AS traking, e.estado, e.pago AS estado_pago,
            CONCAT_WS(' ', u_des.nombres, u_des.apellidos) AS destinatario,
            CONCAT_WS(' ', u_rem.nombres, u_rem.apellidos) AS remitente,
            e.fecha_registro
         FROM encomienda e
         INNER JOIN usuario u_des ON e.id_destinatario = u_des.id_usuario
         INNER JOIN usuario u_rem ON e.id_remitente = u_rem.id_usuario
         WHERE (u_des.num_docu LIKE ? ESCAPE '!' OR e.codigo LIKE ? ESCAPE '!')
           AND e.estado = 'EN DESTINO'
           AND e.pago IN ('PAGADO', 'PAGO EN BLOQUE', 'PAGO EN DESTINO', 'CREDITO')
         ORDER BY (DATE(e.fecha_registro) = CURDATE()) DESC, e.fecha_registro DESC
         LIMIT 20"
    );
    $prefix = tid_like($termino) . '%';
    $stmt->execute([$prefix, $prefix]);
    tid_respond(['success' => true, 'data' => $stmt->fetchAll()]);
} catch (Throwable $error) {
    tid_error($error, 'get_encomiendas_dni.php');
}
