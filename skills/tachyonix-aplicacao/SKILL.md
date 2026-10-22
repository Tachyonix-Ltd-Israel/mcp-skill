---
name: tachyonix-aplicacao
description: Como criar uma aplicação do Tachyonix Builder pelo Builder MCP. Cobre relatório (com ou sem tela de detalhe e drill), aplicação de ação, os formulários (cadastro, atualização de tabela, customizada, cabeçalho), Modelless, Lista de Trabalho e Entrada, além das perguntas obrigatórias, das colunas e filtros quando o pedido não os define, do layout do formulário, dos rótulos em português, das saídas e da navegação. Use quando o pedido for uma tela, um relatório, um formulário ou uma aplicação de aprovação no Tachyonix.
---

# Aplicação

**A aplicação é a tela; os dados vêm de uma Fonte de Dados.** Monte-a sobre a
fonte (`fonte=<NomeSAP>`), não direto sobre a tabela standard.

**Por que importa:** filtro e agregação moram na fonte (tema
`tachyonix-fonte-de-dados`); a aplicação sobre a fonte herda o recorte e
continua leve.

**Pediu total, média, contagem, máximo ou mínimo? Crie primeiro a Fonte de
Dados com a agregação e monte a aplicação sobre ela** — ou ligue a fonte pela
chave, quando o total vai ao lado do documento (ver "Fonte só na consulta"). Não use `agregacao`
num campo da aplicação: ali ela não gera GROUP BY, e cada linha mostra o
próprio valor no lugar do total.

## 1. Escolha o tipo

| `tipo` | Tela |
|---|---|
| `relatorio` | lista, opcionalmente com tela de detalhe e drill |
| `acao` | lista com botões de decisão (nasce com Aprovar e Reprovar) |
| `formulario_cadastro`, `atualizacao_tabela`, `aplicacao_customizada`, `cabecalho` | formulários (nascem com Incluir, Editar e Excluir) |
| `modelless`, `lista_trabalho` | os dados vêm de includes ABAP, não de consulta |
| `entrada` | formulário de entrada de dados |

## 2. As perguntas que não têm default

Faça-as de uma vez, junto com as `decisoes_pendentes` do plano:

- **Destino**: pacote Tachyonix (`list_packages`) e `transporte`
  `'local'`/`'transportavel'`; se transportável, `pacote_sap`,
  `request_work` e `request_cust` (as **tasks** de `list_transport_options`,
  não a request pai).
- **Tela de detalhe**, em relatório: `tela_detalhe=true` (lista + formulário
  de detalhe) ou `false` (só a lista).
- **Nome técnico e título**: `nome_sap` (Y, maiúsculas, até 29) e `descricao`
  em português.

## 3. Monte a tela

- **Campos**: `campos=[...]` (nome nu ou `FONTE.CAMPO`). Sem `campos`, o MCP
  põe na tela todos os campos utilizáveis da fonte e devolve em
  `campos_descartados` o que ficou fora e por quê — por isso, se o pedido
  não diz as colunas, escolha-as você (seção 4).
- **Rótulos em português**: `rotulos={CAMPO: 'Rótulo'}` sempre que o texto do
  dicionário vier em inglês ou longo demais.
- **Formulário de detalhe organizado**: em toda tela de detalhe nova, passe
  `layout_formulario={grupos: [{titulo: 'Identificação', campos: [...]},
  ...], campos_ocultos: [...]}`, com 4 ou 5 campos por grupo. Chave e
  obrigatório não se ocultam.
- **Outras tabelas e drill**: `tabelas=[{tabela, campos, join, dentro_de?}]`.
  Sem `dentro_de` a tabela fica no detalhe da lista; com `dentro_de` ela
  nasce no detalhe de outra tabela (pedido → itens → material). O detalhe da
  linha que nasce junto mostra, por padrão, os campos da tabela nova; para o
  detalhe do item, passe `formulario_campos` qualificado pela fonte da
  Tabela-pai (`['EKPO.EBELP', 'EKPO.MATNR']`).
- **Fonte só na consulta**: entrada de `tabelas` sem `campos` entra na etapa
  Dados sem virar grade. É o caso da tabela de texto (LEFT JOIN com
  `{campo: 'SPRAS', valor: 'P'}`) e da Fonte de Dados que traz o total por
  documento. A coluna dela aparece numa estrutura como calculado:
  `{tipo: 'calculado', nome: 'LIFNR_TXT', formula: 'LFA1.NAME1', em:
  'MAIN_LIST'}`.
- **Ordenação**: `ordenacao=[{campo, direcao: 'desc'}]`.
- **Lista Principal**: `main_list` (contador, atualização, variante de tela…;
  catálogo em `list_main_list_options`) e `filtros_lista` para o filtro de
  cada coluna.
- **Saídas** (microcharts, status, ícone, avatar): `saidas=[{campo, tipo,
  ...}]`, catálogo em `list_output_types`. Ícone e imagem exibem o **valor**
  do campo: ele tem de conter `sap-icon://…` ou uma URL.
- **Campos especiais** (calculado, case, referência, função):
  `campos_especiais`, catálogo em `list_field_types`.
- **Navegação** para outra aplicação ou URL: `navegacoes`, só em campo Label
  (`list_navigation_options`).
- **Ações**: o padrão do tipo nasce sozinho; `acoes=[...]` acrescenta botões
  e liga include, função ou navegação a cada um. `acoes=[]` nasce sem ação.
- **Formulários (TT=4)**: o tipo de cada campo de entrada (lista, ajuda de
  pesquisa, componente) vai em `entradas` (`list_input_types`).

## 4. Colunas e filtros que o pedido não definiu

**No máximo 6 colunas por tabela e de 1 a 3 filtros visíveis na Lista
Principal.** Vale quando o pedido não diz quais colunas ou filtros quer; o
que o usuário (ou a especificação) definir vale como ele definiu.

**Por que importa:** sem `campos`, a tela nasce com todos os campos da fonte
e a lista passa a rolar para o lado; sem filtro visível, a barra de filtros
nasce vazia e o usuário não tem como recortar a lista.

- **Quais 6**: as que identificam e resumem a linha — o documento ou a
  chave, a descrição ou o nome, a data, o status, o parceiro e o valor. A
  moeda ou a unidade de um valor entra junto e conta nas 6.
- **Relatório com tela de detalhe**: o detalhe espelha os campos da lista.
  Passe em `campos` tudo o que o detalhe deve mostrar e esconda na lista o
  que passar de 6 com `main_list={colunas_ocultas: [...]}`; o detalhe se
  organiza por `layout_formulario`. Sem tela de detalhe, passe só as 6.
- **Cada Tabela** (`tabelas[].campos`): até 6 colunas. Se ela abre o
  detalhe da linha (outra Tabela nasce `dentro_de` dela), os campos desse
  detalhe vão em `formulario_campos`.
- **Os filtros**: `filtros_lista=[{campo, visibilidade: 'visivel'}]` em 1 a 3
  colunas visíveis da Lista Principal — as que o usuário usaria para
  recortar a lista: data, status, empresa ou centro, fornecedor ou cliente.
  Não confunda com `filtros`, o recorte fixo da consulta.
- **Diga o que escolheu** no resumo da criação: o usuário troca depois com
  `configure_main_list` (`colunas_ocultas`, `filtros_lista`) ou
  `update_app_columns`.

## 5. Valor com moeda

Campo CURR/QUAN precisa da coluna de moeda/unidade na **mesma estrutura**; o
MCP a inclui quando ela é da mesma fonte. Referência em outra tabela não
grava como coluna: prefira a VDM standard ou a Fonte de Dados que já traz o
valor com a moeda.

## 6. Crie e confira

1. `create_component(..., plan=true)` com a spec completa: confira
   `plano.estruturas`, os campos e os impedimentos.
2. Com as respostas do usuário, `create_component(...)` sem `plan`.
3. `run_backend_validation(guid, preview=5)`: mostre algumas linhas, o
   `nome_sap`, o GUID e os links `runtime_url` (a aplicação) e `builder_url`
   (a aplicação no Builder).
4. Se o resultado pedir ajuste, siga o tema `tachyonix-edicao` em vez de
   recriar.
