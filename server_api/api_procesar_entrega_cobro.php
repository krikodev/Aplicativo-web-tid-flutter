<?php
require_once __DIR__ . '/config/entregas.php';

try {
    $codigo = tid_tracking(tid_form_array('trackings'));
    $photos = tid_form_array('urls_fotos');
    if (count($photos) !== 2) {
        tid_reject('Se requieren exactamente dos fotos de evidencia.');
    }
    $photos = array_map('tid_evidence_url', $photos);
    if ($photos[0] === $photos[1]) {
        tid_reject('Las dos fotografías deben ser diferentes.');
    }
    $signature = tid_evidence_url(tid_text($_POST, 'url_firma', true, 2048));
    $idUsuario = filter_var(tid_text($_POST, 'id_usuario'), FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
    if ($idUsuario === false) {
        tid_reject('El usuario de la entrega no es válido.');
    }
    $paymentRaw = tid_text($_POST, 'id_medio_pago', false);
    $idMedioPago = $paymentRaw === '' ? null : filter_var($paymentRaw, FILTER_VALIDATE_INT);
    $discount = tid_cents(tid_text($_POST, 'descuento'), 'El descuento');
    $amount = tid_cents(tid_text($_POST, 'monto_cobrado'), 'El importe cobrado');

    $pdo = tid_db();
    $pdo->beginTransaction();
    $parcel = tid_parcel($pdo, $codigo, true);
    $collected = $parcel['pago'] === 'PAGO EN DESTINO';
    $idVenta = null;

    // Registrar el movimiento en la terminal destino, nunca en una terminal 0.
    $idTerminal = (int) $parcel['id_terminal_destino'];
    $stmt = $pdo->prepare('SELECT id_terminal FROM terminal WHERE id_terminal = ?');
    $stmt->execute([$idTerminal]);
    if ($idTerminal <= 0 || !$stmt->fetchColumn()) {
        tid_reject('La encomienda no tiene una terminal destino válida.', 409, 'invalid_terminal');
    }

    if ($collected) {
        $sale = tid_pending_sale($pdo, $parcel['id_encomienda'], true);
        $idVenta = (int) $sale['id_venta'];
        $gross = tid_cents($sale['total'], 'El total de la venta');
        if ($discount >= $gross) {
            tid_reject('El descuento debe ser menor que el importe pendiente.');
        }
        $net = $gross - $discount;
        if ($amount !== $net) {
            tid_reject('El importe enviado no coincide con la deuda y el descuento calculados.', 409, 'amount_mismatch');
        }
        if (!in_array($idMedioPago, [1, 2, 3], true)) {
            tid_reject('Selecciona EFECTIVO, YAPE o PLIN.');
        }
        $stmt = $pdo->prepare('SELECT id_medio_pago FROM medio_pago WHERE id_medio_pago = ? AND estado = 1 FOR UPDATE');
        $stmt->execute([$idMedioPago]);
        if (!$stmt->fetchColumn()) {
            tid_reject('El medio de pago no está activo.', 409, 'inactive_payment_method');
        }
        $stmt = $pdo->prepare(
            'SELECT id_caja_chica FROM caja_chica WHERE id_usuario = ? AND estado = 1
             ORDER BY id_caja_chica DESC LIMIT 1 FOR UPDATE'
        );
        $stmt->execute([$idUsuario]);
        $idCaja = $stmt->fetchColumn();
        if (!$idCaja) {
            tid_reject('Debes abrir una Caja Chica antes de cobrar.', 409, 'cashbox_closed');
        }
        $tax = tid_discounted_taxes($sale, $gross, $net);
        $previousDiscount = tid_cents($sale['descuento'] ?? '0', 'El descuento registrado');
        $stmt = $pdo->prepare(
            "UPDATE venta SET estado = 'PAGADO', id_forma_pago = 1, id_medio_pago = ?,
             id_caja_chica = ?, id_cobrador = ?, descuento = ?, op_gravada = ?, op_igv = ?,
             op_exonerada = ?, op_inafecta = ?, total = ?
             WHERE id_venta = ? AND estado = 'PENDIENTE' AND id_pago IS NULL"
        );
        $stmt->execute([
            $idMedioPago, $idCaja, $idUsuario, tid_decimal($previousDiscount + $discount),
            $tax['op_gravada'], $tax['op_igv'], $tax['op_exonerada'], $tax['op_inafecta'],
            tid_decimal($net), $idVenta
        ]);
        if ($stmt->rowCount() !== 1) {
            tid_reject('La venta cambió durante la entrega. Actualiza la información.', 409, 'sale_changed');
        }
        // Conservar el mecanismo actual de caja; no sumar saldo_final otra vez.
    } elseif ($amount !== 0 || $discount !== 0 || $idMedioPago !== null) {
        tid_reject('Esta modalidad se entrega sin cobro, descuento ni medio de pago.');
    }

    $evidence = implode(',', array_merge($photos, [$signature]));
    $stmt = $pdo->prepare(
        "UPDATE encomienda SET estado = 'ENTREGADO', pago = ?, fotos_evidencia = ?, fecha_entrega = NOW()
         WHERE id_encomienda = ? AND estado = 'EN DESTINO'"
    );
    $stmt->execute([$collected ? 'PAGADO' : $parcel['pago'], $evidence, $parcel['id_encomienda']]);
    if ($stmt->rowCount() !== 1) {
        tid_reject('La encomienda cambió durante la entrega.', 409, 'parcel_changed');
    }
    $stmt = $pdo->prepare(
        "INSERT INTO encomienda_movimiento
         (id_encomienda, tipo_movimiento, id_terminal_evento, observacion, id_usuario, fecha_registro)
         VALUES (?, 'ENTREGA', ?, ?, ?, NOW())"
    );
    $stmt->execute([
        $parcel['id_encomienda'], $idTerminal,
        $collected ? 'Entrega y cobro registrados desde la App Móvil.' : 'Entrega registrada desde la App Móvil sin cobro.',
        $idUsuario
    ]);
    $pdo->commit();
    tid_respond([
        'success' => true,
        'message' => $collected ? 'Entrega y cobro registrados correctamente.' : 'Entrega registrada correctamente sin cobro.',
        'cobro_realizado' => $collected,
        'monto_cobrado' => $amount / 100,
        'id_venta' => $idVenta
    ]);
} catch (Throwable $error) {
    if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    tid_error($error, 'api_procesar_entrega_cobro.php');
}
