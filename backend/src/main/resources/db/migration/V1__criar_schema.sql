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
-- Perfis (roles) fixos do sistema
INSERT INTO perfil (nome, descricao) VALUES
 ('ADMIN',   'Administrador: acesso total, usuÃ¡rios e logs'),
 ('USUARIO', 'UsuÃ¡rio comum (atendente): gerencia tutores, pets e agendamentos'),
 ('TUTOR',   'Tutor: consulta os pets e agendamentos vinculados a ele'),
 ('PET',     'Pet: acesso somente leitura aos prÃ³prios agendamentos');