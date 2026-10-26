---
name: tachyonix-fonte-de-dados
description: Como criar uma Fonte de Dados do Tachyonix Builder pelo Builder MCP. Cobre a escolha do tipo (consulta, servico, cubo, analitica, api, api_rap, union, extrator), as fontes e os joins, os filtros, os campos calculados com agregação, o HAVING, valor com moeda e a conferência dos dados. Use quando o pedido for uma Fonte de Dados, uma consulta CDS, um total ou agregação, ou quando uma aplicação precisar de filtro ou agregação, que moram na fonte.
---

# Fonte de Dados

**A fonte é onde mora a regra dos dados: filtro, join e agregação.** A
aplicação só exibe o que a fonte entrega, e várias aplicações podem usar a
mesma fonte.

**Por que importa:** uma fonte sem filtro faz cada tela que a consome
carregar a tabela inteira, e agregação de verdade (GROUP BY) só existe na
fonte.

## 1. Escolha o tipo

| `tipo` | Para quê | Observação |
|---|---|---|
| `servico` | a escolha comum: CDS **com** serviço OData | o `preview` traz as linhas direto da fonte |
| `consulta` | CDS **sem** serviço próprio, só para ser consumida | `run_backend_validation` devolve `cdss: []`: confira na aplicação que a usa |
| `cubo` / `analitica` | análise: a agregação vira anotação `@Aggregation.default` | a analítica tem fórmulas próprias (`analitico` no calculado) |
| `api` | API OData com métodos ABAP (`metodos_api`) | os includes podem nascer depois |
| `api_rap` | manutenção de tabela por objetos RAP | só tabelas, só Association, até 4 fontes; `prefixo_sap` obrigatório, até 5 |
| `union` | junta fontes com as **mesmas colunas, na mesma ordem** | um braço por fonte; sem filtro |
| `extrator` | extração ODP/CDC/Custom | exige `delta` |

O catálogo completo está em `list_component_types`.

## 2. Fontes e joins

- A fonte base vai em `tabela` (ou `fonte`, se for outra Fonte de Dados).
  Prefira a VDM standard e liberada (`I_PURCHASEORDERITEMAPI01` no lugar de `EKPO`).
- As outras fontes vão em `tabelas`, cada uma com o relacionamento:
  `[{tabela: 'EKPO', campos: [...], join: {tipo: 'inner', de: 'EKKO',
  condicoes: [{campo: 'EBELN'}]}}]`. `get_joins` diz a condição entre duas
  fontes. Join composto é uma condição por campo, nunca `AND` numa só.
- A condição também compara com um literal ou uma variável de sessão:
  `{campo: 'SPRAS', valor: 'P'}` ou `{campo: 'SPRAS', variavel: 'sy-langu'}`.
  É assim que entra a tabela de texto (MAKT, T161T…): LEFT JOIN, com o idioma
  na própria condição, para o texto ausente não derrubar a linha nem
  multiplicá-la.
- Uma fonte pode nascer sobre outra Fonte de Dados: `fonte=<NomeSAP>`. É a
  cadeia de análise — o cubo sobre a consulta base, a analítica sobre o cubo —,
  criada em série, cada uma depois de a anterior existir.
- `campos` aceita o nome nu (da fonte base) ou qualificado (`EKPO.MENGE`).
- A mesma fonte duas vezes (pedido e contrato) é um *self-join*: dê `alias`
  à segunda ocorrência e cite-a pelo alias.
- Fonte parametrizada: `parametros=[{parametro, valor, expor?}]`, com um
  valor para **cada** parâmetro que ela declara.

## 3. Filtros

- `filtros=[{tabela, campo, operador, valor}]` é o WHERE da fonte. O
  primeiro é sempre WHERE; `grupo` faz parênteses e `concatenador` liga os
  demais. Operadores e variáveis de sessão em `list_query_options`.
- Filtro por **parâmetro** só existe na Fonte de Dados; o parâmetro LOCAL que
  o expõe nasce sozinho.
- `filtro_especialista` é o texto cru do WHERE, com ponto (`EKKO.BSART <>
  'NB'`), nunca `~`. Ele não se mistura com `filtros`.
- Confira com o usuário o recorte (empresa, tipo de documento, período):
  "sem filtro" raramente é o que ele quer.
- **SELECT × SELECT DISTINCT** (`tipo_select`): a fonte nasce com `SELECT`,
  como o Builder. Com DISTINCT o cubo deduplica as linhas antes de agregar e
  subconta; só peça `SELECT DISTINCT` quando a repetição for indesejada e não
  houver medida.

## 4. Campos calculados e agregação

**Toda consulta com agregação (soma, média, contagem, máximo, mínimo) é uma
Fonte de Dados com a agregação; a aplicação usa essa fonte.** Só a fonte gera
o GROUP BY: a mesma agregação numa aplicação grava, mas devolve o valor de
cada linha.

`campos_especiais=[{tipo: 'calculado', nome: 'TOTAL', descricao: 'Valor
total', formula: 'EKPO.NETWR', agregacao: 'SUM'}]`. As colunas que não são
agregadas viram o agrupamento (por fornecedor, por material…). Regras que o
gerador de CDS cobra:

- **O MCP envelopa a agregação** (`SUM( <fórmula> )`): escreva só a fórmula.
- **Contagem é `COUNT_DISTINCT`**, não `COUNT`.
- **Média** (`AVG`) leva o tipo do resultado; o MCP põe `AS abap.dec(23,2)`
  quando a fórmula não traz um.
- **Divisão nunca com `/`**: use `DIVISION(a, b, casas)` ou `DIV(a, b)`. A
  barra só funciona em FLTP e o resto volta 400 sem texto.
- **Agregação e CASE não convivem na mesma fonte `servico`/`consulta`**: o
  CASE não entra no GROUP BY. Agregue na fonte e faça o CASE na aplicação,
  ou use `cubo`/`analitica`.
- Função fora do construtor visual (`dats_tims_to_tstmp`…) só com
  `modo: 'especialista'`, que vai verbatim para o CDS.

**HAVING** (`having`) só existe na fonte, fora do cubo e da analítica:
`[{campo: 'QTD_ITENS', operador: '>=', valor: 2}]`, com `campo` = um
calculado que tem `agregacao`. Dentro do agregado só uma coluna (sem `cast`)
e o valor é numérico.

## 5. Valor com moeda, quantidade com unidade

- Referência na **mesma fonte** (`EKKO.NETWR` e `EKKO.WAERS`): o MCP traz a
  coluna de moeda junto e grava.
- Referência em **outra fonte** (`EKPO.NETWR` aponta `EKKO.WAERS`): a coluna
  não grava. O caminho é a VDM standard, que publica o valor com a moeda. Se
  o número sem moeda basta, use um calculado `modo: 'especialista'` com
  `cast( EKPO.NETWR as abap.dec(15,2) )`, mas **pergunte antes**: a coluna
  deixa de ser valor monetário.
- Somar valor monetário depende de como o sistema gera o CDS (o
  `env_info` mostra o release):
  - **S/4HANA 2022 em diante** (view entity): o cast vai dentro da
    agregação, `formula='cast( EKPO.NETWR as abap.dec(15,2) )'` com
    `agregacao='SUM'`; a coluna nua volta 400.
  - **1909 a 2021** (view clássica): agregue a coluna direto,
    `formula='EKPO.NETWR'` com `agregacao='SUM'`, sem cast; ponha a coluna de
    moeda na fonte para separar os totais por moeda. Ali, dentro do agregado
    só cabe a coluna: cast, conta e função voltam 400. Conta sobre a coluna
    se faz numa fonte anterior, que a expõe, e esta agrega (fonte sobre
    fonte).
  O build já aplica a regra do sistema e recusa o que não grava.

## 6. Crie e confira

1. `plan_component(tipo='servico', ...)` ou `create_component(...,
   plan=true)`: leia impedimentos e decisões pendentes.
2. Pergunte o destino e o nome técnico (`nome_sap`, prefixo Y).
3. `create_component(tipo=..., descricao=..., nome_sap=..., guid_pacote=...,
   transporte=..., tabela=..., campos=..., filtros=..., campos_especiais=...)`.
4. `run_backend_validation(guid, preview=5)`: num `servico`, as linhas vêm da
   própria fonte. Mostre-as e confira o recorte e os totais.
5. A aplicação vem depois, com `fonte=<NomeSAP desta fonte>` (tema
   `tachyonix-aplicacao`).
