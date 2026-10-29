-- =============================================================================
-- 01_criar_banco.sql  |  Modelo estrela do projeto PNCP (1 fato + 4 dimensoes)
-- Roda do zero: apaga e recria as tabelas, entao pode ser executado varias vezes.
-- O tempo NAO e tabela do banco: e o Calendario criado em DAX no Power BI.
-- =============================================================================
CREATE DATABASE IF NOT EXISTS pncp_controladoria
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE pncp_controladoria;

-- A fato aponta para as dimensoes, entao e a primeira a ser apagada.
DROP TABLE IF EXISTS fato_item_contratado;
DROP TABLE IF EXISTS dim_orgao;
DROP TABLE IF EXISTS dim_fornecedor;
DROP TABLE IF EXISTS dim_modalidade;
DROP TABLE IF EXISTS dim_localidade;

-- -----------------------------------------------------------------------------
-- DIMENSOES: chave substituta (sk_) como PK + chave natural como UNIQUE.
-- As chaves sk_ sao INT COM sinal (sem UNSIGNED) para aceitar a linha -1.
-- -----------------------------------------------------------------------------
CREATE TABLE dim_orgao (
    sk_orgao   INT          NOT NULL AUTO_INCREMENT,
    cnpj_orgao VARCHAR(14)  NOT NULL,
    nome_orgao VARCHAR(500) NOT NULL,
    poder      VARCHAR(20)  NOT NULL,
    PRIMARY KEY (sk_orgao),
    UNIQUE KEY uq_dim_orgao_cnpj (cnpj_orgao)
);

CREATE TABLE dim_fornecedor (
    sk_fornecedor   INT          NOT NULL AUTO_INCREMENT,
    ni_fornecedor   VARCHAR(40)  NOT NULL,
    nome_fornecedor VARCHAR(500) NULL,
    tipo_pessoa     VARCHAR(5)   NULL,
    porte           VARCHAR(60)  NULL,
    PRIMARY KEY (sk_fornecedor),
    UNIQUE KEY uq_dim_fornecedor_ni (ni_fornecedor)
);

CREATE TABLE dim_modalidade (
    sk_modalidade   INT          NOT NULL AUTO_INCREMENT,
    modalidade_id   INT          NOT NULL,
    nome_modalidade VARCHAR(100) NOT NULL,
    PRIMARY KEY (sk_modalidade),
    UNIQUE KEY uq_dim_modalidade_id (modalidade_id)
);

CREATE TABLE dim_localidade (
    sk_localidade INT          NOT NULL AUTO_INCREMENT,
    uf_sigla      VARCHAR(10)  NOT NULL,
    uf_nome       VARCHAR(60)  NULL,
    regiao        VARCHAR(20)  NULL,
    PRIMARY KEY (sk_localidade),
    UNIQUE KEY uq_dim_localidade_uf (uf_sigla)
);

-- -----------------------------------------------------------------------------
-- LINHA "NAO INFORMADO" (sk = -1) em cada dimensao. Nunca use 0: no MySQL, inserir
-- 0 numa coluna AUTO_INCREMENT gera o proximo numero. A chave natural usa um valor
-- que nao existe nas outras linhas, porque a coluna e UNIQUE.
-- -----------------------------------------------------------------------------
INSERT INTO dim_orgao (sk_orgao, cnpj_orgao, nome_orgao, poder)
VALUES (-1, '00000000000000', 'NAO INFORMADO', 'Não informado');
INSERT INTO dim_fornecedor (sk_fornecedor, ni_fornecedor, nome_fornecedor, tipo_pessoa, porte)
VALUES (-1, '__NAO_INFORMADO__', 'NAO INFORMADO', NULL, NULL);
INSERT INTO dim_modalidade (sk_modalidade, modalidade_id, nome_modalidade)
VALUES (-1, -1, 'Não informado');
INSERT INTO dim_localidade (sk_localidade, uf_sigla, uf_nome, regiao)
VALUES (-1, '--', 'Não informado', 'Não informado');

-- -----------------------------------------------------------------------------
-- FATO: uma linha por item de contratacao, com o vencedor. Grao garantido pelo
-- UNIQUE (numero_controle_pncp + numero_item). O banco e a segunda barreira de
-- qualidade: os CHECK recusam quantidade <= 0 e valores negativos.
-- -----------------------------------------------------------------------------
CREATE TABLE fato_item_contratado (
    sk_fato                   INT           NOT NULL AUTO_INCREMENT,
    numero_controle_pncp      VARCHAR(60)   NOT NULL,
    numero_item               INT           NOT NULL,
    sk_orgao                  INT           NOT NULL,
    sk_fornecedor             INT           NOT NULL,
    sk_modalidade             INT           NOT NULL,
    sk_localidade             INT           NOT NULL,
    data_publicacao           DATE          NULL,
    data_homologacao          DATE          NULL,
    descricao_item            TEXT          NULL,
    perfil_gasto              VARCHAR(30)   NOT NULL,
    quantidade                DECIMAL(18,4) NOT NULL,
    valor_unitario_estimado   DECIMAL(18,4) NOT NULL,
    valor_unitario_homologado DECIMAL(18,4) NOT NULL,
    valor_total_estimado      DECIMAL(18,2) NOT NULL,
    valor_total_homologado    DECIMAL(18,2) NOT NULL,
    comparavel                TINYINT       NOT NULL,
    economia_valor            DECIMAL(18,2) NULL,
    dias_ciclo                INT           NULL,
    PRIMARY KEY (sk_fato),
    UNIQUE KEY uq_fato_item (numero_controle_pncp, numero_item),
    CONSTRAINT fk_fato_orgao      FOREIGN KEY (sk_orgao)      REFERENCES dim_orgao (sk_orgao),
    CONSTRAINT fk_fato_fornecedor FOREIGN KEY (sk_fornecedor) REFERENCES dim_fornecedor (sk_fornecedor),
    CONSTRAINT fk_fato_modalidade FOREIGN KEY (sk_modalidade) REFERENCES dim_modalidade (sk_modalidade),
    CONSTRAINT fk_fato_localidade FOREIGN KEY (sk_localidade) REFERENCES dim_localidade (sk_localidade),
    CONSTRAINT chk_fato_quantidade        CHECK (quantidade > 0),
    CONSTRAINT chk_fato_unit_estimado     CHECK (valor_unitario_estimado >= 0),
    CONSTRAINT chk_fato_unit_homologado   CHECK (valor_unitario_homologado >= 0),
    CONSTRAINT chk_fato_total_estimado    CHECK (valor_total_estimado >= 0),
    CONSTRAINT chk_fato_total_homologado  CHECK (valor_total_homologado >= 0),
    CONSTRAINT chk_fato_comparavel        CHECK (comparavel IN (0, 1))
);
