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
