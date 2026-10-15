<?php
require_once __DIR__ . '/config/entregas.php';

try {
    $data = tid_json();
    $codigo = tid_tracking($data['trackings'] ?? null);
    $pdo = tid_db();
    $parcel = tid_parcel($pdo, $codigo);
    $requiresPayment = $parcel['pago'] === 'PAGO EN DESTINO';
    $response = [
        'success' => true,
        'deuda_total' => 0.0,
        'requiere_cobro' => $requiresPayment,
        'estado_pago' => $parcel['pago'],
        'estado_encomienda' => $parcel['estado'],
        'detalles' => []
    ];
    if ($requiresPayment) {
        $sale = tid_pending_sale($pdo, $parcel['id_encomienda']);
        $gross = tid_cents($sale['total'], 'El total de la venta');
        $response['deuda_total'] = $gross / 100;
        $response['id_venta'] = (int) $sale['id_venta'];
        // total es el saldo actual de la venta; no descontar dos veces.
        $response['descuento'] = (float) ($sale['descuento'] ?? 0);
        $response['detalles'][] = [
            'codigo' => $parcel['codigo'],
            'id_venta' => (int) $sale['id_venta'],
            'total_bruto' => $gross / 100,
            'estado_venta' => $sale['estado']
        ];
    }
    tid_respond($response);
} catch (Throwable $error) {
    tid_error($error, 'api_obtener_deuda.php');
}
