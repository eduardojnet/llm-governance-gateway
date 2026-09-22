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
