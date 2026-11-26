-- ============================================================
-- saep_db.sql - Banco de dados da ClÃ­nica VeterinÃ¡ria (MySQL 8+)
-- Cria o banco, as tabelas e popula com >= 3 registros por tabela.
-- Senhas (BCrypt): admin@clinicavet.com / Admin@123 | atendente@clinicavet.com / Atend@123
--                  tutor@clinicavet.com / Tutor@123 | pet@clinicavet.com / Pet@1234
-- CPF: cifrado com AES-256-GCM + HMAC-SHA256 (chaves de DEV do application.properties).
-- Ao usar este script, a API sobe sem recriar o schema (Flyway baseline na V1).
-- ============================================================
DROP DATABASE IF EXISTS saep_db;
CREATE DATABASE saep_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE saep_db;
SET NAMES utf8mb4;

-- V1: schema inicial da ClÃ­nica VeterinÃ¡ria
CREATE TABLE perfil (
    id   BIGINT NOT NULL AUTO_INCREMENT,
    nome VARCHAR(30) NOT NULL,
    descricao VARCHAR(120) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_perfil_nome UNIQUE (nome)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE tutor (
    id                BIGINT NOT NULL AUTO_INCREMENT,
    nome              VARCHAR(120) NOT NULL,
    cpf_criptografado VARCHAR(255) NOT NULL,
    cpf_hash          CHAR(64) NOT NULL,
    telefone          VARCHAR(20) NOT NULL,
    email             VARCHAR(120) NOT NULL,
    endereco          VARCHAR(255),
    ativo             BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uk_tutor_cpf_hash UNIQUE (cpf_hash)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE usuario (
    id        BIGINT NOT NULL AUTO_INCREMENT,
    nome      VARCHAR(120) NOT NULL,
    email     VARCHAR(120) NOT NULL,
    senha     VARCHAR(100) NOT NULL,
    foto_url  VARCHAR(255),
    ativo     BOOLEAN NOT NULL DEFAULT TRUE,
    perfil_id BIGINT NOT NULL,
    tutor_id  BIGINT NULL,
    criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uk_usuario_email UNIQUE (email),
    CONSTRAINT fk_usuario_perfil FOREIGN KEY (perfil_id) REFERENCES perfil (id),
    CONSTRAINT fk_usuario_tutor  FOREIGN KEY (tutor_id)  REFERENCES tutor (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE pet (
    id              BIGINT NOT NULL AUTO_INCREMENT,
    nome            VARCHAR(80) NOT NULL,
    especie         VARCHAR(40) NOT NULL,
    raca            VARCHAR(60),
    data_nascimento DATE,
    ativo           BOOLEAN NOT NULL DEFAULT TRUE,
    tutor_id        BIGINT NOT NULL,
    criado_em       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_pet_tutor FOREIGN KEY (tutor_id) REFERENCES tutor (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE agendamento (
    id          BIGINT NOT NULL AUTO_INCREMENT,
    data_hora   DATETIME NOT NULL,
    motivo      VARCHAR(160) NOT NULL,
    observacoes VARCHAR(255),
    status      VARCHAR(20) NOT NULL DEFAULT 'AGENDADO',
    pet_id      BIGINT NOT NULL,
    usuario_id  BIGINT NULL,
    criado_em   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_agendamento_pet     FOREIGN KEY (pet_id)     REFERENCES pet (id),
    CONSTRAINT fk_agendamento_usuario FOREIGN KEY (usuario_id) REFERENCES usuario (id),
    INDEX idx_agendamento_data (data_hora)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
-- Tabelas de log de atualizaÃ§Ã£o (uma por funcionalidade)
CREATE TABLE log_tutor (
    id            BIGINT NOT NULL AUTO_INCREMENT,
    tutor_id      BIGINT NOT NULL,
    acao          VARCHAR(30) NOT NULL,
    descricao     VARCHAR(500) NOT NULL,
    usuario_email VARCHAR(120) NOT NULL,
    data_hora     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_log_tutor FOREIGN KEY (tutor_id) REFERENCES tutor (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE log_pet (
    id            BIGINT NOT NULL AUTO_INCREMENT,
    pet_id        BIGINT NOT NULL,
    acao          VARCHAR(30) NOT NULL,
    descricao     VARCHAR(500) NOT NULL,
    usuario_email VARCHAR(120) NOT NULL,
    data_hora     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_log_pet FOREIGN KEY (pet_id) REFERENCES pet (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE log_agendamento (
    id             BIGINT NOT NULL AUTO_INCREMENT,
    agendamento_id BIGINT NOT NULL,
    acao           VARCHAR(30) NOT NULL,
    descricao      VARCHAR(500) NOT NULL,
    data_anterior  DATETIME NULL,
    data_nova      DATETIME NULL,
    usuario_email  VARCHAR(120) NOT NULL,
    data_hora      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_log_agendamento FOREIGN KEY (agendamento_id) REFERENCES agendamento (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE log_usuario (
    id            BIGINT NOT NULL AUTO_INCREMENT,
    usuario_id    BIGINT NOT NULL,
    acao          VARCHAR(30) NOT NULL,
    descricao     VARCHAR(500) NOT NULL,
    usuario_email VARCHAR(120) NOT NULL,
    data_hora     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_log_usuario FOREIGN KEY (usuario_id) REFERENCES usuario (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ===== DADOS =====
INSERT INTO perfil (id, nome, descricao) VALUES
 (1,'ADMIN','Administrador: acesso total, usuÃ¡rios e logs'),
 (2,'USUARIO','UsuÃ¡rio comum (atendente): gerencia tutores, pets e agendamentos'),
 (3,'TUTOR','Tutor: consulta os pets e agendamentos vinculados a ele'),
 (4,'PET','Pet: acesso somente leitura aos prÃ³prios agendamentos');

INSERT INTO tutor (id, nome, cpf_criptografado, cpf_hash, telefone, email, endereco) VALUES
 (1,'Mariana Souza','6u2JjtIsGqr6S7APsbMnVSSCkgROmkeCLQNqc2xeHyi12RIi0Pw+','5ddfbdfe3e9963872a870fa38452b51d2f9022f1bc8f100d20f1cb57756e17df','(71) 99811-2233','mariana.souza@email.com','Rua das AcÃ¡cias, 120 - Pituba, Salvador/BA'),
 (2,'Carlos Eduardo Lima','m47X2g9ZNZCjM3Gy7ma+7JfHzc9sUquDpl/ntihac6cDmZ9cC0Wk','5bc03529dd64695922503236c4f1cbaa74c5ac78c2cabde8433b2228219b2451','(71) 98822-4455','carlos.lima@email.com','Av. OceÃ¢nica, 900 - Barra, Salvador/BA'),
 (3,'Fernanda Oliveira','ZRNXUBVG8aE8LfrdAW2MkldP5g2jcm+sFYPtMItIREM9qMjtR+yh','f6ab9df71c59936148dec591a6f33ed17a853e5c0e1769b32e6461aa1f885b53','(71) 99700-1010','fernanda.o@email.com','Rua da Paz, 45 - Rio Vermelho, Salvador/BA');

INSERT INTO usuario (id, nome, email, senha, foto_url, ativo, perfil_id, tutor_id) VALUES
 (1,'Administrador Geral','admin@clinicavet.com','$2a$10$UO9MBwggh..S5G09ynK0t.bYlGik/tI6BCO29jgdnzlw0m83DAzxO',NULL,TRUE,1,NULL),
 (2,'Ana Atendente','atendente@clinicavet.com','$2a$10$DTh.I.B.mHYe46pWZkNNluJ1sVR5EDxKDWuJPe4X4Gv1EL5eSw.pO',NULL,TRUE,2,NULL),
 (3,'Mariana Souza','tutor@clinicavet.com','$2a$10$xno1MFoq0mGWv1.PUjz7euknMGjNduF/5BhxKKOZjAgZnTYKsoEGK',NULL,TRUE,3,1),
 (4,'Thor (Pet)','pet@clinicavet.com','$2a$10$tlPfxuioMUVPc89gYch.ZuKx0bjO4mhXZrib6J6W4xsJWuPkzGWXK',NULL,TRUE,4,1);

INSERT INTO pet (id, nome, especie, raca, data_nascimento, tutor_id) VALUES
 (1,'Thor','CÃ£o','Golden Retriever','2020-03-14',1),
 (2,'Mel','Gato','SiamÃªs','2021-07-02',2),
 (3,'Bob','CÃ£o','Vira-lata','2019-11-20',3),
 (4,'Luna','Gato','Persa','2022-01-09',1);

INSERT INTO agendamento (id, data_hora, motivo, observacoes, status, pet_id, usuario_id) VALUES
 (1,'2026-12-01 09:00:00','Vacina antirrÃ¡bica','Trazer carteirinha','AGENDADO',1,2),
 (2,'2026-12-01 14:30:00','Consulta de rotina',NULL,'CONFIRMADO',2,2),
 (3,'2026-12-03 10:00:00','Retorno pÃ³s-cirÃºrgico','Jejum de 8h','AGENDADO',3,2),
 (4,'2026-12-06 16:00:00','Banho e tosa',NULL,'AGENDADO',1,1);

INSERT INTO log_tutor (tutor_id, acao, descricao, usuario_email, data_hora) VALUES
 (1,'CRIACAO','Tutor cadastrado: Mariana Souza','atendente@clinicavet.com','2026-11-20 08:10:00'),
 (2,'CRIACAO','Tutor cadastrado: Carlos Eduardo Lima','atendente@clinicavet.com','2026-11-20 08:11:00'),
 (3,'CRIACAO','Tutor cadastrado: Fernanda Oliveira','atendente@clinicavet.com','2026-11-20 08:12:00'),
 (1,'ATUALIZACAO','Alterado: telefone ''(71) 99999-0000'' -> ''(71) 99811-2233''','atendente@clinicavet.com','2026-11-22 10:05:00');

INSERT INTO log_pet (pet_id, acao, descricao, usuario_email, data_hora) VALUES
 (1,'CRIACAO','Pet cadastrado: Thor','atendente@clinicavet.com','2026-11-20 09:10:00'),
 (2,'CRIACAO','Pet cadastrado: Mel','atendente@clinicavet.com','2026-11-20 09:11:00'),
 (3,'CRIACAO','Pet cadastrado: Bob','atendente@clinicavet.com','2026-11-20 09:12:00'),
 (4,'CRIACAO','Pet cadastrado: Luna','atendente@clinicavet.com','2026-11-20 09:13:00');

INSERT INTO log_agendamento (agendamento_id, acao, descricao, data_anterior, data_nova, usuario_email, data_hora) VALUES
 (1,'CRIACAO','Agendamento criado para o pet #1 em 2026-12-01 09:00',NULL,'2026-12-01 09:00:00','atendente@clinicavet.com','2026-11-21 11:10:00'),
 (2,'CRIACAO','Agendamento criado para o pet #2 em 2026-12-01 14:30',NULL,'2026-12-01 14:30:00','atendente@clinicavet.com','2026-11-21 11:11:00'),
 (3,'CRIACAO','Agendamento criado para o pet #3 em 2026-12-03 10:00',NULL,'2026-12-03 10:00:00','atendente@clinicavet.com','2026-11-21 11:12:00'),
 (4,'CRIACAO','Agendamento criado para o pet #1 em 2026-12-06 16:00',NULL,'2026-12-06 16:00:00','atendente@clinicavet.com','2026-11-21 11:13:00'),
 (1,'REAGENDAMENTO','Data alterada de 30/11/2026 09:00 para 01/12/2026 09:00','2026-11-30 09:00:00','2026-12-01 09:00:00','atendente@clinicavet.com','2026-11-23 15:40:00');

INSERT INTO log_usuario (usuario_id, acao, descricao, usuario_email, data_hora) VALUES
 (1,'CRIACAO','UsuÃ¡rio criado: admin@clinicavet.com','admin@clinicavet.com','2026-11-19 18:00:00'),
 (2,'CRIACAO','UsuÃ¡rio criado: atendente@clinicavet.com','admin@clinicavet.com','2026-11-19 18:01:00'),
 (3,'CRIACAO','UsuÃ¡rio criado: tutor@clinicavet.com','admin@clinicavet.com','2026-11-19 18:02:00'),
 (4,'CRIACAO','UsuÃ¡rio criado: pet@clinicavet.com','admin@clinicavet.com','2026-11-19 18:03:00'),
 (1,'LOGIN','Login realizado com sucesso','admin@clinicavet.com','2026-11-25 08:00:00');
