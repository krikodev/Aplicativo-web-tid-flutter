<?php
require_once __DIR__ . '/config/api.php';

try {
    $data = tid_json();
    $codigo = tid_text($data, 'codigo_tracking');
    if (!preg_match('/^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$/D', $codigo)) {
        tid_reject('El código de tracking no es válido para buscar imágenes.');
    }
    $images = [];
    $folder = __DIR__ . '/img/';
    if (is_dir($folder)) {
        $files = scandir($folder);
        if ($files === false) {
            throw new RuntimeException('No se pudo leer la carpeta de imágenes.');
        }
        foreach ($files as $file) {
            if (strpos($file, $codigo . '_') === 0 && is_file($folder . $file)
                && preg_match('/\.(jpe?g|png|webp)$/iD', $file)) {
                $images[] = ['nombre' => $file, 'url' => tid_public_base() . 'img/' . rawurlencode($file)];
            }
        }
    }
    tid_respond(['success' => true, 'imagenes' => $images]);
} catch (Throwable $error) {
    tid_error($error, 'get_imagenes.php');
}
