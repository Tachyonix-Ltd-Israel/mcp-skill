"""Converte especificações .docx em markdown sem perder as tabelas.

Só a biblioteca padrão do Python (3.8+): não precisa de pandoc nem de
python-docx. Títulos viram `#`, listas viram `-` e cada tabela do Word vira uma
tabela markdown — com os parágrafos de uma célula unidos por `<br>`, a mesma
convenção dos .md que acompanham as EFs. É nas tabelas que a especificação
mora: campo, alias, chave e saída só fazem sentido lado a lado, e extrair o
texto "achatado" (uma célula por linha) perde essa relação.

Uso:
    python docx_para_md.py <arquivo.docx>                # imprime o markdown
    python docx_para_md.py <arquivo.docx> <saida.md>     # grava o arquivo
    python docx_para_md.py <pasta> <pasta_saida>         # todos os .docx da pasta
    python docx_para_md.py <lote.zip> <pasta_saida>      # direto do .zip

Do .zip, os .docx viram .md e os .md que vierem junto são copiados, sem
extrair antes: num disco que ignora maiúsculas (Windows), dois nomes que só
diferem na caixa se sobrescrevem e um documento some — aqui o segundo ganha o
sufixo `__2` e o nome sai no aviso.
"""
import re
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
_TITULO = re.compile(r"^(?:heading|t[ií]tulo|ttulo|titre|berschrift)\s*([1-9])$", re.I)
# aspas tipográficas do Word: um literal do CDS só aceita a reta ('P', não ‘P’)
_ASPAS = str.maketrans({"‘": "'", "’": "'", "“": '"', "”": '"'})
# condição de join "TAB.CAMPO = ..." no começo da célula
_CONDICAO = re.compile(r"^([A-Z][A-Z0-9_/]*)\.[A-Z0-9_/]+ = ")


def _estilos(z):
    """styleId -> nível de título (0 = não é título), pelo nome e pelo outlineLvl."""
    niveis = {}
    try:
        raiz = ET.fromstring(z.read("word/styles.xml"))
    except KeyError:
        return niveis
    for st in raiz.iter(W + "style"):
        sid = st.get(W + "styleId", "")
        nome_el = st.find(W + "name")
        nome = (nome_el.get(W + "val", "") if nome_el is not None else "").strip()
        nivel = 0
        m = _TITULO.match(nome.replace(" ", "")) or _TITULO.match(sid)
        if m:
            nivel = int(m.group(1))
        elif nome.lower() == "title" or sid.lower() == "title":
            nivel = 1
        else:
            ol = st.find(W + "pPr/" + W + "outlineLvl")
            if ol is not None and ol.get(W + "val", "").isdigit():
                nivel = int(ol.get(W + "val")) + 1
        niveis[sid] = min(nivel, 6)
    return niveis


def _texto(el):
    partes = []
    for n in el.iter():
        if n.tag == W + "t" and n.text:
            partes.append(n.text)
        elif n.tag == W + "tab":
            partes.append(" ")
        elif n.tag in (W + "br", W + "cr"):
            partes.append(" ")
    return re.sub(r"[ \t]+", " ", "".join(partes)).strip().translate(_ASPAS)


def _separa_condicoes(texto):
    """Condições de join que o gerador do .docx colou numa linha só.

    Nas EFs técnicas a célula traz uma condição por linha (`<br>` no .md), e o
    .docx gerado delas perdeu a quebra: `T161T.BSTYP = EKKO.BSTYPT161T.BSART =
    EKKO.BSART`. Toda condição começa pela tabela do join, então cada nova
    ocorrência dela grudada no texto anterior abre uma linha."""
    m = _CONDICAO.match(texto)
    if not m:
        return texto
    return re.sub(r"(?<=[A-Za-z0-9_'])(" + re.escape(m.group(1)) + r"\.)",
                  r"<br>\1", texto)


def _nivel(p, niveis):
    ppr = p.find(W + "pPr")
    if ppr is None:
        return 0, False
    lista = ppr.find(W + "numPr") is not None
    ol = ppr.find(W + "outlineLvl")
    if ol is not None and ol.get(W + "val", "").isdigit():
        return min(int(ol.get(W + "val")) + 1, 6), lista
    st = ppr.find(W + "pStyle")
    sid = st.get(W + "val", "") if st is not None else ""
    return niveis.get(sid, 0), lista


def _celula(tc):
    """O texto da célula: cada parágrafo (e tabela aninhada) separado por <br>."""
    linhas = []
    for el in tc:
        if el.tag == W + "p":
            t = _separa_condicoes(_texto(el))
            if t:
                linhas.append(t)
        elif el.tag == W + "tbl":
            for tr in el.iter(W + "tr"):
                cel = [_texto(c) for c in tr.findall(W + "tc")]
                linhas.append(" · ".join(c for c in cel if c))
        elif el.tag == W + "sdt":
            t = _texto(el)
            if t:
                linhas.append(t)
    return "<br>".join(linhas).replace("|", "\\|")


def _tabela(tbl):
    linhas = []
    for tr in tbl.findall(W + "tr"):
        cels = []
        for tc in tr.findall(W + "tc"):
            pr = tc.find(W + "tcPr")
            span, continua = 1, False
            if pr is not None:
                gs = pr.find(W + "gridSpan")
                if gs is not None and gs.get(W + "val", "").isdigit():
                    span = int(gs.get(W + "val"))
                vm = pr.find(W + "vMerge")
                continua = vm is not None and vm.get(W + "val", "continue") != "restart"
            cels.append("" if continua else _celula(tc))
            cels.extend([""] * (span - 1))
        linhas.append(cels)
    if not linhas:
        return ""
    larg = max(len(l) for l in linhas)
    linhas = [l + [""] * (larg - len(l)) for l in linhas]
    saida = ["| " + " | ".join(linhas[0]) + " |", "|" + "---|" * larg]
    saida += ["| " + " | ".join(l) + " |" for l in linhas[1:]]
    return "\n".join(saida)


def _blocos(corpo, niveis):
    for el in corpo:
        if el.tag == W + "p":
            t = _texto(el)
            if not t:
                continue
            nivel, lista = _nivel(el, niveis)
            if nivel:
                yield "#" * nivel + " " + t
            elif lista:
                yield "- " + t
            else:
                yield t
        elif el.tag == W + "tbl":
            yield _tabela(el)
        elif el.tag == W + "sdt":
            conteudo = el.find(W + "sdtContent")
            if conteudo is not None:
                yield from _blocos(conteudo, niveis)


# Célula com cara de truncada. Numa EF os parâmetros vêm entre `< >` (`valor_alvo=<meta
# da área>`), e um gerador de .docx que lê `< >` como marcação os apaga: a célula
# chega como `valor_maximo=, valor_alvo=` e nada avisa. O conversor não recupera o
# que o .docx já não tem, mas aponta onde falta.
_PARAM_VAZIO = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?=,|;|<br>|$)")
_FIM_CORTADO = re.compile(r"[=,{(]\s*$")


def lacunas(texto):
    """[(seção, célula, motivo)] das células de tabela que parecem truncadas."""
    achados = []
    secao = ""
    for linha in texto.splitlines():
        if linha.startswith("#"):
            secao = linha.lstrip("#").strip()
            continue
        if not linha.startswith("|") or set(linha.strip()) <= set("|-: "):
            continue
        for celula in (c.strip() for c in linha.strip().strip("|").split("|")):
            motivos = []
            vazios = list(dict.fromkeys(_PARAM_VAZIO.findall(celula)))
            if vazios:
                motivos.append("parâmetro sem valor: " + ", ".join(vazios))
            elif _FIM_CORTADO.search(celula):
                motivos.append("termina no meio")
            abertos = [a for a, f in ("{}", "()", "[]") if celula.count(a) > celula.count(f)]
            if abertos and not vazios:
                motivos.append(f"abre `{abertos[0]}` e não fecha")
            if "<>" in celula:
                motivos.append("`<>` vazio")
            if motivos:
                achados.append((secao, celula, "; ".join(motivos)))
    return achados


def converte(caminho):
    """O markdown de um .docx (caminho ou objeto de arquivo), com a seção final
    "Lacunas prováveis" quando alguma célula parece truncada."""
    with zipfile.ZipFile(caminho) as z:
        niveis = _estilos(z)
        raiz = ET.fromstring(z.read("word/document.xml"))
    corpo = raiz.find(W + "body")
    blocos = [b for b in _blocos(corpo, niveis) if b]
    # listas seguidas ficam juntas; o resto separado por linha em branco
    texto = ""
    for i, b in enumerate(blocos):
        if i:
            junto = b.startswith("- ") and blocos[i - 1].startswith("- ")
            texto += "\n" if junto else "\n\n"
        texto += b
    faltas = lacunas(texto)
    if faltas:
        texto += ("\n\n## Lacunas prováveis\n\n"
                  "Células que parecem truncadas no próprio .docx — o valor que "
                  "falta é decisão a pedir ao usuário antes do plano.\n")
        for secao, celula, motivo in faltas:
            curta = celula if len(celula) <= 160 else celula[:157] + "..."
            texto += f"\n- {secao or '(sem seção)'} — {motivo}: `{curta}`"
    return texto + "\n"


class _Destino:
    """Grava sem deixar dois nomes colidirem num disco que ignora maiúsculas.

    Um lote de EFs traz pares que só diferem na maiúscula
    (`…V3__Especificaco…` e `…V3__especificaco…`, a EF e a reexportação): no
    Windows o segundo sobrescreve o primeiro e o documento some sem aviso."""

    def __init__(self, pasta):
        self.pasta = pasta
        self.usados = set()
        self.renomeados = []

    def grava(self, relativo, texto):
        alvo = self.pasta / relativo
        n = 2
        while str(alvo).lower() in self.usados:
            alvo = alvo.with_name(f"{Path(relativo).stem}__{n}{alvo.suffix}")
            n += 1
        if alvo != self.pasta / relativo:
            self.renomeados.append((str(relativo), alvo.name))
        self.usados.add(str(alvo).lower())
        alvo.parent.mkdir(parents=True, exist_ok=True)
        alvo.write_text(texto, encoding="utf-8", newline="\n")


def _do_zip(origem, destino):
    """Os .docx de um .zip viram .md, e os .md que vierem junto são copiados."""
    import io
    saida = _Destino(destino)
    n = 0
    with zipfile.ZipFile(origem) as z:
        for nome in sorted(z.namelist()):
            rel = Path(nome)
            if nome.endswith("/") or rel.name.startswith("~$"):
                continue
            if rel.suffix.lower() == ".docx":
                saida.grava(rel.with_suffix(".md"), converte(io.BytesIO(z.read(nome))))
            elif rel.suffix.lower() == ".md":
                saida.grava(rel, z.read(nome).decode("utf-8", "replace"))
            else:
                continue
            n += 1
    return n, saida.renomeados


def main(args):
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    origem = Path(args[0])
    if origem.suffix.lower() == ".zip":
        destino = Path(args[1]) if len(args) > 1 else origem.with_suffix("")
        n, renomeados = _do_zip(origem, destino)
        print(f"{n} arquivo(s) em {destino}")
        for antes, depois in renomeados:
            print(f"  nome repetido sem maiúsculas: {antes} -> {depois}")
        return 0
    if origem.is_dir():
        destino = Path(args[1]) if len(args) > 1 else origem
        destino.mkdir(parents=True, exist_ok=True)
        n = 0
        for doc in sorted(origem.rglob("*.docx")):
            if doc.name.startswith("~$"):
                continue
            alvo = destino / doc.relative_to(origem).with_suffix(".md")
            alvo.parent.mkdir(parents=True, exist_ok=True)
            alvo.write_text(converte(doc), encoding="utf-8", newline="\n")
            n += 1
        print(f"{n} arquivo(s) convertido(s) em {destino}")
        return 0
    md = converte(origem)
    if len(args) > 1:
        Path(args[1]).write_text(md, encoding="utf-8", newline="\n")
    else:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stdout.write(md)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
