---
name: tachyonix-aplicacao
description: Como criar uma aplicação do Tachyonix Builder pelo Builder MCP. Cobre relatório (com ou sem tela de detalhe e drill), aplicação de ação, os formulários (cadastro, atualização de tabela, customizada, cabeçalho), Modelless, Lista de Trabalho e Entrada, além das perguntas obrigatórias, das colunas e filtros quando o pedido não os define, do layout do formulário, dos rótulos em português, das saídas, da navegação e do Editor de Texto (como o include ABAP lê e grava o texto). Use quando o pedido for uma tela, um relatório, um formulário ou uma aplicação de aprovação no Tachyonix.
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
  obrigatório não se ocultam. Separe por **títulos** (seção 5).
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
- **Texto longo com formatação**: o Editor de Texto (`elementos`), que lê e
  grava por um include ABAP (seção 7).

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

## 5. Títulos, não painéis

**Separe os campos do formulário com títulos, no próprio formulário.** É o
`tipo` default de `layout_formulario`: cada grupo vira um título (o elemento
"Título" do menu "+") seguido dos campos dele.

**Por que importa:** painel e aba põem cada grupo numa caixa ou numa guia
própria. Ninguém pediu essa divisão, e ela pesa na tela: o usuário vê
"grupos" onde queria um formulário só, separado por assunto.

- **Painel ou aba só quando o usuário pedir.** Pediu painel ou grupo:
  `tipo: 'painel'`. Pediu aba: `tipo: 'tab'`. Nada disso no pedido: título.
- **Entre os dois, o painel.** Pediu "grupos" ou "painéis" sem dizer aba: é
  painel. `paineis` sem `layout` também cria painel; aba só com
  `layout: 'aba'`.
- **Numa aplicação que já existe**, `layout_app_form` com o mesmo objeto. Um
  campo que está num painel ou aba não vai para um título: tire o grupo
  antes com `remove_app_structures(paineis=[{em, painel}])` (os campos ficam
  no formulário) e aplique os títulos. Os dois passos cabem numa gravação só
  em `update_app_batch`.

## 6. Valor com moeda

Campo CURR/QUAN precisa da coluna de moeda/unidade na **mesma estrutura**; o
MCP a inclui quando ela é da mesma fonte. Referência em outra tabela não
grava como coluna: prefira a VDM standard ou a Fonte de Dados que já traz o
valor com a moeda.

## 7. Editor de Texto

**O Editor de Texto não lê nem grava o texto sozinho: quem faz isso é ABAP.**
`elementos=[{tipo: 'editor_texto', descricao: 'Observações', include:
'ZINC_OBSERVACOES'}]` cria a estrutura `OBSERVACOES` (tipo R) com o campo
`OBSERVACOES_RT`. O `include` é obrigatório e não precisa existir ainda: o
nome é livre, e o include se cria depois, no ABAP.

**Por que importa:** sem código no include, o editor abre vazio e o que o
usuário digita não é gravado. E o `<NOME>_RT` aparece como CHAR(1) na
consulta: o CDS não aceita STRING sem tamanho, mas o texto não passa pela
consulta, e o tamanho não o limita.

Como o texto anda:

1. O include gera uma **classe de determinação** (`<PREFIXO>CLDT…`), que o
   chama com `INCLUDE <include> IF FOUND`.
2. Na classe, o texto é `cv_data-<nome>-<nome>_rt`: o componente **dentro da
   subestrutura do editor**, `TYPE string`. O `<nome>_rt` do nível de cima é
   `c LENGTH 1`; não use esse.
3. **Leitura**: o include busca o texto na coluna STRING da tabela e preenche
   esse componente. O editor mostra o texto inteiro.
4. **Gravação**: o runtime não grava o editor. O include da ação
   (Incluir/Editar) recebe a mesma subestrutura e grava o texto na tabela.
5. O conteúdo é **HTML** (títulos, parágrafos, negrito, listas): grave e leia
   como veio.

**A classe muda de nome a cada geração da aplicação** (`…001`, `…002`), e um
include tipado pelo nome dela quebra na geração seguinte. Acesse os dados
por `ASSIGN COMPONENT`. Leitura, no include do editor (a chave `ID` vem do
formulário `MAIN_FORM`; o texto, da coluna `TEXTO` de `ZTABELA`):

```abap
ASSIGN COMPONENT 'MAIN_FORM' OF STRUCTURE cv_data TO FIELD-SYMBOL(<ls_form>).
ASSIGN COMPONENT 'OBSERVACOES' OF STRUCTURE cv_data TO FIELD-SYMBOL(<ls_editor>).
IF <ls_form> IS ASSIGNED AND <ls_editor> IS ASSIGNED.
  ASSIGN COMPONENT 'ID' OF STRUCTURE <ls_form> TO FIELD-SYMBOL(<lv_id>).
  ASSIGN COMPONENT 'OBSERVACOES_RT' OF STRUCTURE <ls_editor> TO FIELD-SYMBOL(<lv_texto>).
  IF <lv_id> IS ASSIGNED AND <lv_texto> IS ASSIGNED.
    SELECT SINGLE texto FROM ztabela INTO @<lv_texto> WHERE id = @<lv_id>.
  ENDIF.
ENDIF.
```

Gravação, no include da ação (`ls_registro` é a linha de `ZTABELA` que a
ação já grava):

```abap
ASSIGN COMPONENT 'OBSERVACOES' OF STRUCTURE cv_data TO FIELD-SYMBOL(<ls_editor>).
IF <ls_editor> IS ASSIGNED AND ( iv_action_name = 'ADD' OR iv_action_name = 'EDIT' ).
  ASSIGN COMPONENT 'OBSERVACOES_RT' OF STRUCTURE <ls_editor> TO FIELD-SYMBOL(<lv_texto>).
  IF <lv_texto> IS ASSIGNED.
    ls_registro-texto = <lv_texto>.
  ENDIF.
ENDIF.
```

O Editor de Texto não existe em relatório, Modelless nem Lista de Trabalho, e
na aplicação de ação é somente leitura. Numa aplicação que já existe ele entra
por `add_app_structures` e se reconfigura por `configure_app_structure`.

## 8. Crie e confira

1. `create_component(..., plan=true)` com a spec completa: confira
   `plano.estruturas`, os campos e os impedimentos.
2. Com as respostas do usuário, `create_component(...)` sem `plan`.
3. `run_backend_validation(guid, preview=5)`: mostre algumas linhas, o
   `nome_sap`, o GUID e os links `runtime_url` (a aplicação) e `builder_url`
   (a aplicação no Builder).
4. Se o resultado pedir ajuste, siga o tema `tachyonix-edicao` em vez de
   recriar.
