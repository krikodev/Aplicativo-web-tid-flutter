<?php
require_once __DIR__ . '/api.php';

function tid_cents($value, $label)
{
    if (!is_string($value) && !is_int($value) && !is_float($value)) {
        tid_reject($label . ' no es válido.');
    }
    $raw = str_replace(',', '.', trim((string) $value));
    if (!preg_match('/^([0-9]{1,10})(?:\.([0-9]{1,2}))?$/D', $raw, $parts)) {
        tid_reject($label . ' debe ser positivo o cero y tener hasta dos decimales.');
    }
    return (int) $parts[1] * 100 + (int) str_pad($parts[2] ?? '', 2, '0');
}

function tid_decimal($cents)
{
    return number_format($cents / 100, 2, '.', '');
}

function tid_parcel(PDO $pdo, $codigo, $lock = false)
{
    $stmt = $pdo->prepare(
        'SELECT id_encomienda, codigo, estado, pago, id_terminal_destino
         FROM encomienda WHERE codigo = ?' . ($lock ? ' FOR UPDATE' : '')
    );
    $stmt->execute([$codigo]);
    $rows = $stmt->fetchAll();
    if (count($rows) === 0) {
        tid_reject('No se encontró la encomienda.', 404, 'parcel_not_found');
    }
    if (count($rows) !== 1) {
        tid_reject('El código identifica varias encomiendas. Requiere revisión.', 409, 'ambiguous_parcel');
    }
    $parcel = $rows[0];
    if ($parcel['estado'] !== 'EN DESTINO') {
        tid_reject('Solo se puede entregar una encomienda que está EN DESTINO.', 409, 'invalid_parcel_state');
    }
    if (!in_array($parcel['pago'], ['PAGADO', 'PAGO EN BLOQUE', 'PAGO EN DESTINO', 'CREDITO'], true)) {
        tid_reject('La modalidad de pago no está permitida en la entrega móvil.', 409, 'invalid_payment_mode');
    }
    return $parcel;
}

function tid_pending_sale(PDO $pdo, $idEncomienda, $lock = false)
{
    // IN evita duplicar una venta cuando dt_venta contiene varios detalles.
    $stmt = $pdo->prepare(
        "SELECT v.* FROM venta v
         WHERE v.id_venta IN (
             SELECT DISTINCT dv.id_venta FROM dt_venta dv WHERE dv.id_encomienda = ?
         ) AND v.estado = 'PENDIENTE' AND v.id_pago IS NULL" . ($lock ? ' FOR UPDATE' : '')
    );
    $stmt->execute([$idEncomienda]);
    $sales = $stmt->fetchAll();
    if (count($sales) !== 1) {
        tid_reject('No se encontró una única venta pendiente válida. Revisa la venta asociada.', 409, 'invalid_pending_sale');
    }
    $sale = $sales[0];
    $stmt = $pdo->prepare('SELECT DISTINCT id_encomienda FROM dt_venta WHERE id_venta = ?' . ($lock ? ' FOR UPDATE' : ''));
    $stmt->execute([$sale['id_venta']]);
    $parcelIds = $stmt->fetchAll(PDO::FETCH_COLUMN);
    if (count($parcelIds) !== 1 || (int) $parcelIds[0] !== (int) $idEncomienda) {
        tid_reject('La venta incluye varias encomiendas. Revisa el cobro en el sistema antes de entregar.', 409, 'shared_sale');
    }
    if (tid_cents($sale['total'], 'El total de la venta') <= 0) {
        tid_reject('La venta no tiene un importe pendiente válido.', 409, 'invalid_sale_total');
    }
    return $sale;
}

function tid_evidence_url($url)
{
    if (!is_string($url) || strlen($url) > 2048 || strpos($url, ',') !== false || !filter_var($url, FILTER_VALIDATE_URL)) {
        tid_reject('Una URL de evidencia no es válida.');
    }
    $parts = parse_url($url);
    if (($parts['scheme'] ?? '') !== 'https' || isset($parts['user']) || isset($parts['pass'])) {
        tid_reject('Las evidencias deben tener una URL HTTPS.');
    }
    return $url;
}

function tid_discounted_taxes(array $sale, $gross, $net)
{
    $values = [];
    foreach (['op_gravada', 'op_exonerada', 'op_inafecta', 'op_igv'] as $key) {
        $values[$key] = tid_cents($sale[$key] ?? null, 'El campo ' . $key);
    }
    if (array_sum($values) !== $gross) {
        tid_reject('Los importes de la venta no coinciden con su total. Requiere revisión.', 409, 'inconsistent_sale');
    }
    if ($gross !== $net) {
        foreach ($values as $key => $value) {
            $values[$key] = (int) round($value * ($net / $gross));
        }
        $residual = $net - array_sum($values);
        $target = $values['op_gravada'] > 0 || (float) $sale['op_gravada'] > 0
            ? 'op_igv'
            : ((float) $sale['op_exonerada'] > 0 ? 'op_exonerada' : 'op_inafecta');
        $values[$target] += $residual;
        if (min($values) < 0 || array_sum($values) !== $net) {
            tid_reject('No se pudo distribuir el descuento. Requiere revisión.', 409, 'invalid_discount');
        }
    }
    return array_map('tid_decimal', $values);
}
