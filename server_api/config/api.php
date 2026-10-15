<?php
// PHP 7.4 o superior. Guardar sin BOM y sin etiqueta de cierre.
ini_set('display_errors', '0');
date_default_timezone_set('America/Lima');
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Company-Domain');

class TidApiException extends RuntimeException
{
    public $httpStatus;
    public $errorCode;

    public function __construct($message, $httpStatus = 400, $errorCode = 'invalid_request')
    {
        parent::__construct($message);
        $this->httpStatus = $httpStatus;
        $this->errorCode = $errorCode;
    }
}

function tid_respond(array $body, $status = 200)
{
    http_response_code($status);
    echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}

function tid_reject($message, $status = 400, $code = 'invalid_request')
{
    throw new TidApiException($message, $status, $code);
}

function tid_error(Throwable $error, $context)
{
    error_log($context . ': ' . $error->getMessage());
    $expected = $error instanceof TidApiException;
    $message = $expected ? $error->getMessage() : 'Error interno del servidor. Revisa el log de PHP.';
    tid_respond([
        'success' => false,
        'message' => $message,
        'error' => $message,
        'error_code' => $expected ? $error->errorCode : 'server_error'
    ], $expected ? $error->httpStatus : 500);
}

function tid_text(array $data, $key, $required = true, $maxLength = 120)
{
    $value = $data[$key] ?? '';
    if (!is_string($value) && !is_int($value)) {
        tid_reject('El campo ' . $key . ' no es válido.');
    }
    $value = trim((string) $value);
    if (($required && $value === '') || strlen($value) > $maxLength) {
        tid_reject('El campo ' . $key . ' está vacío o es demasiado largo.');
    }
    return $value;
}

function tid_json()
{
    $raw = file_get_contents('php://input');
    if ($raw === false || strlen($raw) > 65536) {
        tid_reject('El cuerpo de la solicitud no es válido.');
    }
    try {
        $data = json_decode($raw, false, 32, JSON_THROW_ON_ERROR);
    } catch (JsonException $error) {
        tid_reject('El cuerpo debe ser JSON válido.');
    }
    if (!is_object($data)) {
        tid_reject('Se requiere un objeto JSON.');
    }
    return (array) $data;
}

function tid_form_array($key)
{
    $raw = tid_text($_POST, $key, true, 16384);
    try {
        $value = json_decode($raw, false, 16, JSON_THROW_ON_ERROR);
    } catch (JsonException $error) {
        tid_reject('El campo ' . $key . ' debe contener una lista JSON.');
    }
    if (!is_array($value)) {
        tid_reject('El campo ' . $key . ' debe ser una lista.');
    }
    return $value;
}

function tid_tracking($trackings)
{
    if (!is_array($trackings) || count($trackings) !== 1 || !array_key_exists(0, $trackings)) {
        tid_reject('Debes consultar una sola encomienda por vez.');
    }
    return tid_text(['codigo' => $trackings[0]], 'codigo');
}

function tid_date($value)
{
    $date = DateTimeImmutable::createFromFormat('!Y-m-d', $value);
    if (!$date || $date->format('Y-m-d') !== $value) {
        tid_reject('La fecha debe ser válida y tener el formato AAAA-MM-DD.');
    }
    return $value;
}

function tid_like($value)
{
    // El usuario busca texto literal; % y _ no amplían la consulta.
    return str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $value);
}

function tid_db()
{
    // Se usa la MISMA conexión que ya funciona para el login y la búsqueda.
    // No colocar otra vez transporte/root en cada endpoint.
    $pdo = null;
    require __DIR__ . '/conexion.php';
    if (!$pdo instanceof PDO) {
        throw new RuntimeException('config/conexion.php no creó la variable $pdo.');
    }
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
    $pdo->setAttribute(PDO::ATTR_EMULATE_PREPARES, false);
    $pdo->exec("SET time_zone = '-05:00'");
    return $pdo;
}

function tid_public_base()
{
    // No construir URLs a partir de un Host recibido del cliente.
    return 'https://api-tid.net.pe/APIAppDom_Sigtrans/';
}

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        header('Allow: POST, OPTIONS');
        tid_reject('Método no permitido.', 405, 'method_not_allowed');
    }
    $domain = $_SERVER['HTTP_X_COMPANY_DOMAIN'] ?? '';
    if ($domain === '' && function_exists('getallheaders')) {
        foreach (getallheaders() as $key => $value) {
            if (strtolower($key) === 'x-company-domain') {
                $domain = $value;
                break;
            }
        }
    }
    if (strtolower(trim($domain)) !== 'tid.net.pe') {
        tid_reject('Dominio no autorizado. Usa X-Company-Domain: tid.net.pe.', 403, 'invalid_domain');
    }
} catch (Throwable $error) {
    tid_error($error, 'Solicitud API');
}
