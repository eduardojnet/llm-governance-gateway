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
