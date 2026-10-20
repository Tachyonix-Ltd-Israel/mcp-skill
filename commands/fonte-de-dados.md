---
description: Cria uma Fonte de Dados do Tachyonix Builder (consulta CDS com filtros, joins e agregações) seguindo o roteiro do Builder MCP, pronta para ser usada por uma ou mais aplicações.
argument-hint: [assunto]
---

Crie uma Fonte de Dados do Tachyonix Builder com o conector Tachyonix Builder MCP.

Assunto: $ARGUMENTS

Siga o roteiro do conector (get_guide, tema tachyonix-fonte-de-dados):
1. Ache a VDM standard do assunto (search_cds_views) e confira os campos (get_source_fields).
2. Pergunte-me o recorte (filtros), as colunas e se há total, média ou contagem: a agregação mora aqui na fonte, nunca na aplicação.
3. Planeje com create_component(plan=true) e me faça todas as perguntas de uma vez, inclusive o destino e o nome técnico.
4. Crie com tipo servico, ou o tipo que o plano indicar, e confira com run_backend_validation(preview=5).
5. Me diga o nome técnico da fonte: é o que a aplicação usa em fonte=.

Se nada vier depois do comando no lugar de `assunto`, considere: (não informado: pergunte o assunto antes de começar)
