<?php
require_once __DIR__ . '/config/api.php';

try {
    $data = tid_json();
    $filter = tid_text($data, 'filtro', false);
    $date = tid_date(tid_text($data + ['fecha' => date('Y-m-d')], 'fecha'));
    $nextDay = (new DateTimeImmutable($date))->modify('+1 day')->format('Y-m-d');
    $pdo = tid_db();
    $sql = "SELECT e.codigo AS traking, e.estado, e.fecha_salida, e.fecha_entrega,
            e.fotos_evidencia,
            CONCAT_WS(' ', u_des.nombres, u_des.apellidos) AS destinatario,
            u_des.num_docu AS documentoDes,
            CONCAT_WS(' ', u_rem.nombres, u_rem.apellidos) AS remitente,
            pe.producto, t_o.nombre AS origen, t_d.nombre AS destino
         FROM encomienda e
         INNER JOIN usuario u_des ON e.id_destinatario = u_des.id_usuario
         INNER JOIN usuario u_rem ON e.id_remitente = u_rem.id_usuario
         LEFT JOIN (
             SELECT id_encomienda, GROUP_CONCAT(descripcion SEPARATOR ', ') AS producto
             FROM producto_encomienda GROUP BY id_encomienda
         ) pe ON e.id_encomienda = pe.id_encomienda
         LEFT JOIN terminal t_o ON t_o.id_terminal = e.id_terminal_origen
         LEFT JOIN terminal t_d ON t_d.id_terminal = e.id_terminal_destino
         WHERE e.estado = 'ENTREGADO' AND e.fecha_entrega >= ? AND e.fecha_entrega < ?";
    $params = [$date, $nextDay];
    if ($filter !== '') {
        $sql .= " AND (e.codigo LIKE ? ESCAPE '!' OR u_des.num_docu LIKE ? ESCAPE '!')";
        $params[] = '%' . tid_like($filter) . '%';
        $params[] = '%' . tid_like($filter) . '%';
    }
    $stmt = $pdo->prepare($sql . ' ORDER BY e.fecha_entrega DESC LIMIT 50');
    $stmt->execute($params);
    tid_respond(['success' => true, 'data' => $stmt->fetchAll()]);
} catch (Throwable $error) {
    tid_error($error, 'get_historial.php');
}
