---
name: tachyonix-builder
description: Roteiro de trabalho do Tachyonix Builder MCP. Diz a ordem para criar e editar aplicações e Fontes de Dados do Tachyonix Builder no SAP S/4, o que perguntar ao usuário e qual ferramenta usar em cada passo. Use antes do primeiro create_component, antes de editar uma aplicação que já existe e sempre que o pedido envolver relatório, formulário, aplicação de ação ou Fonte de Dados do Tachyonix.
---

# Roteiro do Tachyonix Builder MCP

**Planeje, pergunte, crie a fonte, depois a aplicação, e confira os dados.**
O conector tem as ferramentas; este roteiro diz em que ordem usá-las.

**Por que importa:** cada regra do Builder que aparece só na gravação custa um
build inteiro, e algumas decisões (o destino, a tela de detalhe) são do
usuário, não do agente.

## A ordem

0. **O pedido veio de uma especificação** (EF em .docx, .md ou um lote
   .zip)? Leia antes o tema `tachyonix-especificacao`: como abrir o arquivo
   sem perder as tabelas, o que a EF já decidiu e como cada item dela vira
   parâmetro.
1. **Confira o ambiente.** `env_info`: sistema, mandante e usuário. Na edição
   ABAP, se `escrita_disponivel` vier `false`, pare e avise: nada vai gravar.
2. **Ache a fonte pela VDM standard, não pela tabela.** `search_cds_views`
   (por termo ou por `tabela`), `get_source_info` e
   `get_source_fields(campos=[...])` para conferir só os campos que interessam.
   Tabela transparente é exceção justificada: campo que nenhuma view expõe,
   tabela Y*/Z*, ou a especificação que a prescreve — aí vale a especificação,
   e a VDM é mencionada uma vez, sem troca por conta própria. Termo de
   processo do cliente: `search_sap_objects`.
3. **Planeje antes de gravar.** `plan_component`, ou
   `create_component(plan=true)` quando houver campos especiais, tabelas,
   saídas ou layout. Leia `impedimentos`, `avisos` e `decisoes_pendentes`, e
   faça ao usuário **todas** as perguntas de uma vez.
4. **Pergunte o que é do usuário.** O destino: pacote Tachyonix
   (`list_packages`), `transporte='local'` ou `'transportavel'` e, se
   transportável, pacote ABAP, ordem de workbench e ordem de customizing
   (`list_transport_options` lista as tasks). Nunca assuma `$TMP` nem escolha
   o pacote. Em relatório, pergunte se ele quer tela de detalhe
   (`tela_detalhe`).
5. **Crie a Fonte de Dados primeiro.** Filtros, joins e agregações moram na
   fonte; a aplicação vem depois, com `fonte=<NomeSAP da fonte>`. Detalhe no
   tema `tachyonix-fonte-de-dados`.
   **Consulta com agregação (soma, média, contagem, máximo, mínimo) é sempre
   uma Fonte de Dados com a agregação, e a aplicação usa essa fonte** — como
   base (`fonte=`) ou, para pôr o total ao lado do documento, como mais uma
   fonte da consulta, ligada pela chave. Na aplicação a agregação não gera
   GROUP BY: o "total" sai linha a linha, com o valor da própria linha.
6. **Depois a aplicação.** Detalhe no tema `tachyonix-aplicacao`.
7. **Confira o que nasceu.** `run_backend_validation(guid, preview=5)` e
   mostre ao usuário algumas linhas, o nome técnico, o GUID e os links
   `runtime_url` e `builder_url`. Gravar não prova que a fonte traz o que se
   pediu.
8. **Se falhar, leia o motivo antes de tentar de novo.** Tema
   `tachyonix-diagnostico`. Não varie parâmetros às cegas.
9. **Para mudar depois, use a ferramenta específica.** Tema
   `tachyonix-edicao`. Regravar a aplicação inteira é o caminho que a
   corrompe.

## Regras que valem sempre

- **Nome técnico** (`nome_sap`): prefixo Y, maiúsculas, até 29 caracteres. A
  API RAP não tem nome: a identidade dela é o `prefixo_sap`, de até 5.
- **Português com acentuação** em tudo que o usuário lê: `descricao`,
  `rotulos`, estruturas e botões. O alias é identificador e fica sem acento;
  o rótulo não.
- **Só os parâmetros que a ferramenta declara.** Parâmetro desconhecido é
  recusado. O espaço de opções está nos catálogos `list_*`
  (`list_component_types`, `list_field_types`, `list_output_types`…).
- **Agregação só na Fonte de Dados.** Total, média, contagem, máximo e
  mínimo se calculam numa fonte (`campos_especiais` com `agregacao`); a
  aplicação exibe o resultado com `fonte=<NomeSAP da fonte>`.
- **Valor e quantidade levam a moeda e a unidade junto.** Campo CURR/QUAN
  precisa da coluna de referência na mesma estrutura. Se a referência mora em
  outra tabela, pergunte antes de converter o valor em número.
- **O conector não apaga aplicação**: `deactivate_app` a inativa. Peça
  confirmação antes do que não tem volta; as ferramentas destrutivas exigem
  `confirm=true`.
- **Ambiente**: na edição Python, `environment` vai em toda ferramenta que lê
  ou grava no sistema. Na edição ABAP o ambiente é o próprio sistema e o
  parâmetro não existe.

## O que não é deste conector

DataView, Dashboard e Analytics se criam no **Tachyonix Charts MCP**
(`create_dataview`, `create_dashboard`, `add_dashboard_card`,
`create_analytics`) ou no app Tachyonix Charts. Ficam aqui: os microcharts de
coluna (`saidas`, `list_output_types`), a estrutura V que aponta para uma
DataView existente (`list_dataviews`) e o `get_guid_cds` que o Charts pede.

## Os temas

| Tema | Leia quando |
|---|---|
| `tachyonix-fonte-de-dados` | for criar ou ajustar uma Fonte de Dados: tipo, filtros, joins, agregação, moeda |
| `tachyonix-aplicacao` | for criar relatório, ação, formulário, Modelless ou Entrada |
| `tachyonix-edicao` | a aplicação já existe e algo precisa mudar |
| `tachyonix-diagnostico` | uma gravação falhou ou o dado não veio como esperado |
| `tachyonix-especificacao` | o pedido vier de uma especificação (EF) ou de um lote delas |

Cada tema sai por `get_guide(tema='<tema>')` ou pelo resource
`skill://<tema>/SKILL.md`.
