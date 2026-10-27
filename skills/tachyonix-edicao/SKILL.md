---
name: tachyonix-edicao
description: Como alterar uma aplicação do Tachyonix Builder que já existe, pelo Builder MCP, sem corrompê-la. Mapeia cada mudança (colunas, filtros, joins, campos calculados, rótulos, lista principal, estruturas, ações, layout) para a ferramenta específica e explica dry_run, o resumo de leitura e por que update_app_full é o último recurso. Use sempre que o pedido for mudar, corrigir, traduzir ou reorganizar uma aplicação ou Fonte de Dados já gravada.
---

# Editar uma aplicação que já existe

**Diga o que muda, não reenvie a aplicação.** Cada mudança tem uma ferramenta
que recebe o `guid` e uma spec curta, lê a aplicação, aplica a mesma regra da
criação e regrava com as identidades preservadas.

**Por que importa:** regravar o payload inteiro é o caminho que corrompe a
aplicação em silêncio. Um campo com o GUID errado, ou uma coleção de outra
leitura, e a estrutura perde os campos.

## 1. Inspecione antes

- `get_app_for_edit(guid, resumo=true)`: o inventário (estruturas, aliases,
  tabelas, ações) em poucos KB. **Não serve para regravar.**
- `get_source_fields(fonte, campos=[...])` para conferir um campo novo.

## 2. Qual ferramenta

| Quero… | Ferramenta |
|---|---|
| acrescentar, remover ou mover colunas (inclusive de uma fonte nova, com `fontes` + `joins`) | `update_app_columns` |
| mudar filtros, joins ou o filtro especialista da etapa Dados | `update_app_query` |
| acrescentar campo calculado, case, referência ou função | `add_app_fields` |
| redefinir um campo especial que já existe | `update_app_special_fields` |
| rótulo, tipo de entrada, saída, unidade, navegação, comportamentos de um campo | `configure_app_fields` |
| traduzir estruturas, tabelas e botões | `update_app_fields` (`struct_patches`, `table_patches`, `acao_patches`) |
| contador, atualização, colunas ocultas, filtro de coluna, ordenação da lista | `configure_main_list` |
| configurar Tabela, Editor, Anexo, formulário de detalhe, grupo ou Process Flow | `configure_app_structure` |
| acrescentar ou remover Tabela, sub-tela, Linha do Tempo, Cabeçalho, anexos | `add_app_structures` / `remove_app_structures` |
| configurar ou acrescentar botões | `configure_app_actions` |
| organizar o formulário de detalhe por assunto — com títulos; painel ou aba só se o usuário pedir, e entre os dois o painel | `layout_app_form` |
| trocar painéis ou abas por títulos | `remove_app_structures(paineis=[...])` e depois `layout_app_form`, juntos em `update_app_batch` |
| título, descrição, ícone, tile, vigência | `update_app` |
| fazer uma cópia | `copy_app` |
| **várias das mudanças acima na mesma aplicação** | `update_app_batch` |

## 3. Como chamar

1. **Simule primeiro**: quase todas aceitam `dry_run=true`, que devolve o que
   seria gravado sem tocar em nada.
2. **Grave** a mesma chamada sem `dry_run`.
3. **Confira**: `run_backend_validation(guid, preview=5)`. Mudança na consulta
   (fonte nova, join, filtro) muda as linhas: confira as contagens.

**Mais de uma mudança? Junte num lote.** Cada ferramenta regrava a aplicação
inteira, e numa aplicação de várias telas isso leva de 30 a 75 segundos.
`update_app_batch(guid, passos=[{tool, args}, ...])` roda as mesmas ferramentas
em sequência, cada uma vendo o resultado da anterior, e grava uma vez só. Os
`args` de cada passo são os que a ferramenta recebe sozinha, sem `guid`.
Se um passo é recusado, nada é gravado e a resposta diz qual foi. Não entra no
lote `update_app_fields`; o rótulo de campo, ali, é `configure_app_fields`
com `rotulos`.

## 4. O que não fazer

- **Não use o `resumo` para regravar** nem monte o payload à mão.
  `update_app_full` é o último recurso, e só com o payload **completo** de
  `get_app_for_edit` (sem `resumo`).
- **Não guarde GUID de campo entre gravações**: todo save regera os
  `GuidCampo`. Leia de novo imediatamente antes de usar.
- **Não apague**: aplicação não se exclui pelo conector. `deactivate_app`
  inativa e `activate_app` volta; as duas exigem `confirm=true`.

## 5. Se a gravação falhar

A resposta de uma escrita que falha sobre aplicação existente traz
`mensagens_do_gerador`, com o texto do gerador de CDS. Leia antes de tentar de
novo (tema `tachyonix-diagnostico`). Uma gravação que falha não muda a
definição da aplicação, mas o gerador remove os serviços dela antes de
recriar. O MCP regrava sozinho a versão que estava gravada, e `restauracao`
diz se os serviços voltaram; com `restaurada: false`, a aplicação fica sem
serviços até a próxima gravação boa.
