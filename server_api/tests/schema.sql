-- Esquema MINIMO de prueba, derivado de los PHP suministrados.
-- Solo para una base local desechable tid_test_*. Nunca importar al hosting.
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS encomienda_movimiento, dt_venta, venta, caja_chica,
    medio_pago, producto_encomienda, encomienda, terminal, usuario;
SET FOREIGN_KEY_CHECKS = 1;
CREATE TABLE usuario (
    id_usuario INT PRIMARY KEY, nombres VARCHAR(100), apellidos VARCHAR(100), num_docu VARCHAR(30)
) ENGINE=InnoDB;
CREATE TABLE terminal (id_terminal INT PRIMARY KEY, nombre VARCHAR(100)) ENGINE=InnoDB;
CREATE TABLE medio_pago (id_medio_pago INT PRIMARY KEY, estado INT NOT NULL) ENGINE=InnoDB;
CREATE TABLE caja_chica (
    id_caja_chica INT PRIMARY KEY, id_usuario INT, estado INT, saldo_final DECIMAL(12,2),
    FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario)
) ENGINE=InnoDB;
CREATE TABLE encomienda (
    id_encomienda INT PRIMARY KEY, codigo VARCHAR(120) UNIQUE, estado VARCHAR(30), pago VARCHAR(30),
    id_destinatario INT, id_remitente INT, id_terminal_origen INT, id_terminal_destino INT,
    fecha_registro DATETIME, fecha_salida DATETIME NULL, fecha_entrega DATETIME NULL,
    fotos_evidencia TEXT NULL,
    FOREIGN KEY (id_destinatario) REFERENCES usuario(id_usuario),
    FOREIGN KEY (id_remitente) REFERENCES usuario(id_usuario)
) ENGINE=InnoDB;
CREATE TABLE producto_encomienda (
    id INT PRIMARY KEY AUTO_INCREMENT, id_encomienda INT, descripcion VARCHAR(100), obs VARCHAR(100),
    FOREIGN KEY (id_encomienda) REFERENCES encomienda(id_encomienda)
) ENGINE=InnoDB;
CREATE TABLE venta (
    id_venta INT PRIMARY KEY, total DECIMAL(12,2), descuento DECIMAL(12,2) DEFAULT 0,
    estado VARCHAR(30), id_pago INT NULL, id_caja_chica INT NULL, id_cobrador INT NULL,
    id_forma_pago INT NULL, id_medio_pago INT NULL, id_terminal INT,
    op_gravada DECIMAL(12,2), op_igv DECIMAL(12,2), op_exonerada DECIMAL(12,2), op_inafecta DECIMAL(12,2),
    serie VARCHAR(20), correlativo VARCHAR(30), fecha_emision DATETIME, fecha_registro DATETIME,
    FOREIGN KEY (id_caja_chica) REFERENCES caja_chica(id_caja_chica),
    FOREIGN KEY (id_cobrador) REFERENCES usuario(id_usuario),
    FOREIGN KEY (id_medio_pago) REFERENCES medio_pago(id_medio_pago)
) ENGINE=InnoDB;
CREATE TABLE dt_venta (
    id INT PRIMARY KEY AUTO_INCREMENT, id_venta INT, id_encomienda INT,
    FOREIGN KEY (id_venta) REFERENCES venta(id_venta),
    FOREIGN KEY (id_encomienda) REFERENCES encomienda(id_encomienda)
) ENGINE=InnoDB;
CREATE TABLE encomienda_movimiento (
    id INT PRIMARY KEY AUTO_INCREMENT, id_encomienda INT, tipo_movimiento VARCHAR(30),
    id_terminal_evento INT, observacion VARCHAR(200), id_usuario INT, fecha_registro DATETIME,
    FOREIGN KEY (id_encomienda) REFERENCES encomienda(id_encomienda),
    FOREIGN KEY (id_terminal_evento) REFERENCES terminal(id_terminal),
    FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario)
) ENGINE=InnoDB;
INSERT INTO usuario VALUES
    (1, 'Destinatario', 'Sintético', 'DOC-SINTETICO-001'),
    (2, 'Remitente', 'Sintético', 'DOC-SINTETICO-002'),
    (42, 'Repartidor', 'Sintético', 'DOC-SINTETICO-042');
INSERT INTO terminal VALUES (1, 'Origen de prueba'), (2, 'Destino de prueba');
INSERT INTO medio_pago VALUES (1, 1), (2, 1), (3, 1);
INSERT INTO caja_chica VALUES (7, 42, 1, 100.00);
INSERT INTO encomienda VALUES
    (10, 'TID-TEST-001', 'EN DESTINO', 'PAGO EN DESTINO', 1, 2, 1, 2, NOW(), NULL, NULL, NULL),
    (11, 'TID-TEST-002', 'EN DESTINO', 'PAGADO', 1, 2, 1, 2, NOW(), NULL, NULL, NULL);
INSERT INTO producto_encomienda (id_encomienda, descripcion, obs) VALUES
    (10, 'Caja sintética', 'Prueba'), (10, 'Bolsa sintética', 'Prueba');
INSERT INTO venta (id_venta, total, descuento, estado, id_pago, id_terminal,
    op_gravada, op_igv, op_exonerada, op_inafecta, serie, correlativo, fecha_emision, fecha_registro)
VALUES (100, 118.00, 0, 'PENDIENTE', NULL, 1, 100.00, 18.00, 0, 0, 'TEST', '1', NOW(), NOW());
INSERT INTO dt_venta (id_venta, id_encomienda) VALUES (100, 10);
