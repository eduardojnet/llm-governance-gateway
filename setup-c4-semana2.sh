#!/usr/bin/env bash
# =============================================================================
# llm-governance-gateway :: semana 2
# C4 nivel 1 (Contexto) + Structurizr DSL + ADR-0001
# Executar dentro da pasta do repositorio local.
# =============================================================================
set -euo pipefail

REPO_DIR="/home/eduardo/Documentos/PESSOAL/Documentos/llm-governance-gateway"
cd "$REPO_DIR"

git pull --rebase origin main 2>/dev/null || true
mkdir -p docs/c4 docs/adr

# --- C4 nivel 1: Contexto ---------------------------------------------------
cat > docs/c4/01-contexto.md <<'EOF'
# C4 Nível 1: Contexto

Quem usa o gateway, com o que ele conversa e onde ficam as fronteiras.

O diagrama abaixo usa Mermaid para renderizar direto no GitHub. A fonte canônica,
em Structurizr DSL, está em [`workspace.dsl`](workspace.dsl).

```mermaid
flowchart TB
    subgraph consumidores[" "]
        direction LR
        DEV["<b>Time de produto</b><br/>[Pessoa]<br/>Constrói funcionalidades<br/>que usam LLM"]
        APP["<b>Aplicações internas</b><br/>[Sistema]<br/>Atendimento, back-office,<br/>análise documental"]
    end

    GW["<b>LLM Governance Gateway</b><br/>[Sistema - este projeto]<br/>Aplica política, mascara PII,<br/>registra e roteia"]

    subgraph externos[" "]
        direction LR
        LLM["<b>Provedores de LLM</b><br/>[Sistema externo]<br/>Processamento fora<br/>do perímetro"]
    end

    subgraph governanca[" "]
        direction LR
        AUD["<b>Auditoria e DPO</b><br/>[Pessoa]<br/>Precisa responder<br/>quem viu o quê"]
        FIN["<b>FinOps</b><br/>[Pessoa]<br/>Precisa de teto<br/>e rateio de custo"]
        SRE["<b>SRE</b><br/>[Pessoa]<br/>Precisa que falha externa<br/>não vire incidente interno"]
    end

    IDP["<b>IdP corporativo</b><br/>[Sistema externo]<br/>Identidade de serviço"]
    OBS["<b>Observabilidade e SIEM</b><br/>[Sistema externo]<br/>Traços, métricas, alertas"]

    DEV -->|"constrói"| APP
    APP -->|"requisição no contrato<br/>do provedor, HTTPS"| GW
    GW -->|"payload já tratado"| LLM
    GW -->|"valida identidade<br/>do consumidor"| IDP
    GW -->|"traços, métricas<br/>e eventos"| OBS
    GW -.->|"trilha de auditoria<br/>assíncrona"| AUD
    GW -.->|"consumo e custo<br/>por consumidor"| FIN
    OBS -.->|"alerta de degradação<br/>e fallback"| SRE

    classDef sistema fill:#1168bd,stroke:#0b4884,color:#fff
    classDef externo fill:#999,stroke:#6b6b6b,color:#fff
    classDef pessoa fill:#08427b,stroke:#052e56,color:#fff
    classDef foco fill:#d94801,stroke:#8c2f01,color:#fff
    classDef invisivel fill:none,stroke:none

    class GW foco
    class APP sistema
    class LLM,IDP,OBS externo
    class DEV,AUD,FIN,SRE pessoa
    class consumidores,externos,governanca invisivel
```

## O que o nível 1 revelou

O gateway tem **quatro públicos, não um**. O time de produto é apenas o que faz a
chamada. Auditoria, FinOps e SRE nunca tocam no sistema e ainda assim definem a maior
parte dos requisitos não funcionais.

A consequência entrou direto na arquitetura: três dos quatro públicos consomem
**saída assíncrona** (trilha, custo, alerta). Nenhum deles pode estar no caminho
síncrono da requisição. Isso justifica o serviço de auditoria separado, registrado em
[ADR-0001](../adr/0001-decomposicao-em-tres-servicos.md).

## Fronteira de confiança

A única seta que cruza o perímetro da organização é a do gateway para o provedor de
LLM. É por isso que o mascaramento de PII acontece nesse ponto e não dentro da
aplicação: um único lugar para inspecionar, um único lugar para auditar.

## Fora do contexto, de propósito

Base vetorial, orquestrador de agentes e ferramentas de avaliação de resposta não
aparecem. O gateway é infraestrutura de passagem, não plataforma de IA.
EOF

# --- Structurizr DSL (fonte canonica) ---------------------------------------
cat > docs/c4/workspace.dsl <<'EOF'
workspace "llm-governance-gateway" "Gateway de governanca de LLM para ambientes regulados" {

    model {
        dev   = person "Time de produto" "Constroi funcionalidades que usam LLM"
        aud   = person "Auditoria e DPO" "Precisa responder quem viu o que, quando e sob qual politica"
        fin   = person "FinOps" "Precisa de teto de gasto e rateio por centro de custo"
        sre   = person "SRE" "Precisa que falha externa nao vire incidente interno"

        app   = softwareSystem "Aplicacoes internas" "Atendimento, back-office, analise documental"
        gw    = softwareSystem "LLM Governance Gateway" "Aplica politica, mascara PII, registra e roteia" {
            tags "Foco"
        }
        llm   = softwareSystem "Provedores de LLM" "Processamento fora do perimetro" {
            tags "Externo"
        }
        idp   = softwareSystem "IdP corporativo" "Identidade de servico" {
            tags "Externo"
        }
        obs   = softwareSystem "Observabilidade e SIEM" "Tracos, metricas, alertas" {
            tags "Externo"
        }

        dev -> app "Constroi"
        app -> gw  "Requisicao no contrato do provedor" "HTTPS"
        gw  -> llm "Payload ja tratado" "HTTPS"
        gw  -> idp "Valida identidade do consumidor" "OIDC"
        gw  -> obs "Tracos, metricas e eventos" "OTLP"
        gw  -> aud "Trilha de auditoria (assincrona)"
        gw  -> fin "Consumo e custo por consumidor"
        obs -> sre "Alerta de degradacao e fallback"
    }

    views {
        systemContext gw "contexto" {
            include *
            autolayout tb
        }

        styles {
            element "Person"   { shape person background "#08427b" color "#ffffff" }
            element "Software System" { background "#1168bd" color "#ffffff" }
            element "Externo"  { background "#999999" color "#ffffff" }
            element "Foco"     { background "#d94801" color "#ffffff" }
        }
    }
}
EOF

# --- ADR-0001 ---------------------------------------------------------------
cat > docs/adr/0001-decomposicao-em-tres-servicos.md <<'EOF'
# ADR-0001: Decomposicao em tres servicos

**Status:** aceita
**Data:** 2026-09
**Contexto do projeto:** llm-governance-gateway

## Contexto

O C4 nivel 1 mostrou quatro publicos com necessidades de tempo muito diferentes: o
time de produto consome resposta sincrona; auditoria, FinOps e SRE consomem saida
assincrona. Os RNF de latencia (RNF-01, RNF-02) e de durabilidade da trilha (RNF-08,
RNF-09) sao conflitantes se atendidos pelo mesmo caminho de execucao.

## Decisao

Decompor em tres servicos:

1. **Plano de dados** (gateway): caminho critico, stateless, escala com trafego.
2. **Plano de controle** (policy service): administracao de politica, baixa frequencia.
3. **Servico de auditoria**: consumo assincrono, persistencia, encadeamento de hash.

## Alternativas consideradas

| Alternativa | Por que foi descartada |
|---|---|
| Monolito unico | Escrita sincrona da trilha inviabiliza RNF-01; mudanca de politica exige redeploy, violando RNF-13 |
| Seis ou mais servicos (um por politica) | Custo operacional e latencia de rede sem ganho; nenhuma politica tem eixo de escala proprio |
| Dois servicos (dados + controle, auditoria embutida) | Durabilidade e retencao da trilha acoplam-se ao ciclo de vida do plano de dados |

## Criterio adotado

Servico separado exige **eixo de escala proprio ou ciclo de vida proprio**. Nenhum dos
tres foi separado por dominio conceitual.

## Consequencias

**Positivas:** RNF-01 e RNF-09 deixam de competir; falha do plano de controle nao
derruba o trafego (RNF-04); politica recarrega a quente (RNF-13).

**Negativas:** exige fila com garantia de entrega e prova de que nenhuma mensagem se
perde; tres artefatos de deploy em vez de um; complexidade de observabilidade
distribuida.
EOF

# --- commit -----------------------------------------------------------------
git add -A
git commit -m "docs(c4): system context diagram, structurizr workspace and ADR-0001" || true

echo ""
echo "============================================================"
echo "Semana 2 pronta. Falta apenas: git push origin main"
echo ""
echo "URL do post 2:"
echo "https://github.com/eduardojnet/llm-governance-gateway/blob/main/docs/c4/01-contexto.md"
echo "============================================================"
