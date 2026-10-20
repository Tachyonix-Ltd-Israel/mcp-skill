---
description: Revisa uma aplicação do Tachyonix Builder que já existe contra o roteiro do Builder MCP e propõe as correções, sem gravar nada até o usuário aprovar.
argument-hint: [aplicacao]
---

Revise a aplicação do Tachyonix Builder abaixo com o conector Tachyonix Builder MCP, sem alterar nada até eu aprovar.

Aplicação: $ARGUMENTS

1. Localize-a (list_apps ou list_packages) e leia get_app_for_edit(resumo=true).
2. Confira os dados com run_backend_validation(preview=5).
3. Aponte o que foge do roteiro (get_guide): rótulos em inglês ou sem acentuação, formulário de detalhe sem grupos, agregação fora de uma Fonte de Dados, tabela standard no lugar da VDM, valor sem a moeda, filtro faltando.
4. Para cada ponto, proponha a ferramenta de edição (get_guide, tema tachyonix-edicao) e mostre o resultado com dry_run=true. Só grave depois da minha aprovação.

Se nada vier depois do comando no lugar de `aplicacao`, considere: (não informada: pergunte qual aplicação revisar)
