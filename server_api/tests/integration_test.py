"""Pruebas HTTP contra PHP real y MariaDB/MySQL LOCAL, con datos sintéticos.

TID_TEST_DSN=mysql:host=127.0.0.1;port=3306 (sin base), TID_TEST_USER,
TID_TEST_PASSWORD, PHP_BINARY (opcional). Crea y elimina su propia tid_test_*.
No usa config/conexion.php real y nunca admite un host remoto.
"""
import base64
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import re
import shutil
import signal
import socket
import subprocess
import tempfile
import time
import unittest
import urllib.error
import urllib.parse
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]
PHP = os.environ.get('PHP_BINARY', 'php')
BRIDGE = r'''
$input = json_decode(stream_get_contents(STDIN), true, 64, JSON_THROW_ON_ERROR);
$pdo = new PDO(getenv('TID_TEST_DSN'), getenv('TID_TEST_USER'), getenv('TID_TEST_PASSWORD'),
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
if ($input['query']) {
    $stmt = $pdo->query($input['sql']);
    echo json_encode($stmt->fetchAll(PDO::FETCH_ASSOC), JSON_THROW_ON_ERROR);
} else {
    $pdo->exec($input['sql']);
    echo '[]';
}
'''


class ApiTest(unittest.TestCase):
    @classmethod
    def db(cls, sql, query=False, server=False):
        env = dict(cls.env)
        if server:
            env['TID_TEST_DSN'] = cls.server_dsn
        result = subprocess.run([PHP, '-r', BRIDGE], env=env,
            input=json.dumps({'sql': sql, 'query': query}), text=True,
            capture_output=True, check=True)
        return json.loads(result.stdout)

    @classmethod
    def setUpClass(cls):
        cls.server_dsn = os.environ.get('TID_TEST_DSN', '')
        if not re.fullmatch(r'mysql:host=127\.0\.0\.1(?:;port=[0-9]{1,5})?;?', cls.server_dsn):
            raise RuntimeError('TID_TEST_DSN debe señalar únicamente 127.0.0.1, sin dbname.')
        cls.name = 'tid_test_' + uuid.uuid4().hex
        cls.env = dict(os.environ, TID_TEST_DSN=cls.server_dsn.rstrip(';') + ';dbname=' + cls.name,
            TID_TEST_USER=os.environ.get('TID_TEST_USER', 'root'),
            TID_TEST_PASSWORD=os.environ.get('TID_TEST_PASSWORD', ''), PHP_CLI_SERVER_WORKERS='4')
        cls.db('CREATE DATABASE `' + cls.name + '` CHARACTER SET utf8mb4', server=True)
        cls.addClassCleanup(lambda: cls.db('DROP DATABASE `' + cls.name + '`', server=True))
        cls.temp = tempfile.TemporaryDirectory(prefix='tid-api-test-')
        cls.addClassCleanup(cls.temp.cleanup)
        cls.web = Path(cls.temp.name) / 'api'
        shutil.copytree(ROOT, cls.web, ignore=shutil.ignore_patterns('tests', 'conexion.php'))
        (cls.web / 'config/conexion.php').write_text("<?php\n$pdo = new PDO(getenv('TID_TEST_DSN'), getenv('TID_TEST_USER'), getenv('TID_TEST_PASSWORD'));\n")
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0))
            cls.port = sock.getsockname()[1]
        cls.log = open(Path(cls.temp.name) / 'php.log', 'w+')
        cls.addClassCleanup(cls.log.close)
        cls.process = subprocess.Popen([PHP, '-S', f'127.0.0.1:{cls.port}', '-t', str(cls.web)],
            env=cls.env, stdout=cls.log, stderr=cls.log, start_new_session=True)
        cls.addClassCleanup(cls.stop_server)
        cls.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        for _ in range(100):
            try:
                with socket.create_connection(('127.0.0.1', cls.port), timeout=.1):
                    return
            except OSError:
                if cls.process.poll() is not None:
                    cls.log.seek(0)
                    raise RuntimeError(cls.log.read())
                time.sleep(.05)
        raise RuntimeError('PHP no inició.')

    @classmethod
    def stop_server(cls):
        if cls.process.poll() is None:
            os.killpg(cls.process.pid, signal.SIGTERM)
            cls.process.wait(timeout=5)

    def setUp(self):
        self.db((ROOT / 'tests/schema.sql').read_text())

    def call(self, endpoint, data=None, form=False, method='POST', domain='tid.net.pe', raw=None, content_type=None):
        body = raw if raw is not None else (urllib.parse.urlencode(data).encode() if form else json.dumps(data or {}).encode())
        headers = {'Content-Type': content_type or ('application/x-www-form-urlencoded' if form else 'application/json')}
        if domain is not None:
            headers['X-Company-Domain'] = domain
        request = urllib.request.Request(f'http://127.0.0.1:{self.port}/{endpoint}', data=body, headers=headers, method=method)
        try:
            response = self.opener.open(request, timeout=10)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            text = response.read().decode('utf-8')
            return response.status, json.loads(text) if text else None

    def debt(self, codigo='TID-TEST-001'):
        return self.call('api_obtener_deuda.php', {'trackings': [codigo]})

    def delivery(self, codigo='TID-TEST-001', **changes):
        data = {'trackings': json.dumps([codigo]),
            'urls_fotos': json.dumps(['https://example.com/photo1.png', 'https://example.com/photo2.png']),
            'url_firma': 'https://example.com/signature.png', 'id_usuario': '42',
            'monto_cobrado': '118.00', 'descuento': '0.00', 'id_medio_pago': '1'}
        data.update(changes)
        return self.call('api_procesar_entrega_cobro.php', data, form=True)

    def assert_untouched(self):
        self.assertEqual(self.db('SELECT estado,pago,fecha_entrega FROM encomienda WHERE id_encomienda=10', True),
            [{'estado': 'EN DESTINO', 'pago': 'PAGO EN DESTINO', 'fecha_entrega': None}])
        self.assertEqual(self.db('SELECT estado,total FROM venta WHERE id_venta=100', True),
            [{'estado': 'PENDIENTE', 'total': '118.00'}])
        self.assertEqual(self.db('SELECT * FROM encomienda_movimiento', True), [])

    def test_http_methods_domain_and_json(self):
        for file in ROOT.glob('*.php'):
            with self.subTest(endpoint=file.name):
                self.assertEqual(self.call(file.name, method='OPTIONS', domain=None), (204, None))
                self.assertEqual(self.call(file.name, method='GET')[0], 405)
                self.assertEqual(self.call(file.name, domain=None)[0], 403)
                self.assertEqual(self.call(file.name, domain='jrcargo.com.pe')[0], 403)
        for raw in (b'{', b'[]', b'null', b'"texto"', b'{"trackings":{"0":"TID-TEST-001"}}'):
            self.assertEqual(self.call('api_obtener_deuda.php', raw=raw)[0], 400)

    def test_search_prefix_and_filters(self):
        status, result = self.call('get_encomiendas_dni.php', {'dni': 'DOC-SIN'})
        self.assertEqual(status, 200)
        self.assertEqual({row['traking'] for row in result['data']}, {'TID-TEST-001', 'TID-TEST-002'})
        self.db("UPDATE encomienda SET estado='EN RUTA' WHERE id_encomienda=11")
        self.assertEqual(len(self.call('get_encomiendas_dni.php', {'dni': 'TID-TEST'})[1]['data']), 1)
        self.assertEqual(self.call('get_encomiendas_dni.php', {'dni': 'TI'})[1]['data'], [])
        self.assertEqual(self.call('get_encomiendas_dni.php', {'dni': 'TID%'})[1]['data'], [])

    def test_tracking_and_receipt_queries(self):
        status, body = self.call('get_encomienda_tracking.php', {'codigo_tracking': 'TID-TEST-001'})
        self.assertEqual(status, 200)
        self.assertEqual(len(body['data']), 2)  # dos productos, sin error SQL
        # La falta de una venta o producto no oculta la encomienda.
        self.assertTrue(self.call('get_encomienda_tracking.php', {'codigo_tracking': 'TID-TEST-002'})[1]['success'])
        today = self.db('SELECT CURDATE() AS fecha', True)[0]['fecha']
        status, body = self.call('get_encomienda_comprobante.php', {'serie': 'TEST', 'correlativo': '1', 'fecha': today})
        self.assertEqual(status, 200)
        self.assertEqual(len(body['data']), 2)
        self.assertEqual(self.call('get_encomienda_comprobante.php', {'serie': 'TEST', 'correlativo': '1', 'fecha': '2026-02-30'})[0], 400)

    def test_debt_and_duplicate_details(self):
        self.db('INSERT INTO dt_venta (id_venta,id_encomienda) VALUES (100,10)')
        status, body = self.debt()
        self.assertEqual(status, 200)
        self.assertTrue(body['requiere_cobro'])
        self.assertEqual(body['deuda_total'], 118)
        self.assertEqual(len(body['detalles']), 1)

    def test_no_collection_for_other_payment_modes(self):
        for mode in ('PAGADO', 'PAGO EN BLOQUE', 'CREDITO'):
            with self.subTest(mode=mode):
                self.db("UPDATE encomienda SET pago='" + mode + "' WHERE id_encomienda=10")
                status, body = self.debt()
                self.assertEqual(status, 200)
                self.assertFalse(body['requiere_cobro'])
                self.assertEqual(body['deuda_total'], 0)

    def test_debt_missing_or_multiple_pending_sales(self):
        self.db("UPDATE venta SET estado='PAGADO'")
        self.assertEqual(self.debt()[0], 409)
        self.db("UPDATE venta SET estado='PENDIENTE', id_pago=9")
        self.assertEqual(self.debt()[0], 409)
        self.db('UPDATE venta SET id_pago=NULL')
        self.db('INSERT INTO venta (id_venta,total,estado) VALUES (101,118,"PENDIENTE"); INSERT INTO dt_venta (id_venta,id_encomienda) VALUES (101,10)')
        self.assertEqual(self.debt()[0], 409)

    def test_shared_sale_does_not_charge_whole_order(self):
        self.db('INSERT INTO dt_venta (id_venta,id_encomienda) VALUES (100,11)')
        self.assertEqual(self.debt()[1]['error_code'], 'shared_sale')
        self.assertEqual(self.delivery()[0], 409)
        self.assert_untouched()

    def test_delivery_collects_once_and_registers_terminal(self):
        status, body = self.delivery()
        self.assertEqual(status, 200, body)
        self.assertTrue(body['cobro_realizado'])
        sale = self.db('SELECT estado,total,id_caja_chica,id_cobrador FROM venta', True)[0]
        self.assertEqual(sale, {'estado': 'PAGADO', 'total': '118.00', 'id_caja_chica': 7, 'id_cobrador': 42})
        parcel = self.db('SELECT estado,pago,fotos_evidencia FROM encomienda WHERE id_encomienda=10', True)[0]
        self.assertEqual(parcel['estado'], 'ENTREGADO')
        self.assertEqual(parcel['pago'], 'PAGADO')
        self.assertEqual(len(parcel['fotos_evidencia'].split(',')), 3)
        self.assertEqual(self.db('SELECT id_terminal_evento FROM encomienda_movimiento', True)[0]['id_terminal_evento'], 2)
        self.assertEqual(self.db('SELECT saldo_final FROM caja_chica', True)[0]['saldo_final'], '100.00')
        self.assertEqual(self.delivery()[0], 409)
        self.assertEqual(len(self.db('SELECT * FROM encomienda_movimiento', True)), 1)

    def test_delivery_without_collection_preserves_mode(self):
        for mode in ('PAGADO', 'PAGO EN BLOQUE', 'CREDITO'):
            self.setUp()
            self.db("UPDATE encomienda SET pago='" + mode + "' WHERE id_encomienda=10")
            status, body = self.delivery(monto_cobrado='0', id_medio_pago='')
            self.assertEqual(status, 200, body)
            self.assertFalse(body['cobro_realizado'])
            self.assertEqual(self.db('SELECT pago FROM encomienda WHERE id_encomienda=10', True)[0]['pago'], mode)
            self.assertEqual(self.db('SELECT estado FROM venta', True)[0]['estado'], 'PENDIENTE')

    def test_discount_and_all_payment_methods(self):
        for method in ('1', '2', '3'):
            self.setUp()
            status, body = self.delivery(descuento='11.80', monto_cobrado='106.20', id_medio_pago=method)
            self.assertEqual(status, 200, body)
            self.assertEqual(self.db('SELECT total,descuento,op_gravada,op_igv,id_medio_pago FROM venta', True)[0],
                {'total': '106.20', 'descuento': '11.80', 'op_gravada': '90.00', 'op_igv': '16.20', 'id_medio_pago': int(method)})

    def test_discount_exempt_rounding_and_previous_discount(self):
        self.db('UPDATE venta SET total=10.01,descuento=2,op_gravada=0,op_igv=0,op_exonerada=5.01,op_inafecta=5.00')
        status, body = self.delivery(descuento='0.01', monto_cobrado='10.00')
        self.assertEqual(status, 200, body)
        sale = self.db('SELECT total,descuento,op_exonerada,op_inafecta,op_igv FROM venta', True)[0]
        self.assertEqual(sale['total'], '10.00')
        self.assertEqual(sale['descuento'], '2.01')
        self.assertEqual(float(sale['op_exonerada']) + float(sale['op_inafecta']), 10)
        self.assertEqual(sale['op_igv'], '0.00')

    def test_closed_cashbox_rolls_back(self):
        self.db('UPDATE caja_chica SET estado=0')
        self.assertEqual(self.delivery()[1]['error_code'], 'cashbox_closed')
        self.assert_untouched()

    def test_inactive_payment_and_amount_tampering(self):
        self.db('UPDATE medio_pago SET estado=0 WHERE id_medio_pago=1')
        self.assertEqual(self.delivery()[1]['error_code'], 'inactive_payment_method')
        self.assertEqual(self.delivery(monto_cobrado='0')[1]['error_code'], 'amount_mismatch')
        self.assert_untouched()

    def test_movement_failure_rolls_back_sale_and_parcel(self):
        self.db("CREATE TRIGGER fail_test BEFORE INSERT ON encomienda_movimiento FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='synthetic failure'")
        status, body = self.delivery()
        self.assertEqual(status, 500)
        self.assertNotIn('synthetic failure', json.dumps(body))
        self.assert_untouched()

    def test_invalid_states_and_terminal(self):
        for state in ('ENTREGADO', 'EN RUTA', 'ANULADO'):
            self.db("UPDATE encomienda SET estado='" + state + "' WHERE id_encomienda=10")
            self.assertEqual(self.debt()[0], 409)
            self.assertEqual(self.delivery()[0], 409)
        self.db("UPDATE encomienda SET estado='EN DESTINO',id_terminal_destino=0 WHERE id_encomienda=10")
        self.assertEqual(self.delivery()[1]['error_code'], 'invalid_terminal')

    def test_single_parcel_evidence_and_amount_validation(self):
        for changes in ({'trackings': '["TID-TEST-001","TID-TEST-002"]'},
                {'urls_fotos': '["https://example.com/one.png"]'}, {'url_firma': ''},
                {'monto_cobrado': '118.001'}, {'descuento': '-1'}, {'monto_cobrado': '1e2'},
                {'id_usuario': '0'}, {'url_firma': 'http://example.com/insecure.png'}):
            self.assertEqual(self.delivery(**changes)[0], 400, changes)
        self.assert_untouched()

    def test_concurrent_delivery_only_one_commits(self):
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda _: self.delivery(), range(2)))
        self.assertEqual(sorted(status for status, _ in results), [200, 409])
        self.assertEqual(len(self.db('SELECT * FROM encomienda_movimiento', True)), 1)

    def test_history_date_and_no_product_duplicates(self):
        self.assertEqual(self.delivery()[0], 200)
        today = datetime.now(timezone(timedelta(hours=-5))).strftime('%Y-%m-%d')
        status, body = self.call('get_historial.php', {'fecha': today, 'filtro': 'DOC-SIN'})
        self.assertEqual(status, 200)
        self.assertEqual(len(body['data']), 1)
        self.assertIn('Bolsa sintética', body['data'][0]['producto'])
        self.assertEqual(self.call('get_historial.php', {'fecha': '2000-01-01'})[1]['data'], [])
        self.assertEqual(self.call('get_historial.php', {'fecha': '2026-02-30'})[0], 400)

    def test_legacy_delivery_cannot_bypass_payment(self):
        status, _ = self.call('api_procesar_entrega.php', {'trackings': '["TID-TEST-001"]',
            'urls_fotos': '["https://example.com/one.png","https://example.com/two.png"]'}, form=True)
        self.assertEqual(status, 400)
        self.assert_untouched()

    def test_image_upload_urls_type_and_unique_names(self):
        png = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a9WQAAAAASUVORK5CYII=')
        boundary = 'TidSyntheticMultipartBoundary'
        def upload(content, filename):
            raw = (f'--{boundary}\r\nContent-Disposition: form-data; name="codigo_tracking"\r\n\r\nTID-TEST-001\r\n'
                f'--{boundary}\r\nContent-Disposition: form-data; name="imagen"; filename="{filename}"\r\n'
                'Content-Type: image/png\r\n\r\n').encode() + content + f'\r\n--{boundary}--\r\n'.encode()
            return self.call('subir_imagen.php', raw=raw, content_type='multipart/form-data; boundary=' + boundary)
        self.assertEqual(upload(b'<?php echo "bad";', 'fake.png')[0], 400)
        first = upload(png, 'same.png')
        second = upload(png, 'same.php')
        self.assertEqual(first[0], 200, first)
        self.assertEqual(second[0], 200, second)  # extensión real determinada por MIME
        self.assertNotEqual(first[1]['url'], second[1]['url'])
        self.assertTrue(first[1]['url'].startswith('https://api-tid.net.pe/APIAppDom_Sigtrans/img/'))
        self.assertTrue(second[1]['url'].endswith('.png'))
        status, body = self.call('get_imagenes.php', {'codigo_tracking': 'TID-TEST-001'})
        self.assertEqual(status, 200)
        self.assertEqual(len(body['imagenes']), 2)
        self.assertEqual(self.call('get_imagenes.php', {'codigo_tracking': '../escape'})[0], 400)


if __name__ == '__main__':
    unittest.main(verbosity=2)
