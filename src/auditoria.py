"""Auditoria dos CSVs brutos (Sprint 1)"""
import re
from pathlib import Path

import pandas as pd

RAIZ = Path(__file__).resolve().parent.parent
PASTA_RAW = RAIZ / "data" / "raw"
RELATORIO = RAIZ / "reports" / "auditoria.txt"
linhas_relatorio = []


def mostrar(texto=""):
    print(texto)
    linhas_relatorio.append(str(texto))


def ler(nome):
    return pd.read_csv(PASTA_RAW / f"{nome}.csv", dtype=str,
                       keep_default_na=False, encoding="utf-8")


def padrao(valor):
    valor = re.sub(r"\d", "9", valor)
    valor = re.sub(r"[A-Za-zÀ-ÿ]", "A", valor)
    return valor


def mostrar_formatos(tabela, coluna, top=8):
    if coluna not in tabela.columns:
        mostrar(f"\n  (coluna {coluna} não existe nesta tabela)")
        return
    mostrar(f"\n  Formatos em {coluna} (9 = dígito, A = letra):")
    contagem = tabela[coluna].map(padrao).value_counts().head(top)
    for formato, qtd in contagem.items():
        mostrar(f"    {qtd:>6}  '{formato}'")


compras, itens, resultados = ler("compras"), ler("itens"), ler("resultados")
tabelas = {"compras": compras, "itens": itens, "resultados": resultados}

mostrar("=== 1. TAMANHO DOS ARQUIVOS ===")
for nome, tabela in tabelas.items():
    mostrar(f"{nome}: {len(tabela)} linhas, {len(tabela.columns)} colunas")

mostrar("\n=== 2. REPETIÇÃO EM compras.numero_controle_pncp ===")
repetidos = compras["numero_controle_pncp"].duplicated(keep=False)
mostrar(f"valores distintos: {compras['numero_controle_pncp'].nunique()}")
mostrar(f"linhas com número repetido: {repetidos.sum()}")

mostrar("\n=== 3. FORMATOS ===")
mostrar_formatos(compras, "cnpj_orgao", top=30)
mostrar_formatos(compras, "data_publicacao", top=30)
mostrar_formatos(resultados, "ni_fornecedor", top=30)
mostrar_formatos(resultados, "data_resultado", top=30)
for coluna in ["quantidade", "valor_unitario_estimado", "valor_total_estimado"]:
    mostrar_formatos(itens, coluna, top=40)
for coluna in ["quantidade_homologada", "valor_unitario_homologado", "valor_total_homologado"]:
    mostrar_formatos(resultados, coluna, top=40)

mostrar("\n=== 4. NULOS DISFARÇADOS ===")
SUSPEITOS = ["", "N/A", "NULL", "-", "0", "SEM INFORMAÇÃO", "NÃO SE APLICA"]
for nome, tabela in tabelas.items():
    for coluna in tabela.columns:
        limpo = tabela[coluna].str.strip().str.upper()
        achados = limpo[limpo.isin(SUSPEITOS)].value_counts()
        if len(achados) > 0:
            detalhe = ", ".join(f"'{v}': {q}" for v, q in achados.items())
            mostrar(f"{nome}.{coluna} -> {detalhe}")

mostrar("\n=== 5. ENCODING QUEBRADO ===")
for nome, tabela in tabelas.items():
    for coluna in tabela.columns:
        quebrado = tabela[coluna].str.contains("Ã[\u0080-\u00bf\u2018-\u203a]|Â[\u0080-\u00bf]|�", regex=True)
        if quebrado.sum() > 0:
            exemplo = tabela.loc[quebrado, coluna].iloc[0][:60]
            mostrar(f"{nome}.{coluna}: {quebrado.sum()} linhas. Ex.: {exemplo}")

mostrar("\n=== 6. data_resultado ANTERIOR A data_publicacao ===")
juntos = resultados.merge(
    compras[["numero_controle_pncp", "data_publicacao"]].drop_duplicates("numero_controle_pncp"),
    on="numero_controle_pncp", how="left")
def converter_data(serie):
    """Uma conversão para cada máscara que apareceu na auditoria dos formatos."""
    texto = serie.str.strip().str.replace(r"[T ].*$", "", regex=True)  # tira a hora
    resultado = pd.Series(pd.NaT, index=serie.index, dtype="datetime64[ns]")
    regras = [
        (r"^\d{4}[-/]\d{2}[-/]\d{2}$", "%Y-%m-%d", lambda t: t.str.replace("/", "-")),
        (r"^\d{2}[-./]\d{2}[-./]\d{4}$", "%d/%m/%Y", lambda t: t.str.replace(r"[-.]", "/", regex=True)),
        (r"^\d{8}$", "%Y%m%d", lambda t: t),
    ]
    for padrao_regex, formato, ajustar in regras:
        casa = texto.str.match(padrao_regex)
        resultado[casa] = pd.to_datetime(ajustar(texto[casa]), format=formato, errors="coerce")
    return resultado.dt.normalize()


oito = resultados["data_resultado"].str.match(r"^\d{8}$")
mostrar(f"data_resultado com 8 dígitos: {oito.sum()} (começam com 20: {resultados.loc[oito, 'data_resultado'].str.startswith('20').sum()})")
data_res = converter_data(juntos["data_resultado"])
data_pub = converter_data(juntos["data_publicacao"])
mostrar(f"data_resultado ilegível ou vazia: {data_res.isna().sum()}")
mostrar(f"data_resultado anterior à publicação: {(data_res < data_pub).sum()}")

mostrar("\n=== 7. NOMES E UNIDADES ===")
nomes = compras["razao_social_orgao"]
padronizados = nomes.str.strip().str.upper().str.replace(r"\s+", " ", regex=True)
mostrar(f"razao_social_orgao distintos como vêm: {nomes.nunique()}")
mostrar(f"razao_social_orgao distintos após maiúsculas e espaços: {padronizados.nunique()}")
mostrar(f"cnpj_orgao distintos como vêm: {compras['cnpj_orgao'].nunique()}")
mostrar(f"unidade_medida distintas: {itens['unidade_medida'].nunique()}")
mostrar(f"nome_fornecedor distintos: {resultados['nome_fornecedor'].nunique()}")

RELATORIO.parent.mkdir(exist_ok=True)
RELATORIO.write_text("\n".join(linhas_relatorio), encoding="utf-8")
mostrar(f"\nRelatório salvo em {RELATORIO}")
