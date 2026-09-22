# llm-governance-gateway

Gateway de governança de LLM para ambientes regulados: política declarativa,
mascaramento de PII, trilha de auditoria e fallback entre provedores.

---

## O problema

Uma instituição regulada não trava projeto de inteligência artificial por falta de
tecnologia. Trava porque ninguém sabe responder quem perguntou o quê ao modelo, qual
dado de cliente saiu junto, sob qual regra e a que custo.

Enquanto essas quatro perguntas não tiverem resposta auditável, o projeto não passa
pela segurança da informação nem pelo jurídico.

Este gateway é o ponto único de passagem entre as aplicações internas e os provedores
de modelo. É onde a política é aplicada, registrada e medida.

---

## Nota de honestidade

Este repositório contém **dois artefatos distintos**, e a distinção é declarada de
propósito:

| Artefato | O que é | Status |
|---|---|---|
| **Arquitetura alvo** | Desenho de produção completo em AWS, C4 nos níveis 1 a 3, IaC em Terraform | Documentação |
| **Implementação de referência** | Subconjunto executável em Docker Compose, instrumentado e medido | Em construção |

Nada aqui foi executado em ambiente produtivo de terceiros. Onde houver número, ele
é medição própria e o método de verificação está publicado junto.

---

## Requisitos não funcionais

Alvos definidos **antes** da primeira linha de código. Status atualizado conforme a
medição acontece.

| ID | Alvo | Verificação | Status |
|---|---|---|---|
| RNF-01 | Overhead p95 ≤ 50 ms (exclui tempo do provedor) | Teste de carga com provedor mockado | Não medido |
| RNF-02 | Overhead p99 ≤ 120 ms | Idem | Não medido |
| RNF-03 | 200 req/s por instância do plano de dados | Teste de carga | Não medido |
| RNF-04 | 99,9% no plano de dados; falha do plano de controle não derruba o tráfego | Falha injetada | Não medido |
| RNF-05 | Fallback entre provedores em ≤ 2 s, sem erro ao consumidor | Chaos test | Não medido |
| RNF-06 | Nenhuma PII detectada trafega em claro sob política de mascaramento | Suíte de teste | Não medido |
| RNF-07 | Cobertura de detecção ≥ 98%, falso positivo ≤ 2% | Dataset sintético publicado | Não medido |
| RNF-08 | 100% das requisições registradas na trilha | Reconciliação contador vs. trilha | Não medido |
| RNF-09 | RPO zero para requisições concluídas | Queda durante carga | Não medido |
| RNF-10 | Retenção de 5 anos; payload em claro nunca persistido | Revisão de schema | Não medido |
| RNF-11 | Traço distribuído com correlação requisição, política e custo | Inspeção OpenTelemetry | Não medido |
| RNF-12 | Custo de infraestrutura ≤ 3% do custo de inferência intermediado | Cálculo aberto | Não medido |
| RNF-13 | Mudança de política sem redeploy e sem reinício | Recarga a quente sob carga | Não medido |
| RNF-14 | Troca de provedor sem alteração de código no consumidor | Configuração apenas | Não medido |

Requisito não funcional sem número é desejo. Os 14 acima têm valor e método.

Documento completo, com requisitos funcionais, restrições regulatórias, premissas e
matriz de rastreabilidade: [docs/01-requisitos.md](docs/01-requisitos.md)

---

## Arquitetura

Três serviços, com justificativa por eixo de escala e não por moda:

| Serviço | Responsabilidade | Por que separado |
|---|---|---|
| **Plano de dados** | Caminho crítico: política, PII, roteamento, fallback | Stateless, sensível a latência, escala com tráfego |
| **Plano de controle** | Administração e distribuição de política | Frequência de uso muito menor; falha não pode derrubar o tráfego |
| **Auditoria** | Consumo assíncrono, persistência, encadeamento de hash | Durabilidade e retenção distintas; não bloqueia o caminho crítico |

Parei em três de propósito. Cada fatiamento adicional adiciona custo operacional,
latência de rede e superfície de falha sem ganho correspondente neste domínio.

Diagramas C4 em código: `docs/c4/` (em construção)
Decisões arquiteturais registradas: `docs/adr/`

---

## Stack

Python, FastAPI, Redis, Postgres, OpenTelemetry, Docker Compose.
Arquitetura alvo em AWS: ALB, ECS Fargate, ElastiCache, RDS, SQS, Secrets Manager,
WAF, VPC com subnets privadas. IaC em Terraform, em `infra/`.

---

## Estado atual

| Etapa | Status |
|---|---|
| Engenharia de requisitos | Concluída |
| C4 Contexto e Contêineres | Em construção |
| Plano de dados: proxy e cadeia de políticas | Não iniciado |
| PII engine | Não iniciado |
| Rate limit e budget cap | Não iniciado |
| Trilha de auditoria | Não iniciado |
| Fallback e circuit breaker | Não iniciado |
| IaC e janela de medição em AWS | Não iniciado |
| Benchmarks publicados | Não iniciado |

---

## Como rodar

Ainda não executável. As instruções entram aqui quando o plano de dados subir.

---

## Licença

MIT. Ver [LICENSE](LICENSE).
