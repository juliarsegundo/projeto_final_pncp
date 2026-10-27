## Auditoria dos dados brutos (Sprint 1)

Auditoria feita com `src/auditoria.py` (leitura de todos os CSVs como texto, sem corrigir nada). O relatório completo está em `reports/auditoria.txt`.

**Tamanho dos arquivos:** `compras.csv` 2.042 linhas, `itens.csv` 7.077 linhas, `resultados.csv` 15.896 linhas. Não há `numero_controle_pncp` repetido em `compras.csv` (2.042 valores distintos).

### Problemas encontrados

| Problema | Coluna | Quantos registros | Como vou tratar |
| --- | --- | --- | --- |
| CNPJ com máscara (pontos, barra e hífen) | `compras.cnpj_orgao` | 176 de 2.042 (8,6%) | Remover tudo que não é dígito |
| CNPJ/CPF com máscara | `resultados.ni_fornecedor` | 1.631 de 15.896 (10,3%): 1.239 CNPJ e 392 CPF | Remover tudo que não é dígito |
| Espaços nas pontas do documento | `compras.cnpj_orgao` / `resultados.ni_fornecedor` | 131 / 990 | `strip()` antes de qualquer outra limpeza |
| Zero à esquerda perdido (CNPJ com 11 a 13 dígitos) | `compras.cnpj_orgao` | 77 (64 com 12 dígitos, 10 com 13, 3 com 11) | Completar com zeros até 14 dígitos |
| Zero à esquerda perdido (documento com 8 a 13 dígitos) | `resultados.ni_fornecedor` | 355 (175 com 13, 154 com 10, 18 com 12, 6 com 9, 2 com 8) | Completar com zeros: 14 dígitos para PJ, 11 para PF, usando `tipo_pessoa` |
| Documento com letras (provável fornecedor estrangeiro) | `resultados.ni_fornecedor` | 18 | Não completar com zeros; manter o texto limpo e conferir `tipo_pessoa` (PE) |
| Dinheiro e quantidades com `R$` | `itens`: `quantidade`, `valor_unitario_estimado`, `valor_total_estimado`; `resultados`: `quantidade_homologada`, `valor_unitario_homologado`, `valor_total_homologado` | pelo menos 1.145, 1.064, 1.067, 2.539, 2.106 e 2.129 (na mesma ordem) | Remover `R$` |
| Espaços (inclusive invisíveis) ao redor de números | mesmas 6 colunas | pelo menos 286, 204, 245, 637, 436 e 432 | Remover espaços antes de converter |
| Milhar e decimal juntos (`1.234,56` e `1,234.56`) | mesmas 6 colunas | pelo menos 213, 449, 1.222, 1.146, 949 e 2.806 | Regra 12: quando aparecem os dois símbolos, o último é o decimal |
| Vírgula como decimal (`1234,56`) | mesmas 6 colunas | pelo menos 1.262, 919, 279, 2.245, 1.811 e 312 | Regra 12: vírgula ou ponto sozinho é sempre o decimal |
| Valores negativos entre parênteses | colunas de valor | 0 nos formatos mais comuns (ver nota abaixo) | Converter para número negativo, caso apareça |
| Datas em 7 máscaras no mesmo campo | `compras.data_publicacao` | 723 de 2.042 (35,4%) fora do formato mais comum | Converter cada máscara com seu próprio formato |
| Datas em 7 máscaras no mesmo campo | `resultados.data_resultado` | 5.595 de 15.896 (35,2%) fora do formato mais comum | Converter cada máscara com seu próprio formato |
| Data sem separador (AAAAMMDD) | `data_publicacao` / `data_resultado` | 106 / 923 | Ler como `%Y%m%d` (as 923 começam com 20) |
| Homologação anterior à publicação | `resultados.data_resultado` | 234 de 15.896 (1,5%), estimativa antes da limpeza | Anular data de homologação e ciclo; manter o item (regra 7) |
| Nulos disfarçados (`NULL`, `-`, `N/A`, `0`, `SEM INFORMAÇÃO`) | `compras.processo` | 72 | Converter para vazio |
| Nulos disfarçados | `compras.modo_disputa` | 54, mais 904 com `NÃO SE APLICA` | Converter para vazio (decidir sobre os 904 e documentar) |
| Nulos disfarçados | `itens.situacao_item` | 196 | Converter para vazio |
| Nulos disfarçados | `resultados.porte` | 425 (inclui 9 `NÃO SE APLICA`) | Converter para vazio |
| Texto vazio ou `NÃO SE APLICA` sem informação | `itens.unidade_medida` / `itens.criterio_julgamento` / `itens.categoria_item` | 9 vazios / 1.883 / 7.077 (todas) | `categoria_item` é ignorada (o enunciado diz que não ajuda); as demais viram vazio |
| Acentos quebrados (`Ã§`, `Ã£`) | `compras.objeto_compra` | 43 | Corrigir a codificação do texto |
| Acentos quebrados | `compras.municipio` / `compras.nome_unidade` | 28 / 14 | Corrigir a codificação do texto |
| Acentos quebrados | `itens.descricao` | 116 | Corrigir a codificação do texto |
| Acentos quebrados | `resultados.nome_fornecedor` | 1 | Corrigir a codificação do texto |
| Quebra de linha dentro do texto | `itens.descricao` (apareceu no exemplo do relatório) | a medir na limpeza | Trocar por espaço |
| Mesmo órgão escrito de formas diferentes | `compras.razao_social_orgao` | 440 nomes distintos, 352 só após maiúsculas e espaços (88 variações) | Maiúsculas, espaços e acentos padronizados; agrupar por nome |
| Mesmo órgão com vários CNPJ (unidades) e CNPJ sujos | `compras.cnpj_orgao` | 539 distintos como vêm (esperado: 363 após a limpeza) | Uma linha por CNPJ limpo em `dim_orgao` |
| Unidades de medida com grafias variadas | `itens.unidade_medida` | 360 distintas | Padronizar e decidir o agrupamento (documentado na Sprint 2) |
| Fornecedor com muitas grafias de nome | `resultados.nome_fornecedor` | 10.707 nomes distintos | Padronizar o texto; o fornecedor é identificado por `ni_fornecedor` |

Nota sobre as contagens "pelo menos": o relatório lista os 40 formatos mais comuns de cada coluna de dinheiro, então os números dessas linhas são o mínimo. O total real é igual ou maior.

### Vazios que são normais (não são problema)

| Coluna | Vazios | Por que é normal |
| --- | --- | --- |
| `resultados.data_cancelamento` | 15.834 | Vazio significa que o resultado não foi cancelado (62 foram cancelados) |
| `resultados.ordem_classificacao_srp` | 11.976 | Pela regra do projeto, vazio conta como 1º colocado |
| `itens.catalogo_codigo_item` | 7.068 | Coluna quase sempre vazia, segundo o dicionário |
| `compras.data_abertura_proposta` e `data_encerramento_proposta` | 617 | Campos opcionais; não entram na fato |

### Hipóteses de leitura

- Datas com `-`, `.` ou `/` e o ano no final (`10-03-2025`, `10.03.2025`, `10/03/2025`) foram lidas como dia/mês/ano.
- Os `0` em campos numéricos (quantidade, valores) são números e não nulos. O `0` só é nulo em campos de texto.
