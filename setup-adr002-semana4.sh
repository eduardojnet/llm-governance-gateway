#!/usr/bin/env bash
# =============================================================================
# llm-governance-gateway :: ADR-0002
# Deteccao de PII deterministica no caminho critico
# Executar dentro da pasta do repositorio local.
# =============================================================================
set -euo pipefail

REPO_DIR="/home/eduardo/Documentos/PESSOAL/Documentos/llm-governance-gateway"
cd "$REPO_DIR"

git pull --rebase origin main 2>/dev/null || true
mkdir -p docs/adr

cat > docs/adr/0002-deteccao-de-pii-deterministica.md <<'EOF'
# ADR-0002: Deteccao de PII deterministica no caminho critico

**Status:** aceita
**Data:** 2026-09
**Requisitos relacionados:** RF-03, RF-04, RNF-01, RNF-06, RNF-07, RNF-11

## Contexto

O gateway precisa identificar dado pessoal no payload antes de encaminha-lo a um provedor
externo (RF-03) e aplicar acao configuravel por tipo (RF-04). Tres requisitos limitam as
abordagens possiveis:

- **RNF-01:** overhead p95 de 50 ms para toda a cadeia de politicas, nao apenas para a deteccao.
- **RNF-07:** cobertura >= 98% e falso positivo <= 2%, medidos e publicados.
- **RNF-06:** nenhuma PII detectada pode trafegar em claro sob politica de mascaramento.

Existe ainda um requisito de auditoria que nao aparece como RNF numerado e governa a decisao:
a area de auditoria precisa **reproduzir** a decisao tomada sobre uma requisicao passada,
obtendo o mesmo resultado a partir da mesma entrada.

## Decisao

Deteccao **deterministica** no caminho sincrono da requisicao:

1. Reconhecimento por padrao estrutural (expressao regular) para identificadores brasileiros.
2. **Validacao de digito verificador** para CPF, CNPJ e cartao, descartando falso positivo
   estrutural antes de qualquer acao.
3. Regras versionadas em arquivo, com identificador de versao gravado na trilha de auditoria
   junto de cada decisao.

Nenhum modelo de linguagem participa do caminho sincrono de deteccao.

## Alternativas consideradas

| Alternativa | Por que foi descartada |
|---|---|
| LLM classificando PII no caminho sincrono | Saida nao reproduzivel entre versoes do provedor; latencia variavel incompativel com RNF-01; custo por chamada duplicado; falso positivo nao controlavel para RNF-07 |
| Modelo NER local (spaCy, Presidio) no caminho sincrono | Melhor que LLM em latencia e custo, mas ainda probabilistico: mudanca de modelo altera decisao passada sem alteracao de codigo rastreavel |
| Deteccao apenas por regex, sem digito verificador | Falso positivo estrutural alto (qualquer sequencia de 11 digitos vira CPF), inviabilizando o alvo de 2% |
| Delegar a deteccao a cada aplicacao consumidora | Controle replicado em N lugares, auditoria em N lugares, deriva garantida entre implementacoes |

## Consequencias

**Positivas**
- Mesma entrada produz a mesma saida, hoje e em seis meses. A trilha e reproduzivel.
- A politica vigente em qualquer data passada e recuperavel pelo historico de versoes.
- Latencia previsivel e proxima de zero; sem custo por chamada.
- Alteracao de regra passa por revisao de codigo e tem autoria registrada.

**Negativas, assumidas**
- PII nao estruturada nao e coberta: nome proprio em texto corrido, endereco em forma livre,
  dado sensivel inferido pelo contexto da frase.
- Novos formatos exigem nova regra e novo deploy do arquivo de regras.
- A cobertura de 98% do RNF-07 e medida contra dataset sintetico de PII **estruturada**, e o
  escopo dessa medicao sera declarado junto do resultado.

## Tratamento do que o determinismo nao cobre

PII nao estruturada nao entra no caminho sincrono. A abordagem prevista:

1. Politica conservadora no ingresso por rota: rotas que recebem texto livre de origem sensivel
   operam sob acao mais restritiva por padrao.
2. Classificacao estatistica **fora** do caminho critico, alimentando revisao posterior e
   ajuste de politica, sem decidir bloqueio em tempo de requisicao.
3. A decisao de bloqueio permanece com regra explicita, sob responsabilidade nomeada.

## Criterio de revisao desta decisao

Esta ADR sera revista se, e somente se, houver metodo que garanta reproducao bit a bit da
decisao de classificacao ao longo do tempo, com versionamento verificavel do artefato que
decide.
EOF

git add -A
git commit -m "docs(adr): ADR-0002 deterministic PII detection on the critical path" || true

echo ""
echo "============================================================"
echo "ADR-0002 criada. Falta apenas: git push origin main"
echo ""
echo "URL do post 4:"
echo "https://github.com/eduardojnet/llm-governance-gateway/blob/main/docs/adr/0002-deteccao-de-pii-deterministica.md"
echo "============================================================"
