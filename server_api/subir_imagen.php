<?php
require_once __DIR__ . '/config/api.php';

try {
    $codigo = tid_text($_POST, 'codigo_tracking');
    if (!preg_match('/^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$/D', $codigo)) {
        tid_reject('El código de tracking no es válido para guardar imágenes.');
    }
    $file = $_FILES['imagen'] ?? null;
    if (!is_array($file) || !isset($file['error']) || is_array($file['error']) || $file['error'] !== UPLOAD_ERR_OK) {
        tid_reject('No se recibió una imagen válida. Revisa el límite de subida del hosting.');
    }
    if ($file['size'] <= 0 || $file['size'] > 10 * 1024 * 1024 || !is_uploaded_file($file['tmp_name'])) {
        tid_reject('La imagen debe pesar como máximo 10 MB.');
    }
    $mime = (new finfo(FILEINFO_MIME_TYPE))->file($file['tmp_name']);
    $extensions = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'];
    if (!isset($extensions[$mime]) || getimagesize($file['tmp_name']) === false) {
        tid_reject('Solo se admiten imágenes JPEG, PNG o WebP.');
    }
    $folder = __DIR__ . '/img/';
    if (!is_dir($folder) && !mkdir($folder, 0755, true) && !is_dir($folder)) {
        throw new RuntimeException('No se pudo crear img/.');
    }
    $name = $codigo . '_' . bin2hex(random_bytes(12)) . '.' . $extensions[$mime];
    if (!move_uploaded_file($file['tmp_name'], $folder . $name)) {
        throw new RuntimeException('No se pudo guardar la imagen.');
    }
    tid_respond([
        'success' => true, 'mensaje' => 'Imagen subida correctamente.',
        'message' => 'Imagen subida correctamente.',
        'url' => tid_public_base() . 'img/' . rawurlencode($name), 'nombre_archivo' => $name
    ]);
} catch (Throwable $error) {
    tid_error($error, 'subir_imagen.php');
}
