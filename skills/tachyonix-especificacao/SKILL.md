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
| "exclusivamente em linguagem de negócio", "nenhum nome técnico" | EF de negócio | descubra as fontes: `search_sap_objects` (termo em português; leia `entidades`, a tabela e a VDM de cada uma), `search_cds_views`, `get_source_fields(campos=[...])`; os controles saem do vocabulário (§4) |
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

Duas fontes de informação antes do mapa:

- **A EF técnica gêmea**, quando existe (o mesmo nome noutra pasta, às vezes
  com o sufixo `_MCP`): ela nomeia o que a EF de negócio só descreve — as datas
  da linha do tempo, os valores e as cores dos selos, as séries dos
  microcharts, as tabelas de texto e o calendário. Use-a como intenção; se ela
  prescreve tabela física e a VDM serve, traduza com `map_source_fields`.
- **O que já está construído**: `list_packages(guid_pacote=<destino>)` e os
  subpacotes dele. Aplicação que já existe se confere
  (`get_app_for_edit(resumo=true)`, `run_backend_validation(preview=3)`) e se
  edita; criar de novo com outro nome duplica. O plano avisa quando o pacote
  já tem uma parecida.

Mostre ao usuário o resumo — quantas fontes, aplicações e DataViews — e faça
de uma vez as perguntas que sobrarem (§7).

## 3.1 O plano é a saída do MCP, não um texto

**Planeje a cadeia inteira com `plan_chain`** antes de gravar o primeiro
objeto: a fonte de soma, a do cabeçalho, o cubo, a analítica e a aplicação, na
ordem, cada passo com os argumentos de `create_component`. O passo que cita a
fonte de um passo anterior a lê pela estrutura simulada, e por isso a
aplicação sobre uma fonte que ainda não existe recebe o mesmo plano de quem já
existe. O plano está pronto quando:

- todo passo volta `ok` — sem impedimento; os avisos estão lidos e decididos;
- toda VDM e todo campo da EF têm destino, ou uma decisão de ficar de fora;
- todo microchart de várias séries (`COLUMN`, `COMPARISON`, `DELTA`, `FLOW`)
  tem as séries em `dados`, e todo selo tem os valores e as cores;
- num painel, toda dimensão é a coluna de TEXTO (o nome, a descrição), e a
  base está no grão da medida (o item, quando a medida é do item);
- o que já existe no destino foi conferido (§3);
- nenhuma conclusão de uma sessão anterior virou regra sem ser medida de novo
  — o que falhou ontem pode ter sido o ambiente.

Guarde no plano a `chamada` de cada passo: é o que se executa, e é o que se
revisa.

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
| Avatar com iniciais | `AVATAR` (`exibir_como: 'iniciais'`) no campo do **nome** — as iniciais saem do valor do campo, e sobre um código o avatar mostra os dois primeiros dígitos |
| Ícone | `STATUS` fixo com o ícone da categoria (`sap-icon://…`): `ICON` mostra o **valor** do campo como ícone |
| Linha do tempo (num campo) | `FLOW` com as datas em `dados`, não a estrutura Linha do Tempo (`timelines`) |

Configuração de cada um em `list_output_types`. `COLUMN`, `COMPARISON`,
`STACKED`, `DELTA` e `FLOW` exigem as séries em `dados` (`[{titulo,
campo|valor}]`): sem elas o build recusa. Meta, teto e faixa "da área" sem
número (`<meta da área>`) são parâmetros: use a sugestão da EF ou pergunte, e
declare o valor usado.

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
| Coluna "Texto" ao lado do código, ou campo de outra fonte na Lista Principal | a fonte em `tabelas` sem `campos` e a coluna em `campos`, qualificada: `campos=['EBELN', 'LFA1.NAME1']` — entra na Lista Principal e no detalhe que a espelha, e o CURR/QUAN traz a moeda/unidade da mesma fonte junto |
| Chave S que o DDIC não marca (MATDOC) | `chaves_por_estrutura={NomeEstrutura: [...]}`; a P nunca tem chave |
| *(oculto)* | `main_list.colunas_ocultas` na M; `layout_formulario.campos_ocultos` na P |
| Seções do formulário de detalhe | `layout_formulario.grupos` com títulos (o `tipo` default); `tipo: 'painel'` só se a EF pedir painel ou grupo, `'tab'` só se pedir aba |
| Fonte agregada `…_SUM` | Fonte de Dados `servico` com `campos_especiais` de `agregacao` sobre a COLUNA pura, criada antes, com a coluna de moeda/unidade do valor nos campos dela (o build liga a moeda ao total); na aplicação, a fonte em `tabelas` **sem `campos`**, por LEFT OUTER JOIN pela chave do documento, e o total em `campos` qualificado (`campos=[..., 'YSUM.VALOR_TOTAL']`) — a moeda dela vem junto. Com `campos` na entrada de `tabelas` ela vira uma grade, não coluna da lista |
| `SUM(EKPO.NETWR)` sem a moeda na fonte | o build recusa: traga a moeda para a fonte. Se só o número basta e o sistema é 2022 ou mais novo (view entity), `formula: 'cast( EKPO.NETWR as abap.dec(15,2) )'`, `modo: 'especialista'`; o total sai sem moeda — declare. No 1909 o cast DENTRO da agregação volta 400 (`SDDL_PARSER_MSG/376`) |
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
  de ao menos um campo chave, como toda Fonte de Dados. Na base:
  - o **grão é o da medida**: valor e quantidade do item pedem a base no item,
    com o cabeçalho juntado — não o cabeçalho com uma fonte de soma ao lado;
  - **cada recorte com o seu texto** ("nome, nunca código"): a fonte de texto
    juntada com o idioma (`{campo: 'LANGUAGE', variavel: 'sy-langu'}` ou o
    literal da EF), e a coluna de texto é a dimensão — o Charts não liga
    código a texto;
  - o **calendário corporativo** que a EF cita é uma tabela do cliente:
    procure-a (`search_sap_objects(term='calendar', environment=...)` — a
    descrição de tabela custom costuma estar em inglês) e junte-a pela data do
    fato; sem ela, `I_CALENDARDATE` (ano, trimestre, mês e ano-mês). Não
    calcule mês, bimestre ou semestre com fórmula numa fonte que agrega.
  - **No cubo**, a soma de valor/quantidade é a COLUNA pura com a moeda ou a
    unidade dela entre as dimensões, como na fonte. Ranking (Top N) só a
    analítica faz.
- **Sem o conector do Tachyonix Charts** nesta sessão: confira antes o
  `.mcp.json` do projeto, que pode registrá-lo. Se ele não existe mesmo,
  a estrutura V não se cria sozinha — pergunte ao usuário entre (a) criar a
  DataView no app Tachyonix Charts e depois pôr a V na tela por
  `add_app_structures(elementos=[{tipo: 'dataview', guid_consulta, calc}])`,
  ou (b) trocar o gráfico por um microchart numa grade (`saidas` com
  `tipo: 'COLUMN'` e as séries em `dados`), e declare a troca nas
  divergências.
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
- Antes de criar, confira se o nome já existe (o plano mostra a colisão) e o
  que já está no destino (§3): num lote, parte das EFs pode já estar
  construída.
- Um plano por EF (`plan_chain`), não um modelo de plano para o lote: o que é
  comum às EFs vale como checklist (§3.1), e o que é de cada uma — a VDM, os
  campos, as séries — só o plano dela confere.
- Uma gravação de cada vez, na ordem da EF; leia o motivo antes de repetir
  (tema `tachyonix-diagnostico`).

## 9. Entregue com as divergências

Para cada artefato: o nome técnico, o GUID, os links, algumas linhas de
`run_backend_validation(preview=5)` e a lista do que divergiu da EF e por quê
— cast no lugar do valor com moeda, controle trocado, campo que o ambiente
não tem, gráfico movido. Divergência não declarada é defeito escondido.
