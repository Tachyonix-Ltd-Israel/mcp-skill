---
name: tachyonix-especificacao
description: Como ler uma especificação (EF) e transformá-la nas chamadas do Tachyonix Builder MCP. Cobre abrir .docx, .md e lotes .zip sem perder as tabelas (com um conversor incluído), reconhecer o tipo de documento (EF de negócio, EF técnica, híbrida, painel analítico, anexo de controles), montar o mapa da EF, traduzir topologia, fontes, joins de texto, campos, controles visuais, fonte agregada, gráficos, ações e filtros para os parâmetros, separar o que a EF já decidiu do que ainda é do usuário e entregar com as divergências declaradas. Use sempre que o pedido vier de um documento de especificação, ou de um lote deles.
---

# Especificação (EF)

**Leia a EF inteira, monte o mapa e só então chame as ferramentas.** O roteiro
de construção continua sendo o de `tachyonix-builder`; este tema diz como
chegar da EF até ele.

**Por que importa:** a especificação mora nas tabelas — campo, alias, chave e
saída só fazem sentido lado a lado —, e cada engano de leitura só aparece no
build, um por vez.

## 1. Abra o arquivo sem perder as tabelas

- **Prefira o `.md` gêmeo** (o mesmo nome, outra pasta). Nas EFs técnicas o
  `.docx` gerado perdeu conteúdo: as condições de um join composto vêm coladas
  numa linha, e o texto entre `< >` (`valor_maximo=<parâmetro da área>, …`)
  some junto com o resto da célula.
- **Só `.docx`**: use o conversor deste tema, `scripts/docx_para_md.py`, que só
  usa a biblioteca padrão do Python. Pelo conector,
  `get_guide(tema='tachyonix-especificacao', arquivo='scripts/docx_para_md.py')`
  devolve o texto dele; grave-o e rode
  `python docx_para_md.py <arquivo.docx | pasta | lote.zip> [saída]`. Ele mantém
  as tabelas, separa as condições de join coladas e troca as aspas
  tipográficas (‘P’) pelas retas, que o CDS exige. Quando alguma célula
  parece truncada (`valor_maximo=, valor_alvo=`, uma chave aberta sem
  fechar), ele as lista no fim, em **Lacunas prováveis**: o valor que falta
  não está no `.docx` — pergunte-o ao usuário junto das decisões do plano.
- **Lote em `.zip`**: converta direto do zip. No Windows, nomes que só diferem
  na maiúscula (`…__Especificaco…` e `…__especificaco…`, a EF e a
  reexportação) se sobrescrevem ao extrair e um documento some; o conversor
  renomeia e avisa. Confira a contagem com o índice do lote (o manifesto).
- **Nunca use o texto achatado** (uma célula por linha). Se o host já converteu
  o anexo, confira que as tabelas vieram como tabela.

## 2. Reconheça o tipo do documento

| Sinal no documento | Tipo | Caminho |
|---|---|---|
| "exclusivamente em linguagem de negócio", "nenhum nome técnico" | EF de negócio | descubra as fontes: `search_sap_objects` (termo em português), `search_cds_views`, `get_source_fields(campos=[...])`; os controles saem do vocabulário (§4) |
| EF de negócio com o bloco "ESPECIFICAÇÃO TÉCNICA DA VERSÃO VIGENTE" | híbrida | use o bloco técnico: `TABELA-CAMPO` é `TABELA.CAMPO`, `A~X = B~X` é um join, e aliases como `VTOT_0` são calculados da versão anterior — o significado está na parte de negócio |
| "Parâmetros de execução" (§0), tabela de joins, uma tabela por estrutura | EF técnica | tradução direta (§5) |
| cadeia VDM → Cubo → Analítica → DataViews | painel analítico | §6 |
| "anexo técnico", de-para de controles | anexo | não é artefato: é o dicionário das EFs de negócio da mesma campanha |

## 3. Monte o mapa da EF antes de qualquer chamada

Uma linha por artefato, na ordem de criação que a EF declara: tipo, nome
técnico e descrição. Para cada um, anote:

- as fontes e os joins, condição por condição (campo × campo ou literal);
- as estruturas (M, P, T, V) com nível, pai e campos — `FONTE.CAMPO`, alias,
  chave, saída e se é oculto;
- as agregações (viram Fonte de Dados), os controles visuais, os gráficos, as
  ações, os filtros da tela, a ordenação e a autorização;
- o destino declarado, os critérios de aceite e as divergências que a EF já
  declara.

Mostre ao usuário o resumo — quantas fontes, aplicações e DataViews — e faça
de uma vez as perguntas que sobrarem (§7).

## 4. O vocabulário dos controles

| Na EF | `saidas[].tipo` |
|---|---|
| Selo colorido | `STATUS`, com a cor por valor do domínio |
| Barra-meta | `BULLET` |
| Duas barras comparadas | `DELTA` (exatamente duas séries) |
| Barras comparadas | `COMPARISON` |
| Mini-colunas | `COLUMN` |
| Rosca de participação | `HARVEY` |
| Medidor circular | `RADIAL` |
| Barra de progresso | `PROGRESS` |
| Avatar com iniciais | `AVATAR` (`exibir_como: 'iniciais'`) |
| Ícone | `STATUS` fixo com o ícone da categoria (`sap-icon://…`): `ICON` mostra o **valor** do campo como ícone |
| Linha do tempo (num campo) | `FLOW`, não a estrutura Linha do Tempo (`timelines`) |

Configuração de cada um em `list_output_types`. Meta, teto e faixa "da área"
sem número (`<meta da área>`) são parâmetros: use a sugestão da EF ou
pergunte, e declare o valor usado.

## 5. Da EF técnica para os parâmetros

| Na EF | No MCP |
|---|---|
| TipoTemplate 1 / 0 | `tipo='relatorio'` / `'acao'` |
| Fonte de Dados Consulta CDS, `Servico = true` / `false` | `tipo='servico'` / `'consulta'` |
| Tela de detalhe SIM (`ShowNavigation = S`) | `tela_detalhe=true` — a EF respondeu, não pergunte de novo |
| Topologia `M/P/T` | `tela_detalhe=true` e `tabelas=[{tabela, nome, campos, join}]` |
| `M/P/T/P/T` (drill) | a Tabela do 2º nível com `dentro_de` = `nome` da Tabela do 1º; a P do 2º nível nasce com ela, e os campos dela vão em `formulario_campos` qualificados pela fonte da Tabela-pai (`EKPO.EBELP`) |
| Estrutura V | `elementos=[{tipo: 'dataview', guid_consulta, calc, dentro_de?}]`, com a DataView já criada (`list_dataviews`) |
| Fonte "texto/descrição" por LEFTOUTERJOIN com literal de idioma | entrada de `tabelas` **sem `campos`** (entra só na consulta): `{tabela: 'T161T', join: {tipo: 'left', de: 'EKKO', condicoes: [{campo: 'BSTYP'}, {campo: 'BSART'}, {campo: 'SPRAS', valor: 'P'}]}}` |
| Coluna "Texto" ao lado do código, ou campo de outra fonte numa estrutura | `campos_especiais=[{tipo: 'calculado', nome: 'LIFNR_TXT', formula: 'LFA1.NAME1', em: 'MAIN_LIST'}]` — não vale para CURR/QUAN |
| Chave S que o DDIC não marca (MATDOC) | `chaves_por_estrutura={NomeEstrutura: [...]}`; a P nunca tem chave |
| *(oculto)* | `main_list.colunas_ocultas` na M; `layout_formulario.campos_ocultos` na P |
| Fonte agregada `…_SUM` | Fonte de Dados `servico` com `campos_especiais` de `agregacao`, criada antes; na aplicação, uma entrada de `tabelas` sem `campos`, ligada por LEFT OUTER JOIN pela chave do documento, e o total como calculado `formula: '<FONTE>.SUM_NETWR'` |
| `SUM(EKPO.NETWR)` com a moeda em outra tabela | não grava como está: `formula: 'cast( EKPO.NETWR as abap.dec(15,2) )'`, `modo: 'especialista'`. O total sai sem moeda — declare |
| CURR/QUAN com a moeda "oculta na mesma estrutura" vinda de OUTRA tabela (`EKPO.NETWR` com `EKKO.WAERS`) | o gerador recusa; o plano mostra `moeda_unidade.situacao`, e a saída é o cast ou a VDM. Referência da própria tabela (`EKPO.MENGE` com `EKPO.MEINS`) grava |
| Percentual | `DIVISION(a, b, casas)`, nunca `/` |
| Ações (§8) | `acoes=[{template, nome, descricao, icone, include, motivo, confirmar: {titulo, mensagem, ok, cancelar}, exibir_em, ao_executar, atualizar_apos_executar}]`; "nenhuma" é `acoes=[]` |
| Filtros visíveis, ordenação, autorização (§9) | `filtros_lista`, `ordenacao`, `autorizacao` (o campo do objeto tem de estar na M) |
| Filtros fixos (WHERE) | `filtros`, na fonte |

## 6. Gráficos e painéis: a ordem entre os conectores

- **Relatório com V**: (1) a fonte agregada; (2) a fonte dos gráficos
  (`…_DVS`); (3) as DataViews, no **Tachyonix Charts** (`create_dataview`,
  com o `guid_cds` da fonte, que `get_guid_cds` lê); (4) a aplicação, com cada
  V apontando a DataView por `guid_consulta` (`list_dataviews`); (5) a
  conferência.
- **Painel**: a Consulta CDS base → o Cubo (`tipo='cubo'`, `fonte=` a base) →
  a Analítica (`tipo='analitica'`, `fonte=` o cubo) → as DataViews e a
  Analytic View no Charts (`create_dashboard`) → o relatório companheiro. Em
  série, um de cada vez: cada um lê o anterior publicado. A analítica precisa
  de ao menos um campo chave, como toda Fonte de Dados.
- **SELECT × SELECT DISTINCT**: o painel pede o Cubo com `SELECT`, porque o
  DISTINCT subconta. É como toda Fonte de Dados nasce (`tipo_select`); não
  peça `SELECT DISTINCT` numa fonte com medida.

## 7. O que a EF decide e o que ainda é do usuário

- **A EF decide**: as fontes (tabela física quando ela prescreve — siga a EF e
  mencione a VDM uma vez só, sem trocar por conta própria), a topologia, a
  tela de detalhe, os campos, os controles e as ações.
- **Confirme no ambiente**: pacote (`GuidPacote`) e ordens vêm do sistema de
  quem escreveu e não existem em outro; `list_packages` e
  `list_transport_options` dão as opções, e o usuário escolhe. O nome técnico
  prescrito vale se estiver livre (o plano confere). O serviço de cadastro
  citado (`Y_KBS_CADASTRO_APP_SRV`) não vale: o conector é o caminho.
- **Regras citadas pela EF** (A-SEM-V, NAME-BUDGET-30, F-MCHART-SCALE-SUFFIX…)
  são do autor. Quem diz o que grava é o plano: siga a EF quando ele aceitar;
  quando recusar, use a saída que ele dá e declare.
- **Volumetria e aceite** foram medidos no ambiente do autor. Compare a forma
  (grão da lista, drill que filtra pela linha, total que bate com a soma dos
  itens), não o número. `run_backend_validation` confere os dois no serviço
  gerado: `contagem=true` dá o total de linhas de cada CDS, e
  `conferir_soma={total, itens, chave}` compara o total de um documento com
  a soma dos itens dele.
- **Tabela física prescrita, VDM disponível**: `map_source_fields(origem,
  destino, campos)` diz, campo a campo, o equivalente na VDM e o que ela não
  tem — é o que decide se a troca é viável antes de propô-la.

## 8. Lote de EFs

- Siga as famílias: a fonte agregada `…_SUM` é compartilhada entre o
  relatório e a ação da mesma versão — crie uma vez e reaproveite.
- Antes de criar, confira se o nome já existe (o plano mostra a colisão).
- Uma gravação de cada vez, na ordem da EF; leia o motivo antes de repetir
  (tema `tachyonix-diagnostico`).

## 9. Entregue com as divergências

Para cada artefato: o nome técnico, o GUID, os links, algumas linhas de
`run_backend_validation(preview=5)` e a lista do que divergiu da EF e por quê
— cast no lugar do valor com moeda, controle trocado, campo que o ambiente
não tem, gráfico movido. Divergência não declarada é defeito escondido.
