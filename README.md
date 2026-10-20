# Tachyonix Builder

<!-- GERADO por scripts/gera_plugin.py a partir de src/tachyonix_mcp/data/roteiro/
     e de skills_do_plugin/. Não edite aqui: edite a fonte e regere. -->

O roteiro de trabalho do conector **Tachyonix Builder MCP**: em que ordem
criar e editar aplicações e Fontes de Dados do Tachyonix Builder no SAP S/4, o
que perguntar ao usuário antes de gravar e qual ferramenta do conector usar em
cada passo.

**Por que importa:** o conector tem as ferramentas; sem o roteiro, o agente
descobre as regras do Builder uma por vez, e cada descoberta custa uma
gravação.

É preciso ter o **Tachyonix Builder** e o conector Tachyonix Builder MCP
instalados no seu sistema SAP: o plugin ensina o agente a usá-los, não os
substitui.

## Instale

- **Claude Code:**

  ```
  /plugin marketplace add Tachyonix-Ltd-Israel/mcp-skill
  /plugin install tachyonix-builder@tachyonix
  ```

- **claude.ai e Cowork:** o zip deste repositório (*Code › Download ZIP*) em
  *Customize › Plugins › Add › Upload plugin*. Um Owner pode deixá-lo instalado
  para a organização.
- **Outros agentes** (Codex, Cursor, Gemini CLI e os demais que carregam Agent
  Skills): copie as pastas de `skills/` para a pasta de skills do agente.

## Use

1. **Registre o conector** do seu sistema: peça ao agente *"configure o Builder
   MCP aqui"*. A skill `tachyonix-configuracao` conduz o registro, e no Windows
   o script dela faz tudo de uma vez, sem a senha passar pela conversa:
   `skills/tachyonix-configuracao/scripts/configurar-builder-mcp.ps1`. O plugin
   não traz conector: há um por sistema, cada um com a sua credencial.
2. **Peça como pediria a um consultor** ("crie um relatório de pedidos de compra
   com tela de detalhe"). As skills entram sozinhas quando o pedido é do
   Tachyonix.

## Skills

| Skill | Para quê |
|---|---|
| `tachyonix-builder` | Roteiro de trabalho do Tachyonix Builder MCP. |
| `tachyonix-aplicacao` | Como criar uma aplicação do Tachyonix Builder pelo Builder MCP. |
| `tachyonix-diagnostico` | Como diagnosticar uma falha do Tachyonix Builder MCP. |
| `tachyonix-edicao` | Como alterar uma aplicação do Tachyonix Builder que já existe, pelo Builder MCP, sem corrompê-la. |
| `tachyonix-especificacao` | Como ler uma especificação (EF) e transformá-la nas chamadas do Tachyonix Builder MCP. |
| `tachyonix-fonte-de-dados` | Como criar uma Fonte de Dados do Tachyonix Builder pelo Builder MCP. |
| `tachyonix-configuracao` | Como registrar o conector Tachyonix Builder MCP neste agente e conferir que ele lê e grava. |

A pasta `skills/` está no formato padrão de Agent Skills e serve também a
outros hosts (Hub, Codex, Cursor) que carregam skills de pasta.

## Commands

| Command | O que faz |
|---|---|
| `/tachyonix-builder:construir-de-especificacao` | Constrói no Tachyonix Builder o que uma especificação (EF) descreve — relatório, ação, Fonte de Dados ou painel —, a partir de um .docx, .md ou lote .zip, seguindo o roteiro do Builder MCP: ler sem perder as tabelas, mapear a EF, Fonte de Dados primeiro, todas as perguntas de uma vez e entrega com as divergências. |
| `/tachyonix-builder:fonte-de-dados` | Cria uma Fonte de Dados do Tachyonix Builder (consulta CDS com filtros, joins e agregações) seguindo o roteiro do Builder MCP, pronta para ser usada por uma ou mais aplicações. |
| `/tachyonix-builder:revisar-aplicacao` | Revisa uma aplicação do Tachyonix Builder que já existe contra o roteiro do Builder MCP e propõe as correções, sem gravar nada até o usuário aprovar. |

## Dados

O plugin é só texto (skills e commands): ele não envia nada. Quem fala com o
SAP é o conector Tachyonix Builder MCP, com a credencial que você registrou.

O mesmo roteiro está no próprio conector, para os agentes sem plugin: a tool
`get_guide`, os resources `skill://<tema>/SKILL.md` e os prompts MCP. A
exceção é `tachyonix-configuracao`, que só o plugin traz: ela serve antes de o
conector existir.

Este conteúdo é gerado a partir do repositório do produto: correções e
sugestões entram por issue, não por pull request.
