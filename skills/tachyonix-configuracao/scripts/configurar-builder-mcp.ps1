<#
.SYNOPSIS
    Configura o conector Tachyonix Builder MCP nos agentes de IA desta máquina.

.DESCRIPTION
    Pede a senha SAP sem mostrá-la, confere a conexão com o sistema ANTES de
    guardar qualquer coisa, guarda a credencial numa variável de ambiente do seu
    usuário do Windows e registra o servidor no Claude Code, no Cursor, no
    VS Code e no Codex que encontrar.

    A credencial não aparece na tela nem nos arquivos dos agentes: os registros
    citam a variável (${TACHYONIX_MCP_ABAP_BASIC}), e é o agente que a lê ao
    conectar. Cada arquivo alterado ganha uma cópia ao lado (.bak-<data>).

    Rode num terminal seu (PowerShell ou Windows Terminal), não pelo terminal
    de um agente de IA: o script pede a senha, e o terminal do agente não
    aceita digitação.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\configurar-builder-mcp.ps1 -Endereco https://s4t.empresa.com:44301 -Mandante 100

.EXAMPLE
    .\configurar-builder-mcp.ps1 -Endereco https://s4t.empresa.com:44301 -Mandante 100 -Charts -Agentes claude-code,vscode

.EXAMPLE
    .\configurar-builder-mcp.ps1 -Endereco https://s4t.empresa.com:44301 -Mandante 100 -SoTestar
#>
[CmdletBinding()]
param(
    # O endereço com que você abre o Builder: https://host:porta (serve também a URL inteira do nó).
    [string]$Endereco,
    # O mandante (sap-client), três dígitos.
    [string]$Mandante,
    # O nome do servidor no agente. Padrão: tachyonix-<sistema>, como tachyonix-s4t.
    [string]$Nome,
    # Onde registrar, separados por vírgula: claude-code, cursor, vscode, codex. Sem ele, os encontrados.
    [string]$Agentes,
    # Registra também o Tachyonix Charts MCP (DataView, Dashboard e Analytics), no nó ao lado.
    [switch]$Charts,
    # Só confere a conexão, com a credencial já guardada. Não muda nada.
    [switch]$SoTestar,
    # A variável de ambiente que guarda o Base64 de USUARIO:senha.
    [string]$Variavel = 'TACHYONIX_MCP_ABAP_BASIC',
    # Para automação. Sem ele, o script pergunta usuário e senha.
    [System.Management.Automation.PSCredential]$Credencial,
    # O idioma da sessão: é nele que a aplicação nasce e as descrições chegam.
    [string]$Idioma = 'PT'
)

$ErrorActionPreference = 'Stop'

$NOMES_AGENTE = [ordered]@{
    'claude-code' = 'Claude Code'
    'cursor'      = 'Cursor'
    'vscode'      = 'VS Code'
    'codex'       = 'Codex'
}
# o Claude Code corta a descrição das ferramentas; a de create_component passa de 18 mil
$CORTE_DESCRICAO = 20000

$ABRE = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"configurar-builder-mcp","version":"1.0"}}}'
$ENV_INFO = '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"env_info","arguments":{}}}'

# ------------------------------------------------------------- conversa --- #

function Diz([string]$texto = '', [string]$cor = 'Gray') { Write-Host $texto -ForegroundColor $cor }
function Diz-Ok([string]$texto)    { Write-Host "  [ok] $texto" -ForegroundColor Green }
function Diz-Aviso([string]$texto) { Write-Host "  [!]  $texto" -ForegroundColor Yellow }
function Diz-Falha([string]$texto) { Write-Host "  [x]  $texto" -ForegroundColor Red }

function Pode-Perguntar { -not [Console]::IsInputRedirected }

function Pergunta([string]$texto, [string]$padrao = '') {
    if (-not (Pode-Perguntar)) { return $padrao }
    $rotulo = if ($padrao) { "$texto [$padrao]" } else { $texto }
    $r = Read-Host $rotulo
    if ([string]::IsNullOrWhiteSpace($r)) { return $padrao }
    return $r.Trim()
}

function Confirma([string]$texto, [bool]$padrao = $true) {
    if (-not (Pode-Perguntar)) { return $padrao }
    $opcoes = if ($padrao) { 'S/n' } else { 's/N' }
    $r = Read-Host "$texto [$opcoes]"
    if ([string]::IsNullOrWhiteSpace($r)) { return $padrao }
    return $r.Trim().ToLowerInvariant().StartsWith('s')
}

# ------------------------------------------------------------- endereço --- #

function Resolve-Sistema([string]$endereco) {
    $e = $endereco.Trim()
    if ($e -notmatch '^[A-Za-z][A-Za-z0-9+.-]*://') { $e = "https://$e" }
    $uri = $null
    if (-not [Uri]::TryCreate($e, [UriKind]::Absolute, [ref]$uri)) {
        throw "Endereço inválido: '$endereco'. Use https://host:porta, o mesmo com que você abre o Builder."
    }
    $mandante = ''
    if ($uri.Query -match 'sap-client=(\d{3})') { $mandante = $Matches[1] }
    return [pscustomobject]@{
        Base     = '{0}://{1}' -f $uri.Scheme, $uri.Authority
        Servidor = $uri.Host
        Esquema  = $uri.Scheme
        Mandante = $mandante
    }
}

function Url-No([string]$base, [string]$no, [string]$mandante, [string]$idioma) {
    return '{0}/sap/bc/tachyonix/{1}?sap-client={2}&sap-language={3}' -f $base, $no, $mandante, $idioma
}

function Nome-Padrao([string]$servidor) {
    $s = $servidor.ToLowerInvariant()
    $sistema = if ($s -match '^\d{1,3}(\.\d{1,3}){3}$') { $s -replace '\.', '-' } else { ($s -split '\.')[0] }
    return 'tachyonix-' + (($sistema -replace '[^a-z0-9-]', '-').Trim('-'))
}

function Nome-Charts([string]$nome) {
    if ($nome -like 'tachyonix-*') { return 'tachyonix-charts-' + $nome.Substring(10) }
    return "$nome-charts"
}

# ----------------------------------------------------------- credencial --- #

function Base64-Credencial([string]$usuario, [securestring]$senha) {
    $claro = [Net.NetworkCredential]::new('', $senha).Password
    try { return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($usuario + ':' + $claro)) }
    finally { $claro = $null }
}

function Le-Variavel([string]$nome) {
    $v = [Environment]::GetEnvironmentVariable($nome, 'Process')
    if (-not $v) { $v = [Environment]::GetEnvironmentVariable($nome, 'User') }
    return $v
}

function Grava-Variavel([string]$nome, [string]$valor) {
    # no usuário, nunca em 'Machine'; e no processo, para o claude mcp add e o teste
    [Environment]::SetEnvironmentVariable($nome, $valor, 'User')
    [Environment]::SetEnvironmentVariable($nome, $valor, 'Process')
}

# o Codex recebe o NOME de uma variável que guarda a linha inteira, 'Basic <base64>'
function Variavel-Auth([string]$variavel) { return ($variavel -replace '_BASIC$', '') + '_AUTH' }

function Variavel-DoSistema([string]$nome) {
    return 'TACHYONIX_' + (($nome -replace '^tachyonix-', '') -replace '[^A-Za-z0-9]', '_').ToUpperInvariant() + '_BASIC'
}

# ---------------------------------------------------------------- teste --- #

function Chama-Mcp([string]$url, [string]$basic, [string]$corpo, [switch]$Gravacao) {
    # o SAP consome o Authorization no logon; a gravação usa o X-Tachyonix-Auth
    $linha = "Basic $basic"
    $cabecalhos = @{ 'Authorization' = $linha }
    if ($Gravacao) { $cabecalhos['X-Tachyonix-Auth'] = $linha }
    try {
        $r = Invoke-RestMethod -Uri $url -Method Post -Headers $cabecalhos `
            -ContentType 'application/json; charset=utf-8' `
            -Body ([Text.Encoding]::UTF8.GetBytes($corpo)) -TimeoutSec 120 -UseBasicParsing
        return [pscustomobject]@{ Status = 200; Corpo = $r; Erro = '' }
    } catch {
        $status = 0
        $resposta = $_.Exception.Response
        if ($resposta) { try { $status = [int]$resposta.StatusCode } catch { $status = 0 } }
        $erro = $_.Exception.Message
        if ($_.Exception.InnerException) { $erro = $_.Exception.InnerException.Message }
        return [pscustomobject]@{ Status = $status; Corpo = $null; Erro = $erro }
    }
}

function Testa-Builder([string]$url, [string]$basic) {
    $res = [pscustomobject]@{ Ok = $false; Status = 0; Erro = ''; Info = $null }
    $abre = Chama-Mcp $url $basic $ABRE
    $res.Status = $abre.Status
    $res.Erro = $abre.Erro
    if ($abre.Status -ne 200) { return $res }
    $servidor = $null
    if ($abre.Corpo -and $abre.Corpo.result) { $servidor = $abre.Corpo.result.serverInfo.name }
    if ($servidor -ne 'Tachyonix Builder MCP') {
        $res.Erro = 'a resposta não é do Tachyonix Builder MCP (confira o caminho /sap/bc/tachyonix/mcp)'
        return $res
    }
    $chamada = Chama-Mcp $url $basic $ENV_INFO -Gravacao
    $res.Status = $chamada.Status
    if ($chamada.Status -ne 200 -or -not $chamada.Corpo.result) {
        if ($chamada.Corpo -and $chamada.Corpo.error) { $res.Erro = 'env_info devolveu erro: ' + $chamada.Corpo.error.message }
        else { $res.Erro = 'env_info não respondeu: ' + $chamada.Erro }
        return $res
    }
    # a recusa vem como texto, não JSON: a do usuário sem S_DEVELOP, por exemplo
    if ($chamada.Corpo.result.isError -eq $true) {
        $res.Erro = 'o servidor recusou o env_info: ' + $chamada.Corpo.result.content[0].text
        return $res
    }
    $res.Info = $chamada.Corpo.result.content[0].text | ConvertFrom-Json
    $res.Ok = $true
    return $res
}

function Explica-Falha($teste) {
    switch ($teste.Status) {
        401 { return 'Usuário, senha ou mandante não conferem (401). Confira entrando no Builder com o mesmo usuário.' }
        403 { return 'O sistema recusou o acesso ao serviço do MCP (403): o usuário não tem autorização para /sap/bc/tachyonix/mcp.' }
        404 { return 'Não há Builder MCP neste endereço (404). Confira host, porta e mandante; se estiverem certos, o administrador cria o nó pelo report /TACHYON/MCP_ICF_SETUP.' }
        0   { return "Não conectou: $($teste.Erro) Confira o endereço e a rede (VPN). Se a mensagem fala de certificado, SSL ou TLS, o Windows não confia no certificado do servidor." }
        200 { return "O endereço respondeu, mas $($teste.Erro)." }
        default { return "O sistema respondeu $($teste.Status): $($teste.Erro)" }
    }
}

function Mostra-Info($info) {
    Diz-Ok ('Conectou como {0} no {1}, mandante {2} (Builder {3}).' -f
        $info.usuario, $info.environment.name, $info.environment.sap_client, $info.builder.versao_builder)
    if ($info.escrita_disponivel -eq $true) {
        Diz-Ok 'Gravação disponível (escrita_disponivel = true).'
    } else {
        Diz-Aviso ('O conector lê, mas não grava (escrita_disponivel = false). Com os dois cabeçalhos ' +
                   'certos, isso é configuração do sistema: fale com quem o administra.')
    }
}

# --------------------------------------------------------------- agentes --- #

function Acha-Claude {
    # .exe sempre: o claude.cmd do npm passaria o '&' da URL para o cmd.exe
    $exe = Get-Command 'claude.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($exe) { return [pscustomobject]@{ Exe = $exe.Source; Antes = @() } }
    $local = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
    if (Test-Path -LiteralPath $local) { return [pscustomobject]@{ Exe = $local; Antes = @() } }
    $doEditor = @('.vscode', '.cursor', '.windsurf') |
        ForEach-Object { Join-Path $env:USERPROFILE "$_\extensions" } |
        Where-Object { Test-Path -LiteralPath $_ } |
        ForEach-Object { Get-ChildItem -LiteralPath $_ -Directory -Filter 'anthropic.claude-code-*' -ErrorAction SilentlyContinue } |
        ForEach-Object { Join-Path $_.FullName 'resources\native-binary\claude.exe' } |
        Where-Object { Test-Path -LiteralPath $_ } |
        Sort-Object { (Get-Item -LiteralPath $_).LastWriteTime } -Descending |
        Select-Object -First 1
    if ($doEditor) { return [pscustomobject]@{ Exe = $doEditor; Antes = @() } }
    $shim = Get-Command 'claude.cmd' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $node = Get-Command 'node.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($shim -and $node) {
        $cli = Join-Path (Split-Path $shim.Source) 'node_modules\@anthropic-ai\claude-code\cli.js'
        if (Test-Path -LiteralPath $cli) { return [pscustomobject]@{ Exe = $node.Source; Antes = @($cli) } }
    }
    return $null
}

function Pastas-VSCode {
    return @('Code', 'Code - Insiders') |
        ForEach-Object { Join-Path $env:APPDATA "$_\User" } |
        Where-Object { Test-Path -LiteralPath $_ }
}

function Detecta-Agentes {
    $achados = @()
    if ((Acha-Claude) -or (Test-Path -LiteralPath (Join-Path $env:USERPROFILE '.claude.json'))) { $achados += 'claude-code' }
    if (Test-Path -LiteralPath (Join-Path $env:USERPROFILE '.cursor')) { $achados += 'cursor' }
    if (@(Pastas-VSCode).Count -gt 0) { $achados += 'vscode' }
    if ((Test-Path -LiteralPath (Join-Path $env:USERPROFILE '.codex')) -or
        (Get-Command 'codex' -ErrorAction SilentlyContinue)) { $achados += 'codex' }
    return $achados
}

function Roda-Nativo([string]$exe, [string[]]$argumentos) {
    # no Windows PowerShell, stderr de programa externo com 'Stop' vira exceção
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $saida = & $exe @argumentos 2>&1 | ForEach-Object { "$_" }
        return [pscustomobject]@{ Codigo = $LASTEXITCODE; Saida = ($saida -join "`n").Trim() }
    } finally {
        $ErrorActionPreference = $anterior
    }
}

function Resultado([string]$agente, [string]$nome, [string]$situacao, [string]$detalhe, [string]$bloco) {
    return [pscustomobject]@{ Agente = $agente; Nome = $nome; Situacao = $situacao; Detalhe = $detalhe; Bloco = $bloco }
}

function Servidor-Http([string]$url, [string]$referencia, [string]$tipo) {
    $s = [ordered]@{}
    if ($tipo) { $s['type'] = $tipo }
    $s['url'] = $url
    $s['headers'] = [ordered]@{
        'Authorization'    = "Basic $referencia"
        'X-Tachyonix-Auth' = "Basic $referencia"
    }
    return $s
}

function Json-Escalar($valor) {
    # o ConvertTo-Json do Windows PowerShell escapa & < > ' : válido, mas ilegível
    $json = ConvertTo-Json -InputObject $valor -Compress
    $barra = [char]92
    foreach ($par in @(@('0026', '&'), @('0027', "'"), @('003c', '<'), @('003e', '>'))) {
        $json = $json.Replace($barra + 'u' + $par[0], $par[1])
    }
    return $json
}

function Json-Legivel($valor, [int]$nivel = 0) {
    # recuo de 2 espaços: o mcp.json é arquivo que gente edita, e o ConvertTo-Json
    # do Windows PowerShell recua cada valor até a coluna da chave
    $dentro = '  ' * ($nivel + 1)
    $fora = '  ' * $nivel
    if ($null -eq $valor) { return 'null' }
    # pares numa lista explícita: @() de um único par achataria o par
    $pares = $null
    if ($valor -is [System.Collections.IDictionary]) {
        $pares = New-Object System.Collections.Generic.List[object]
        foreach ($k in $valor.Keys) { $pares.Add(@([string]$k, $valor[$k])) }
    } elseif ($valor -is [System.Management.Automation.PSCustomObject]) {
        $pares = New-Object System.Collections.Generic.List[object]
        foreach ($p in $valor.PSObject.Properties) { $pares.Add(@($p.Name, $p.Value)) }
    }
    if ($null -ne $pares) {
        if ($pares.Count -eq 0) { return '{}' }
        $itens = foreach ($p in $pares) { $dentro + (Json-Escalar $p[0]) + ': ' + (Json-Legivel $p[1] ($nivel + 1)) }
        return "{`n" + (@($itens) -join ",`n") + "`n$fora}"
    }
    if ($valor -is [System.Collections.IEnumerable] -and $valor -isnot [string]) {
        $itens = @(foreach ($v in $valor) { $dentro + (Json-Legivel $v ($nivel + 1)) })
        if ($itens.Count -eq 0) { return '[]' }
        return "[`n" + ($itens -join ",`n") + "`n$fora]"
    }
    return Json-Escalar $valor
}

function Copia-DeSeguranca([string]$arquivo) {
    # uma cópia por segundo: o Builder e o Charts gravam o mesmo arquivo em
    # sequência, e a segunda cópia guardaria o arquivo já alterado no lugar do original
    $copia = $arquivo + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
    if ((Test-Path -LiteralPath $arquivo) -and -not (Test-Path -LiteralPath $copia)) {
        Copy-Item -LiteralPath $arquivo -Destination $copia
    }
}

function Escreve-Texto([string]$arquivo, [string]$texto) {
    $pasta = Split-Path -Parent $arquivo
    if (-not (Test-Path -LiteralPath $pasta)) { New-Item -ItemType Directory -Path $pasta -Force | Out-Null }
    [IO.File]::WriteAllText($arquivo, $texto, (New-Object System.Text.UTF8Encoding $false))
}

function Grava-Json([string]$arquivo, [string]$raiz, [string]$nome, $servidor) {
    $obj = $null
    if (Test-Path -LiteralPath $arquivo) {
        $texto = [IO.File]::ReadAllText($arquivo)
        if ($texto.Trim()) {
            try { $obj = $texto | ConvertFrom-Json }
            catch {
                return [pscustomobject]@{ Situacao = 'manual'
                    Detalhe = "$arquivo não é JSON puro (tem comentário ou vírgula sobrando): acrescente o bloco abaixo em `"$raiz`"" }
            }
            if ($obj -isnot [System.Management.Automation.PSCustomObject]) {
                return [pscustomobject]@{ Situacao = 'manual'; Detalhe = "$arquivo não tem um objeto JSON na raiz" }
            }
        }
    }
    if (-not $obj) { $obj = [pscustomobject]@{} }
    $lista = $null
    if ($obj.PSObject.Properties[$raiz]) { $lista = $obj.$raiz }
    if ($lista -isnot [System.Management.Automation.PSCustomObject]) {
        $lista = [pscustomobject]@{}
        $obj | Add-Member -NotePropertyName $raiz -NotePropertyValue $lista -Force
    }
    $existia = [bool]$lista.PSObject.Properties[$nome]
    if ($existia) { $lista.PSObject.Properties.Remove($nome) }
    $lista | Add-Member -NotePropertyName $nome -NotePropertyValue $servidor
    Copia-DeSeguranca $arquivo
    Escreve-Texto $arquivo ((Json-Legivel $obj) + "`n")
    $situacao = if ($existia) { 'atualizado' } else { 'registrado' }
    return [pscustomobject]@{ Situacao = $situacao; Detalhe = $arquivo }
}

function Grava-Codex([string]$arquivo, [string]$nome, [string]$url, [string]$variavelAuth) {
    # TOML à mão: só o bloco [mcp_servers.<nome>] (e as subtabelas dele) muda
    $linhas = @()
    $quebra = "`n"
    if (Test-Path -LiteralPath $arquivo) {
        $texto = [IO.File]::ReadAllText($arquivo)
        if ($texto.Contains("`r`n")) { $quebra = "`r`n" }
        $linhas = $texto -split "`r?`n"
    }
    $esc = [regex]::Escape($nome)
    $cabecalho = '^\s*\[\s*mcp_servers\s*\.\s*(?:"' + $esc + '"|' + $esc + ')\s*[\].]'
    $mantidas = New-Object System.Collections.Generic.List[string]
    $pulando = $false
    $existia = $false
    foreach ($l in $linhas) {
        if ($l -match '^\s*\[') {
            $pulando = $l -match $cabecalho
            if ($pulando) { $existia = $true }
        }
        if (-not $pulando) { $mantidas.Add($l) }
    }
    while ($mantidas.Count -gt 0 -and [string]::IsNullOrWhiteSpace($mantidas[$mantidas.Count - 1])) {
        $mantidas.RemoveAt($mantidas.Count - 1)
    }
    $todas = @($mantidas)
    if ($todas.Count -gt 0) { $todas += '' }
    $todas += "[mcp_servers.$nome]"
    $todas += "url = `"$url`""
    $todas += ('env_http_headers = {{ "Authorization" = "{0}", "X-Tachyonix-Auth" = "{0}" }}' -f $variavelAuth)
    Copia-DeSeguranca $arquivo
    Escreve-Texto $arquivo (($todas -join $quebra) + $quebra)
    $situacao = if ($existia) { 'atualizado' } else { 'registrado' }
    return [pscustomobject]@{ Situacao = $situacao; Detalhe = $arquivo }
}

function Registra-ClaudeCode([string]$nome, [string]$url, [string]$variavel) {
    $ref = '${' + $variavel + '}'
    $manual = "claude mcp add --transport http --scope user $nome '$url' " +
              "--header 'Authorization: Basic $ref' --header 'X-Tachyonix-Auth: Basic $ref'"
    $cc = Acha-Claude
    if (-not $cc) {
        return Resultado 'claude-code' $nome 'manual' 'não achei o executável do Claude Code: rode no Git Bash (ou no terminal do macOS e do Linux)' $manual
    }
    $removeu = Roda-Nativo $cc.Exe ($cc.Antes + @('mcp', 'remove', $nome, '--scope', 'user'))
    $r = Roda-Nativo $cc.Exe ($cc.Antes + @('mcp', 'add', '--transport', 'http', '--scope', 'user', $nome, $url,
            '--header', "Authorization: Basic $ref", '--header', "X-Tachyonix-Auth: Basic $ref"))
    if ($r.Codigo -ne 0) {
        return Resultado 'claude-code' $nome 'manual' ("o claude mcp add falhou: " + $r.Saida) $manual
    }
    $situacao = if ($removeu.Codigo -eq 0) { 'atualizado' } else { 'registrado' }
    return Resultado 'claude-code' $nome $situacao 'escopo do usuário (~/.claude.json)' ''
}

function Registra([string]$agente, [string]$nome, [string]$url, [string]$variavel) {
    switch ($agente) {
        'claude-code' { return Registra-ClaudeCode $nome $url $variavel }
        'cursor' {
            $s = Servidor-Http $url ('${env:' + $variavel + '}') ''
            $r = Grava-Json (Join-Path $env:USERPROFILE '.cursor\mcp.json') 'mcpServers' $nome $s
            return Resultado 'cursor' $nome $r.Situacao $r.Detalhe (Json-Legivel @{ mcpServers = @{ $nome = $s } })
        }
        'vscode' {
            $s = Servidor-Http $url ('${env:' + $variavel + '}') 'http'
            $pastas = @(Pastas-VSCode)
            if ($pastas.Count -eq 0) { $pastas = @(Join-Path $env:APPDATA 'Code\User') }
            foreach ($p in $pastas) {
                $r = Grava-Json (Join-Path $p 'mcp.json') 'servers' $nome $s
                Resultado 'vscode' $nome $r.Situacao $r.Detalhe (Json-Legivel @{ servers = @{ $nome = $s } })
            }
        }
        'codex' {
            $r = Grava-Codex (Join-Path $env:USERPROFILE '.codex\config.toml') $nome $url (Variavel-Auth $variavel)
            return Resultado 'codex' $nome $r.Situacao $r.Detalhe ''
        }
    }
}

# ------------------------------------------------------------ principal --- #

function Configura {
    Diz ''
    Diz 'Tachyonix Builder MCP - configuração do conector' 'Cyan'
    Diz ''
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch { }

    if (-not $Endereco) {
        $Endereco = Pergunta 'Endereço do sistema, o mesmo com que você abre o Builder (ex.: https://s4t.empresa.com:44301)'
    }
    if (-not $Endereco) { Diz-Falha 'Falta o endereço do sistema (-Endereco https://host:porta).'; exit 1 }
    try { $sis = Resolve-Sistema $Endereco } catch { Diz-Falha $_.Exception.Message; exit 1 }
    if (-not $Mandante) { $Mandante = $sis.Mandante }
    if (-not $Mandante) { $Mandante = Pergunta 'Mandante (sap-client)' }
    if ($Mandante -notmatch '^\d{3}$') { Diz-Falha "Mandante inválido: '$Mandante'. São três dígitos, como 100."; exit 1 }
    if ($sis.Esquema -ne 'https') { Diz-Aviso 'O endereço não é https: a senha passaria sem criptografia pela rede.' }
    if (-not $Nome) { $Nome = Nome-Padrao $sis.Servidor }
    if ($Nome -notmatch '^[a-z0-9][a-z0-9-]*$') { Diz-Falha "Nome inválido: '$Nome'. Use minúsculas, dígitos e hífen."; exit 1 }

    $escolhidos = $null
    if ($Agentes) {
        $escolhidos = @($Agentes -split '[,; ]+' | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() })
        $invalidos = @($escolhidos | Where-Object { -not $NOMES_AGENTE.Contains($_) })
        if ($invalidos.Count -gt 0) {
            Diz-Falha ("Agente desconhecido: {0}. Use {1}." -f ($invalidos -join ', '), ($NOMES_AGENTE.Keys -join ', '))
            exit 1
        }
    }

    $url = Url-No $sis.Base 'mcp' $Mandante $Idioma
    Diz "  Servidor: $url"
    Diz "  Nome no agente: $Nome"
    Diz ''

    if ($SoTestar) {
        $basic = Le-Variavel $Variavel
        if (-not $basic) { Diz-Falha "A variável $Variavel não existe: rode o script sem -SoTestar."; exit 1 }
        $t = Testa-Builder $url $basic
        if (-not $t.Ok) { Diz-Falha (Explica-Falha $t); exit 1 }
        Mostra-Info $t.Info
        exit 0
    }

    # 1. a credencial, conferida ANTES de ser guardada
    $basic = $null
    $t = $null
    $guardada = [Environment]::GetEnvironmentVariable($Variavel, 'User')
    if (-not $Credencial -and $guardada -and (Confirma "Já existe uma credencial em $Variavel. Usar a mesma neste sistema?" $true)) {
        Diz '  Conferindo a conexão...'
        $t = Testa-Builder $url $guardada
        if ($t.Ok) { $basic = $guardada }
        else {
            Diz-Falha (Explica-Falha $t)
            if ($t.Status -ne 401) { exit 1 }
        }
    }
    for ($tentativa = 1; -not $basic -and $tentativa -le 3; $tentativa++) {
        if ($Credencial) {
            $usuario = $Credencial.UserName
            $senha = $Credencial.Password
        } else {
            if (-not (Pode-Perguntar)) {
                Diz-Falha ('Este script pede a senha: rode-o num terminal seu (PowerShell ou Windows Terminal), ' +
                           'não pelo terminal de um agente de IA.')
                exit 2
            }
            $usuario = Pergunta 'Usuário SAP'
            $senha = Read-Host 'Senha SAP (não aparece na tela)' -AsSecureString
        }
        if (-not $usuario) { Diz-Falha 'Falta o usuário SAP.'; continue }
        $candidata = Base64-Credencial $usuario $senha
        Diz '  Conferindo a conexão...'
        $t = Testa-Builder $url $candidata
        if ($t.Ok) { $basic = $candidata; break }
        Diz-Falha (Explica-Falha $t)
        if ($Credencial -or $t.Status -ne 401) { exit 1 }
    }
    if (-not $basic) { exit 1 }
    Mostra-Info $t.Info

    # 2. o Charts MCP, se pedido: mesmo sistema, mesma credencial, nó ao lado
    $urlCharts = $null
    if ($Charts) {
        $urlCharts = Url-No $sis.Base 'charts_mcp' $Mandante $Idioma
        $c = Chama-Mcp $urlCharts $basic $ABRE
        if ($c.Status -eq 200 -and $c.Corpo -and $c.Corpo.result) {
            Diz-Ok 'O Tachyonix Charts MCP respondeu: ele também será registrado.'
        } else {
            $porque = if ($c.Status) { "respondeu $($c.Status)" } else { $c.Erro }
            Diz-Aviso "O Tachyonix Charts MCP não está disponível neste sistema ($porque): registro só o Builder MCP."
            $urlCharts = $null
        }
    }

    # 3. os agentes
    if ($null -eq $escolhidos) {
        $achados = @(Detecta-Agentes)
        if ($achados.Count -eq 0) {
            Diz-Aviso 'Não achei Claude Code, Cursor, VS Code nem Codex nesta máquina: guardo só a credencial.'
            $escolhidos = @()
        } else {
            Diz ('  Agentes encontrados: ' + (($achados | ForEach-Object { $NOMES_AGENTE[$_] }) -join ', '))
            if (Confirma 'Registrar em todos?' $true) { $escolhidos = $achados }
            else { $escolhidos = @($achados | Where-Object { Confirma "  $($NOMES_AGENTE[$_])?" $true }) }
        }
    }

    # 4. guarda a credencial
    $guardada = [Environment]::GetEnvironmentVariable($Variavel, 'User')
    if ($guardada -and $guardada -ne $basic) {
        Diz-Aviso "A variável $Variavel já guarda outra credencial, que outros conectores podem estar usando."
        if (-not (Confirma '  Substituir por esta? (Não: guardo esta numa variável só deste sistema)' $false)) {
            $Variavel = Variavel-DoSistema $Nome
        }
    }
    Grava-Variavel $Variavel $basic
    Diz-Ok "Credencial guardada em $Variavel, variável do seu usuário do Windows."
    if ($escolhidos -contains 'codex') {
        Grava-Variavel (Variavel-Auth $Variavel) "Basic $basic"
        Diz-Ok "Codex: a linha inteira em $(Variavel-Auth $Variavel)."
    }
    if ($escolhidos -contains 'claude-code') {
        $corte = [Environment]::GetEnvironmentVariable('CLAUDE_CODE_MAX_MCP_DESCRIPTION_LENGTH', 'User') -as [int]
        if (-not $corte -or $corte -lt $CORTE_DESCRICAO) {
            Grava-Variavel 'CLAUDE_CODE_MAX_MCP_DESCRIPTION_LENGTH' "$CORTE_DESCRICAO"
            Diz-Ok "Claude Code: CLAUDE_CODE_MAX_MCP_DESCRIPTION_LENGTH = $CORTE_DESCRICAO, para as descrições longas chegarem inteiras."
        }
    }

    # 5. registra
    $resultados = @()
    foreach ($a in $escolhidos) {
        $resultados += @(Registra $a $Nome $url $Variavel)
        if ($urlCharts) { $resultados += @(Registra $a (Nome-Charts $Nome) $urlCharts $Variavel) }
    }

    Diz ''
    Diz 'Resumo' 'Cyan'
    foreach ($r in $resultados) {
        $rotulo = '{0,-12} {1,-28}' -f $NOMES_AGENTE[$r.Agente], $r.Nome
        if ($r.Situacao -eq 'manual') {
            Diz-Aviso "$rotulo à mão: $($r.Detalhe)"
            Diz $r.Bloco 'White'
        } else {
            Diz-Ok "$rotulo $($r.Situacao): $($r.Detalhe)"
        }
    }
    Diz ''
    Diz 'Próximos passos' 'Cyan'
    Diz '  1. Feche e abra cada agente (o VS Code inteiro, todas as janelas): ele só enxerga a credencial depois de reiniciar.'
    Diz '  2. Numa conversa nova, peça: "Chame env_info e me mostre o resultado." Tem de vir o seu usuário e escrita_disponivel = true.'
    Diz '  3. Senha trocada no SAP: rode este script de novo, com os mesmos parâmetros.'
    Diz ''
    exit 0
}

# dot-source (. .\configurar-builder-mcp.ps1) só carrega as funções: é como os testes as exercitam
if ($MyInvocation.InvocationName -ne '.') { Configura }
