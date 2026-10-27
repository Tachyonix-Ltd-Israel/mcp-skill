---
description: Constrói no Tachyonix Builder o que uma especificação (EF) descreve — relatório, ação, Fonte de Dados ou painel —, a partir de um .docx, .md ou lote .zip, seguindo o roteiro do Builder MCP: ler sem perder as tabelas, mapear a EF, Fonte de Dados primeiro, todas as perguntas de uma vez e entrega com as divergências.
argument-hint: [especificacao]
---

Construa no Tachyonix Builder o que a especificação abaixo descreve, com o conector Tachyonix Builder MCP.

Especificação: $ARGUMENTS

Siga o roteiro do conector (get_guide, tema tachyonix-especificacao):
1. Abra o documento sem perder as tabelas: prefira o .md gêmeo; se só houver .docx ou um .zip, use o conversor do tema (get_guide com arquivo='scripts/docx_para_md.py').
2. Diga que tipo de EF é (de negócio, técnica, híbrida ou painel) e monte o mapa: artefatos na ordem de criação, fontes e joins, estruturas e campos, controles, agregações, gráficos, ações, filtros e aceite.
3. Se houver total, média ou contagem, a agregação mora numa Fonte de Dados, criada antes.
4. Planeje cada artefato com create_component(plan=true) e me faça todas as perguntas de uma vez: o destino neste ambiente (o pacote e as ordens da EF podem ser de outro sistema) e o que a EF deixou em aberto.
5. Crie na ordem da EF, com rótulos em português e layout_formulario na tela de detalhe (separada por títulos; painel ou aba só se a EF pedir).
6. Confira com run_backend_validation(preview=5) e me entregue o nome técnico, o GUID, os links e a lista do que divergiu da EF e por quê.
Se algo falhar, leia mensagens_do_gerador antes de tentar de novo.

Se nada vier depois do comando no lugar de `especificacao`, considere: (não informada: peça a especificação antes de começar)
