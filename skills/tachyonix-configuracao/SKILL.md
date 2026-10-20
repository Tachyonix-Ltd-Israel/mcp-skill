---
name: tachyonix-configuracao
description: Como registrar o conector Tachyonix Builder MCP neste agente e conferir que ele lê e grava. Cobre o script incluído para Windows (pede a senha fora do chat, testa a conexão antes de guardar, guarda a credencial numa variável do usuário e registra no Claude Code, Cursor, VS Code e Codex), o registro à mão nos outros agentes e sistemas, o claude.ai (pela tela de conectores) e o diagnóstico quando o conector não conecta, não grava ou some. Use quando o usuário pedir para instalar, configurar, conectar, testar ou consertar o Builder MCP ou o Tachyonix Charts MCP, ou para trocar a senha deles.
---

# Configurar o Builder MCP

**Você prepara; a senha, o usuário digita fora do chat.** O conector é uma URL
e dois cabeçalhos com a credencial SAP. O script desta skill cuida da
credencial e do registro; o seu papel é perguntar o que falta, entregar o
comando pronto e conferir no fim.

**Por que importa:** a linha `Basic …` dos cabeçalhos é a senha do usuário,
só codificada. Escrita na conversa, ela fica no histórico e vai para o
provedor do modelo; escrita num arquivo do projeto, vai para o Git.

## 0. A regra da credencial

- **Nunca peça a senha nem o Base64 na conversa**, e não os escreva em arquivo
  nenhum. Os registros citam a variável (`${TACHYONIX_MCP_ABAP_BASIC}`); quem a
  lê é o agente, ao conectar.
- **Se o usuário colar a senha na conversa**, não a use: diga que ela ficou no
  histórico e recomende trocá-la no SAP antes de seguir.
- **Não imprima a variável** para conferir (`echo`, `env`, `set`, `Get-ChildItem
  Env:`): quem confere é o teste do script ou o `env_info`.
- **Registro no perfil do usuário, nunca no do projeto.** O `.mcp.json`, o
  `.cursor/mcp.json` e o `.vscode/mcp.json` de um repositório vão para o Git.

## 1. Veja onde você roda

| Você é | Caminho |
|---|---|
| Agente na máquina do usuário: Claude Code, Codex, Cursor, VS Code com Copilot, Gemini CLI, Windsurf | §2, e então §3 (Windows) ou §4 (à mão) |
| Assistente na nuvem: claude.ai no navegador, no Desktop ou no celular | §5: o cadastro é na tela de conectores, e quem o faz é o usuário |

## 2. Pergunte o que não é segredo, de uma vez

1. **O endereço do sistema**: o mesmo com que o usuário abre o Builder,
   `https://host:porta` (por exemplo `https://s4t.empresa.com:44301`).
2. **O mandante** (`sap-client`), três dígitos.
3. **Quais sistemas.** É um servidor por sistema, e cada um ganha um nome,
   `tachyonix-<sistema>` (`tachyonix-s4t`).
4. **Se quer também o Tachyonix Charts MCP**, que cria DataView, Dashboard e
   Analytics. Ele fica no nó ao lado e usa a mesma credencial.

O usuário SAP e a senha, quem pergunta é o script, no terminal.

## 3. No Windows: o script

O script está nesta skill, em `scripts/configurar-builder-mcp.ps1`. Monte o
comando com as respostas e peça ao usuário que o rode **num terminal dele**
(PowerShell ou Windows Terminal), não pelo seu: o script pede a senha, e o
terminal do agente não aceita digitação — se você tentar, ele para e diz isso.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<pasta desta skill>\scripts\configurar-builder-mcp.ps1" -Endereco https://s4t.empresa.com:44301 -Mandante 100
```

- `-Charts` registra também o Charts MCP; `-Agentes claude-code,vscode` limita
  os agentes (sem ele, o script usa os que encontrar e pergunta); `-Nome` troca
  o nome do servidor.
- `-ExecutionPolicy Bypass` vale só para essa execução: é o que deixa rodar um
  script baixado sem mudar a política da máquina.
- **Se você não enxerga o arquivo** (só este texto foi anexado), use o §4.

O que ele faz, nesta ordem, para você explicar ao usuário e ler a saída com ele:

1. Pede o usuário SAP e a senha (que não aparece) e **testa antes de guardar**:
   abre a conversa MCP e chama `env_info` com os dois cabeçalhos. Senha errada
   não chega a ser gravada.
2. Guarda o Base64 em `TACHYONIX_MCP_ABAP_BASIC`, variável do usuário do
   Windows. Se ela já guarda outra credencial, pergunta se substitui ou se cria
   uma só deste sistema.
3. Registra o servidor em cada agente com a sintaxe dele e guarda uma cópia
   (`.bak-<data>`) de cada arquivo que altera. No Claude Code usa o próprio
   `claude mcp add`, no escopo do usuário, e define
   `CLAUDE_CODE_MAX_MCP_DESCRIPTION_LENGTH=20000` — sem ele, a descrição das
   ferramentas maiores chega cortada.
4. Mostra o resumo, agente a agente: registrado, atualizado, ou o bloco para
   colar à mão (num `mcp.json` com comentários, por exemplo, ele não mexe).

`-SoTestar` só confere a conexão com a credencial guardada, sem mudar nada.
Senha trocada no SAP: o mesmo comando de novo.

Depois, **o usuário fecha e abre o agente** — ele só enxerga a variável nova
depois de reiniciar —, e você segue o §6.

## 4. À mão: macOS, Linux, outro agente ou sem o script

**A credencial** o usuário cria no terminal dele; a senha não aparece:

```powershell
# Windows / PowerShell
$u = Read-Host 'Usuário SAP'; $s = Read-Host 'Senha SAP' -AsSecureString
$b = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${u}:" + [Net.NetworkCredential]::new('', $s).Password))
[Environment]::SetEnvironmentVariable('TACHYONIX_MCP_ABAP_BASIC', $b, 'User')
[Environment]::SetEnvironmentVariable('TACHYONIX_MCP_ABAP_AUTH', "Basic $b", 'User')   # só o Codex usa
```

```bash
# macOS / Linux: acrescenta ao ~/.zshrc (no bash, ~/.bashrc)
read -rp 'Usuário SAP: ' u; read -rsp 'Senha SAP: ' s; echo
b="$(printf '%s:%s' "$u" "$s" | base64 | tr -d '\n')"
printf "export TACHYONIX_MCP_ABAP_BASIC='%s'\nexport TACHYONIX_MCP_ABAP_AUTH='Basic %s'\n" "$b" "$b" >> ~/.zshrc
```

**O registro** você faz, no arquivo do perfil do usuário, acrescentando ao que
já existe e guardando uma cópia antes. A URL é sempre
`https://<host>:<porta>/sap/bc/tachyonix/mcp?sap-client=<mandante>&sap-language=PT`,
e os dois cabeçalhos, `Authorization` e `X-Tachyonix-Auth`, levam a mesma linha
`Basic <variável>`. A chave errada costuma ser ignorada em silêncio, e o
servidor nasce sem credencial:

| Agente | Onde | Lista · URL | Como cita a variável |
|---|---|---|---|
| Claude Code | `claude mcp add`, abaixo | escopo `user` | `${TACHYONIX_MCP_ABAP_BASIC}` |
| Cursor | `~/.cursor/mcp.json` | `mcpServers` · `url` | `${env:TACHYONIX_MCP_ABAP_BASIC}` |
| VS Code | `mcp.json` do perfil (comando *MCP: Open User Configuration*) | `servers` · `url`, com `"type": "http"` | `${env:TACHYONIX_MCP_ABAP_BASIC}` |
| Codex | `~/.codex/config.toml`, tabela `[mcp_servers.<nome>]` | `url` · `env_http_headers` | o NOME da variável com a linha inteira: `TACHYONIX_MCP_ABAP_AUTH` |
| Gemini CLI | `~/.gemini/settings.json` | `mcpServers` · **`httpUrl`** | `$TACHYONIX_MCP_ABAP_BASIC` |
| Windsurf | `~/.codeium/windsurf/mcp_config.json` | `mcpServers` · **`serverUrl`** | `${env:TACHYONIX_MCP_ABAP_BASIC}` |
| Claude Desktop | — | — | use o conector do claude.ai (§5) |

No Claude Code, rode você mesmo (Git Bash, macOS ou Linux); as aspas simples
fazem o `${…}` chegar literal ao registro, que o expande ao conectar:

```bash
claude mcp add --transport http --scope user tachyonix-s4t \
  'https://<host>:<porta>/sap/bc/tachyonix/mcp?sap-client=<mandante>&sap-language=PT' \
  --header 'Authorization: Basic ${TACHYONIX_MCP_ABAP_BASIC}' \
  --header 'X-Tachyonix-Auth: Basic ${TACHYONIX_MCP_ABAP_BASIC}'
```

e defina `CLAUDE_CODE_MAX_MCP_DESCRIPTION_LENGTH=20000` no ambiente do usuário.

- **Charts MCP**: o mesmo registro, com `/charts_mcp` no lugar de `/mcp` e o
  nome `tachyonix-charts-<sistema>`.
- **Outros agentes** (Zed, Cline, Roo Code, Kiro, Warp, JetBrains): a tabela
  completa está no documento *MCP e agentes de IA*, seção "Como registrar em
  cada agente".

## 5. claude.ai: o usuário cadastra na tela

Você não alcança a tela de conectores; guie o usuário, um conector por servidor:

1. *Configurações › Conectores › Adicionar conector personalizado*. Em Team e
   Enterprise, quem adiciona é o Owner, em *Configurações da organização ›
   Conectores*.
2. **URL pública** do sistema, com mandante e idioma. Quem chama é o claude.ai,
   de fora da rede da empresa: endereço interno e certificado não confiável não
   conectam.
3. **Sem login**: desligue o OAuth, ou o cabeçalho `Authorization` fica
   reservado.
4. **Dois cabeçalhos**, os dois com a linha inteira `Basic <base64>`:
   `authorization` e `x-app-key` (o claude.ai recusa o nome `X-Tachyonix-Auth`;
   `x-app-key` é o mesmo cabeçalho). Marque os dois como obrigatórios.

A linha para colar, o usuário gera no terminal dele, e ela vai direto para a
área de transferência, sem aparecer:

```powershell
$u = Read-Host 'Usuário SAP'; $s = Read-Host 'Senha SAP' -AsSecureString
'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${u}:" + [Net.NetworkCredential]::new('', $s).Password)) | Set-Clipboard
```

Depois de colar nos dois campos, ele copia outra coisa qualquer, para a senha
sair da área de transferência.

- **Sem a seção de cabeçalhos na tela**, a organização ainda não tem o recurso
  (em beta), e o conector não liga por esse caminho.
- **A credencial não se edita**: senha trocada é conector removido e cadastrado
  de novo.
- **Confira de quem é a credencial.** Num conector cadastrado pela organização,
  `env_info` pode mostrar o usuário de quem cadastrou, e então tudo é gravado
  em nome dessa pessoa.

## 6. Confira

Numa conversa nova, com o agente reiniciado, chame `env_info` e mostre ao
usuário:

| Campo | Tem de vir |
|---|---|
| `usuario` | o usuário SAP **dele** |
| `escrita_disponivel` | `true`: é o teste do segundo cabeçalho |
| `core_alcancavel` | `true` |
| `environment.sap_client` | o mandante pedido |
| `environment.base_url` | um endereço que o usuário abre no navegador: é dele que saem os links das aplicações |

O conector tem **65** ferramentas. Feche com um pedido real, só de leitura:
`list_packages`. Daí em diante o roteiro de trabalho vem do próprio conector,
pelo `get_guide`.

## 7. Quando não funciona

| Sintoma | Causa | O que fazer |
|---|---|---|
| "a execução de scripts foi desabilitada" | a política de execução do Windows | rode com `powershell -ExecutionPolicy Bypass -File …`, como no §3 |
| `401` | usuário, senha ou mandante errados | o usuário entra no Builder com o mesmo usuário para conferir e roda o script de novo |
| `404` | host, porta ou mandante errados, ou o nó não existe no sistema | confira o endereço do Builder; se estiver certo, o administrador cria o nó pelo report `/TACHYON/MCP_ICF_SETUP` |
| Erro de certificado ou de conexão | fora da rede (VPN), endereço errado ou certificado em que a máquina não confia | abra a URL no navegador da mesma máquina: ela tem de pedir senha, com o cadeado fechado |
| Lê, mas não grava (`escrita_disponivel: false`) | falta o `X-Tachyonix-Auth` (no claude.ai, `x-app-key`), ou o valor difere do `Authorization` | confira os dois cabeçalhos; com os dois certos, é configuração do sistema: o usuário fala com quem o administra |
| `401` só no agente, com o teste do script passando | o agente foi aberto antes de a variável existir | feche e abra o agente inteiro (o VS Code com todas as janelas) |
| O servidor não aparece, ou aparece outro com o mesmo nome | no Claude Code, o registro local ou de projeto ganha do de usuário | `claude mcp list`; remova o repetido ou use outro nome |
| Ferramentas faltando ou descrições cortadas | limite do agente: 65 ferramentas, descrições longas | Claude Code: `CLAUDE_CODE_MAX_MCP_DESCRIPTION_LENGTH=20000`; VS Code (128 por pedido) e Windsurf (100): desligue as que não usa |
| O sistema recebeu versão nova e o agente usa a lista antiga | o cliente guardou a lista anterior | reconecte o servidor (no Claude Code, `/mcp`) |
| O link da aplicação não abre | o endereço dos links não é o que o usuário usa | acrescente o cabeçalho `X-Tachyonix-Base` (no claude.ai, `x-app-id`) com a URL que ele abre |
