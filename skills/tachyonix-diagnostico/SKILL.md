---
name: tachyonix-diagnostico
description: Como diagnosticar uma falha do Tachyonix Builder MCP. Diz onde está o texto do erro do gerador de CDS (400 sem mensagem, 500, recusa do próprio MCP), como ler o log do build, o que fazer com 403, timeout e preview vazio, e quais regras do gerador mais derrubam uma gravação. Use quando uma criação ou edição falhar, quando o build for bloqueado pelo gate ou quando a aplicação gravar mas não trouxer os dados esperados.
---

# Diagnóstico

**O erro tem texto; ele só não está sempre no corpo da resposta.** Leia o
motivo antes de mudar qualquer parâmetro.

**Por que importa:** variar fatores às cegas custa uma gravação por tentativa
e leva a conclusões erradas ("agregação não funciona neste ambiente"), quando
o gerador disse o motivo exato.

## 1. Onde está o motivo

| Sintoma | Onde ler |
|---|---|
| a ferramenta recusou antes de gravar | a própria mensagem: ela nomeia o parâmetro, a regra e a saída |
| gate `BLOQUEADO` | `gate_verdict` e os itens com severidade de erro; `validate_payload` detalha |
| 400 numa **criação** ou **edição** | `mensagens_do_gerador` na resposta: as mensagens do gerador de CDS, com a linha do SDDL (`SDDL_PARSER_MSG/376`…) |
| 500 do gerador | `error` traz o código do dump (`GETWA_NOT_ASSIGNED`, ST22); `ultima_etapa_do_gerador`, quando vem, é o último passo que ele concluiu |
| gravou, mas algo está estranho | `run_backend_validation(guid, log=true)`: o diário do último build |
| gravou, e o dado não é o esperado | `run_backend_validation(guid, preview=5)`: as linhas de cada CDS gerado; `contagem=true` e `conferir_soma` conferem totais |

A mensagem do topo de um 400 é quase sempre a genérica "Exception raised
without specific error"; o motivo está em `mensagens_do_gerador`. Só quando
ela não vem (`como_ver_o_motivo` diz isso) vale aplicar a parte suspeita por
**edição** numa aplicação que já existe, que devolve o diário do build.

## 2. Situações conhecidas

- **Parâmetro recusado**: a ferramenta não o declara; a mensagem diz qual
  ferramenta o tem. Não reenvie em outro nome.
- **403 só na gravação**: sessão/CSRF do servidor ligando para si mesmo. É
  configuração do sistema; avise o usuário, não repita.
- **403 nos serviços depois de uma edição que falhou**: o gerador remove os
  CDS antes de recriar. O MCP já regrava a versão anterior (`restauracao`);
  se ela não voltou, corrija o motivo e grave de novo.
- **403 `/IWFND/MED/101` num CDS** (o `motivo` em `run_backend_validation`):
  o serviço está registrado e o nó ICF dele não foi criado. Esperar não
  resolve. Acontece quando várias aplicações são gravadas ao mesmo tempo no
  mesmo sistema: grave uma por vez. Uma nova gravação da aplicação publica os
  serviços de novo.
- **`ok` do `run_backend_validation`** é o da aplicação inteira: um CDS fora
  basta para a tela não abrir. `aplicacao_lida: false` é GUID que o sistema
  não devolve; confira o GUID antes de recriar.
- **Timeout do cliente** numa criação longa: a aplicação pode ter nascido
  assim mesmo. Procure-a (`list_apps`, ou pelo pacote em `list_packages`)
  antes de repetir, ou nasce em dobro.
- **`preview` vazio numa `consulta`**: ela não publica serviço próprio;
  confira na aplicação que a consome. Num `servico`, vazio é o filtro.
- **Aplicação não aparece na lista do Builder**: a descrição nasce no idioma
  da sessão; confira o idioma do registro do conector.

## 3. Regras do gerador que mais derrubam

| Mensagem ou sintoma | Causa | Saída |
|---|---|---|
| 400 com `/` num calculado | o CDS só divide FLTP com a barra | `DIVISION(a, b, casas)` ou `DIV(a, b)` |
| 500 `RAISE_SHORTDUMP` na leitura de um CDS, com o `$count` em 200 | um calculado divide por uma coluna que é zero em alguma linha | `case when <divisor> = 0 then 0 else division(a, <divisor>, casas) end`, `modo: 'especialista'` |
| 400 com valor CURR/QUAN | a moeda/unidade não está na mesma estrutura, ou mora em outra tabela | traga a referência junto, use a VDM, ou `cast(...)` com a concordância do usuário |
| total CURR/QUAN de uma fonte recusado na aplicação, com referência `DDDDLCHARTYPES` | a fonte somou sem ligar a moeda ao total | regrave o campo na fonte (`update_app_special_fields`) com a moeda nos campos dela |
| `/TACHYON/MESSAGES/137` "Método: Activate" | o CDS passou na sintaxe e falhou na ativação; o gerador corta o motivo | leia `leitura_da_ativacao`; antes de mudar a spec, confira se a mesma grava em outro sistema |
| `SDDL_PARSER_MSG/024` "não está na GROUP BY" | agregação sobre coluna fora do agrupamento | deixe o MCP envelopar; não escreva `SUM(` à mão no calculado da fonte |
| 400 com agregação + CASE | o CASE não entra no GROUP BY | CASE na aplicação, ou fonte `cubo`/`analitica` |
| `SDDL_PARSER_MSG/005` "name not unique" | o mesmo nome em duas estruturas | alias com sufixo da estrutura (o MCP faz sozinho; não copie campo de outra app) |
| 400 na API RAP sem texto | `prefixo_sap` com mais de 5 caracteres | prefixo de até 5 |
| `SDDL_PARSER_MSG/017` "table unknown" | fonte citada sem estar na consulta | acrescente a fonte em `tabelas` (criação) ou `update_app_columns(fontes=...)` |

## 4. Antes de tentar de novo

1. Leia a mensagem inteira e identifique **um** fator.
2. Se a regra não estiver aqui nem na mensagem, rode
   `create_component(..., plan=true)` com a spec: o plano lista todos os
   impedimentos de uma vez.
3. Mude só esse fator e grave de novo. Se falhar igual, o fator era outro:
   volte ao passo 1, não acumule mudanças.
4. Relate ao usuário o que o gerador disse, em português.
