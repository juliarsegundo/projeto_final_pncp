-- =====================================================================
-- 02_perguntas.sql  -  As 6 perguntas de negocio da Controladoria
-- Banco: pncp_controladoria
-- Regras: percentual = SOMA / SOMA (nunca media de percentuais);
--         economia so conta itens comparaveis (comparavel = 1);
--         NULLIF evita divisao por zero (ex.: Credenciamento nao tem item comparavel).
-- =====================================================================
USE pncp_controladoria;

-- ---------------------------------------------------------------------
-- PERGUNTA 1 - Economia global do Poder Publico
-- Qual o percentual e o valor nominal economizado (estimado - homologado)?
-- ---------------------------------------------------------------------
SELECT
    COUNT(*)                                                              AS itens_comparaveis,
    SUM(valor_total_estimado)                                             AS estimado_comparavel,
    SUM(valor_total_homologado)                                           AS homologado_comparavel,
    SUM(valor_total_estimado) - SUM(valor_total_homologado)               AS economia_nominal,
    ROUND(100 * (SUM(valor_total_estimado) - SUM(valor_total_homologado))
          / NULLIF(SUM(valor_total_estimado), 0), 2)                      AS economia_pct
FROM fato_item_contratado
WHERE comparavel = 1;

-- ---------------------------------------------------------------------
-- PERGUNTA 2 - Concentracao e risco de fornecedores
-- 10 maiores fornecedores em volume homologado e % do total (todos os itens da fato)
-- ---------------------------------------------------------------------
SELECT
    f.ni_fornecedor,
    f.nome_fornecedor,
    COUNT(*)                                                              AS itens,
    SUM(t.valor_total_homologado)                                         AS volume_homologado,
    ROUND(100 * SUM(t.valor_total_homologado)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2) AS pct_do_total
FROM fato_item_contratado t
JOIN dim_fornecedor f ON f.sk_fornecedor = t.sk_fornecedor
GROUP BY f.ni_fornecedor, f.nome_fornecedor
ORDER BY volume_homologado DESC
LIMIT 10;

-- Complemento da pergunta 2: quanto os 10 maiores concentram juntos
SELECT
    SUM(volume) AS volume_top10,
    ROUND(100 * SUM(volume) / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2) AS pct_top10
FROM (
    SELECT SUM(valor_total_homologado) AS volume
    FROM fato_item_contratado
    GROUP BY sk_fornecedor
    ORDER BY volume DESC
    LIMIT 10
) AS maiores;

-- ---------------------------------------------------------------------
-- PERGUNTA 3 - Eficacia por modalidade
-- Maior desagio (so comparaveis) e maior volume de recursos (todos os itens)
-- ---------------------------------------------------------------------
SELECT
    m.nome_modalidade,
    COUNT(*)                                                              AS itens,
    SUM(t.valor_total_homologado)                                         AS volume_homologado,
    SUM(CASE WHEN t.comparavel = 1 THEN t.valor_total_estimado ELSE 0 END)   AS estimado_comparavel,
    SUM(CASE WHEN t.comparavel = 1 THEN t.valor_total_homologado ELSE 0 END) AS homologado_comparavel,
    ROUND(100 * (SUM(CASE WHEN t.comparavel = 1 THEN t.valor_total_estimado ELSE 0 END)
               - SUM(CASE WHEN t.comparavel = 1 THEN t.valor_total_homologado ELSE 0 END))
          / NULLIF(SUM(CASE WHEN t.comparavel = 1 THEN t.valor_total_estimado ELSE 0 END), 0), 2) AS economia_pct
FROM fato_item_contratado t
JOIN dim_modalidade m ON m.sk_modalidade = t.sk_modalidade
GROUP BY m.nome_modalidade
ORDER BY volume_homologado DESC;

-- ---------------------------------------------------------------------
-- PERGUNTA 4 - Tempo do ciclo de compras, por orgao
-- Agrupa pelo NOME padronizado; so itens com ciclo; so orgaos com 5 ou mais itens com ciclo
-- ---------------------------------------------------------------------
SELECT
    o.nome_orgao,
    COUNT(t.dias_ciclo)                                                   AS itens_com_ciclo,
    COUNT(DISTINCT o.cnpj_orgao)                                          AS unidades_compradoras,
    ROUND(AVG(t.dias_ciclo), 1)                                           AS ciclo_medio_dias,
    MAX(t.dias_ciclo)                                                     AS ciclo_maximo_dias
FROM fato_item_contratado t
JOIN dim_orgao o ON o.sk_orgao = t.sk_orgao
GROUP BY o.nome_orgao
HAVING COUNT(t.dias_ciclo) >= 5
ORDER BY ciclo_medio_dias DESC;

-- Complemento da pergunta 4: numeros gerais para conferir com a prova real
SELECT
    COUNT(dias_ciclo)               AS itens_com_ciclo,
    ROUND(AVG(dias_ciclo), 1)       AS ciclo_medio_dias,
    MAX(dias_ciclo)                 AS ciclo_maximo_dias,
    COUNT(*) - COUNT(dias_ciclo)    AS itens_sem_ciclo
FROM fato_item_contratado;

-- ---------------------------------------------------------------------
-- PERGUNTA 5 - Distribuicao regional
-- 5a) por estado: onde esta o maior gasto e o melhor desconto
-- ---------------------------------------------------------------------
SELECT
    l.uf_sigla,
    l.regiao,
    COUNT(*)                                                              AS itens,
    SUM(t.valor_total_homologado)                                         AS volume_homologado,
    ROUND(100 * (SUM(CASE WHEN t.comparavel = 1 THEN t.valor_total_estimado ELSE 0 END)
               - SUM(CASE WHEN t.comparavel = 1 THEN t.valor_total_homologado ELSE 0 END))
          / NULLIF(SUM(CASE WHEN t.comparavel = 1 THEN t.valor_total_estimado ELSE 0 END), 0), 2) AS economia_pct
FROM fato_item_contratado t
JOIN dim_localidade l ON l.sk_localidade = t.sk_localidade
GROUP BY l.uf_sigla, l.regiao
ORDER BY volume_homologado DESC;

-- 5b) por regiao
SELECT
    l.regiao,
    COUNT(*)                                                              AS itens,
    SUM(t.valor_total_homologado)                                         AS volume_homologado,
    ROUND(100 * SUM(t.valor_total_homologado)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2) AS pct_do_total,
    ROUND(100 * (SUM(CASE WHEN t.comparavel = 1 THEN t.valor_total_estimado ELSE 0 END)
               - SUM(CASE WHEN t.comparavel = 1 THEN t.valor_total_homologado ELSE 0 END))
          / NULLIF(SUM(CASE WHEN t.comparavel = 1 THEN t.valor_total_estimado ELSE 0 END), 0), 2) AS economia_pct
FROM fato_item_contratado t
JOIN dim_localidade l ON l.sk_localidade = t.sk_localidade
GROUP BY l.regiao
ORDER BY volume_homologado DESC;

-- ---------------------------------------------------------------------
-- PERGUNTA 6 - Perfil dos gastos (perfil_gasto e coluna da propria fato, sem JOIN)
-- ---------------------------------------------------------------------
SELECT
    perfil_gasto,
    COUNT(*)                                                              AS itens,
    SUM(valor_total_homologado)                                           AS volume_homologado,
    ROUND(100 * SUM(valor_total_homologado)
          / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 1) AS pct_do_volume
FROM fato_item_contratado
GROUP BY perfil_gasto
ORDER BY volume_homologado DESC;
