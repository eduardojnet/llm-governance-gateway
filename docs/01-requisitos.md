# llm-governance-gateway: Documento de Requisitos

**Versão:** 0.1
**Status:** rascunho para validação
**Tipo de artefato:** arquitetura alvo + implementação de referência

> **Nota de honestidade.** Este documento descreve a arquitetura alvo de um gateway de
> governança de LLM para ambiente regulado. A implementação de referência publicada no
> repositório cobre um subconjunto declarado no item 11. Nada aqui foi executado em
> ambiente produtivo de terceiros.

---

## 1. O problema, em linguagem simples

Uma empresa regulada (banco, seguradora, meio de pagamento) quer usar modelos de
linguagem em processos internos. O caminho ingênuo é cada aplicação chamar o provedor
de IA diretamente com a chave de API.

Isso cria quatro problemas que a área de segurança e o jurídico não aceitam:

1. Dado pessoal de cliente sai da empresa sem inspeção.
2. Ninguém sabe depois quem perguntou o quê, quando, e o que o modelo respondeu.
3. Não existe teto de gasto. A conta aparece no fim do mês.
4. Se o provedor cai, todas as aplicações caem junto.

O gateway resolve isso no mesmo lugar em que se resolveu o problema equivalente de APIs
há quinze anos: um ponto único de passagem, com política declarativa, trilha de
auditoria e resiliência.

**Em uma frase:** é o pedágio entre as aplicações da empresa e os provedores de IA, onde
a política de uso é aplicada e registrada.

---

## 2. O problema, em linguagem técnica

Proxy HTTP de camada 7, compatível com o contrato de API dos principais provedores de
LLM, posicionado entre consumidores internos e provedores externos. Aplica cadeia de
políticas por consumidor e por rota: detecção e pseudonimização de PII com
re-hidratação no retorno, autorização por identidade de serviço, rate limit e budget cap
com contadores distribuídos, trilha de auditoria append-only com hash de payload,
roteamento com fallback entre provedores sob circuit breaker, e telemetria em
OpenTelemetry.

Separação explícita entre plano de dados (caminho crítico, stateless, escala com
tráfego) e plano de controle (administração de política, baixa frequência, perfil de
escala oposto).

---

## 3. Stakeholders e o que cada um exige

| Stakeholder | Dor atual | O que exige do sistema |
|---|---|---|
| Segurança da Informação | Dado sensível saindo sem inspeção | Bloqueio ou mascaramento antes da saída; evidência |
| Jurídico / DPO | Exposição a LGPD, retenção em terceiro | Minimização de dado, base legal rastreável, eliminação |
| Auditoria interna | Ausência de trilha | Registro imutável de quem, quando, o quê, sob qual política |
| Arquitetura / Plataforma | Integração ponto a ponto duplicada | Ponto único, contrato estável, sem lock-in de provedor |
| Time de produto | Bloqueio para lançar | Latência baixa e autosserviço de política |
| Financeiro / FinOps | Custo imprevisível | Teto por consumidor e rateio por centro de custo |
| SRE | Falha externa derruba serviço interno | Fallback, circuit breaker, observabilidade |

---

## 4. Fora de escopo (decisão consciente)

Não faz parte deste sistema, e a exclusão é deliberada:

- Treinamento ou fine-tuning de modelos
- Pipeline de RAG e gestão de base vetorial
- Avaliação de qualidade semântica da resposta
- Interface gráfica de administração
- Cache semântico
- Multi-tenancy com isolamento físico

Cada exclusão existe para manter o gateway como componente de infraestrutura, não como
plataforma de IA. Escopo que cresce por entusiasmo é o modo mais comum de matar um
projeto de referência.

---

## 5. Requisitos funcionais

| ID | Requisito | Prioridade |
|---|---|---|
| RF-01 | Receber requisição no contrato de API do provedor, sem exigir SDK proprietário no cliente | Obrigatório |
| RF-02 | Autenticar o consumidor por identidade de serviço e resolver a política aplicável | Obrigatório |
| RF-03 | Detectar PII brasileira no payload de entrada: CPF, CNPJ, cartão, e-mail, telefone, CEP, nome próprio | Obrigatório |
| RF-04 | Aplicar ação configurável por tipo de PII: mascarar, pseudonimizar, bloquear ou permitir com registro | Obrigatório |
| RF-05 | Re-hidratar tokens pseudonimizados na resposta, restaurando o valor original ao consumidor autorizado | Obrigatório |
| RF-06 | Aplicar rate limit por consumidor e por rota | Obrigatório |
| RF-07 | Aplicar teto de gasto por consumidor, com bloqueio ao atingir o limite | Obrigatório |
| RF-08 | Registrar em trilha append-only: identidade, timestamp, política aplicada, hash do payload, PII detectada por tipo, provedor, tokens e custo estimado | Obrigatório |
| RF-09 | Rotear para provedor alternativo sob falha ou degradação, com circuit breaker | Obrigatório |
| RF-10 | Expor política declarativa em YAML versionado, com validação de schema no carregamento | Obrigatório |
| RF-11 | Expor métricas, health check e readiness | Obrigatório |
| RF-12 | Permitir eliminação seletiva de registro de auditoria mediante solicitação formal, preservando integridade da cadeia de hash | Desejável |

> **Nota sobre RF-12.** Existe tensão real entre trilha imutável e direito de eliminação.
> A solução prevista é criptografia por titular com destruição de chave
> (crypto-shredding), mantendo o hash íntegro.

---

## 6. Requisitos não funcionais

Os números abaixo são **alvos de projeto propostos**, não medições. Serão confrontados
com medição real e o desvio será publicado, favorável ou não.

| ID | Categoria | Alvo proposto | Como será verificado |
|---|---|---|---|
| RNF-01 | Desempenho | Overhead p95 do gateway <= 50 ms, excluído o tempo do provedor | Teste de carga com provedor mockado |
| RNF-02 | Desempenho | Overhead p99 <= 120 ms | Idem |
| RNF-03 | Escalabilidade | 200 req/s por instância do plano de dados | Teste de carga |
| RNF-04 | Disponibilidade | 99,9% no plano de dados; degradação do plano de controle não derruba o plano de dados | Teste de falha injetada |
| RNF-05 | Resiliência | Falha do provedor primário resulta em fallback em <= 2 s, sem erro ao consumidor | Chaos test simples |
| RNF-06 | Segurança | Nenhuma PII detectada trafega para provedor externo em claro sob política de mascaramento | Suíte de teste com dataset sintético |
| RNF-07 | Segurança | Cobertura de detecção >= 98% e falso positivo <= 2% no dataset sintético de PII brasileira | Métrica publicada no repositório |
| RNF-08 | Auditabilidade | 100% das requisições registradas; perda de registro é falha crítica | Reconciliação contador vs. trilha |
| RNF-09 | Auditabilidade | RPO da trilha = 0 para requisições concluídas; escrita assíncrona com garantia de entrega | Teste de queda durante carga |
| RNF-10 | Retenção | Trilha retida por 5 anos; payload em claro nunca persistido, apenas hash | Revisão de schema |
| RNF-11 | Observabilidade | Traço distribuído fim a fim com correlação entre requisição, política e custo | Inspeção em OpenTelemetry |
| RNF-12 | Custo | Custo de infraestrutura do gateway <= 3% do custo de inferência intermediado | Cálculo publicado |
| RNF-13 | Operabilidade | Mudança de política sem redeploy e sem reinício do plano de dados | Teste de recarga a quente |
| RNF-14 | Portabilidade | Troca de provedor sem alteração de código no consumidor | Configuração apenas |

**Regra adotada:** requisito não funcional sem número é desejo, não requisito.

---

## 7. Restrições regulatórias

- **LGPD, princípios do art. 6º:** finalidade, adequação e necessidade. O gateway
  materializa a minimização: envia ao provedor apenas o dado necessário à finalidade
  declarada.
- **LGPD, direitos do titular (art. 18):** inclui eliminação. Tratado em RF-12.
- **Transferência internacional:** provedores de LLM frequentemente processam fora do
  Brasil. O gateway registra destino e política aplicada, produzindo a evidência que a
  área de privacidade precisa.
- **Retenção do provedor:** dado enviado pode ficar sujeito à política de retenção do
  terceiro. Reforça a exigência de mascaramento na saída, não apenas no armazenamento
  próprio.
- **Setor financeiro e segurador:** requisitos de rastreabilidade e continuidade de
  serviço aplicáveis a fornecedores de tecnologia.

> A moldura regulatória setorial específica (BACEN, SUSEP) não foi verificada quanto a
> normativos vigentes. Antes de citar norma setorial nominalmente, confirmar redação e
> vigência na fonte oficial.

---

## 8. Premissas

| ID | Premissa | Risco se falsa |
|---|---|---|
| P-01 | Consumidores internos aceitam o contrato de API do provedor como interface | Exige camada de adaptação adicional |
| P-02 | Detecção determinística por regex e validação de dígito cobre a maior parte da PII estruturada brasileira | Nome próprio e endereço livre exigem abordagem estatística |
| P-03 | Pseudonimização reversível é aceitável ao jurídico | Se não for, resta bloqueio, com perda de utilidade |
| P-04 | Latência do provedor domina o tempo total, tornando o overhead do gateway pouco perceptível | Se falsa, o orçamento de latência precisa ser revisto |

---

## 9. Decomposição em serviços

| Serviço | Responsabilidade | Por que separado |
|---|---|---|
| **Plano de dados** (gateway) | Caminho crítico da requisição: política, PII, roteamento, fallback | Stateless, sensível a latência, escala com tráfego |
| **Plano de controle** (policy service) | CRUD e validação de política, distribuição de configuração | Frequência de uso ordens de grandeza menor; eixo de escala oposto; falha não pode derrubar o tráfego |
| **Serviço de auditoria** | Consumo assíncrono da trilha, persistência, encadeamento de hash | Requisito de durabilidade e retenção distinto; não pode bloquear o caminho crítico |

**Parei em três de propósito.** Cada fatiamento adicional adiciona custo operacional,
latência de rede e superfície de falha sem ganho correspondente neste domínio.

---

## 10. Matriz de rastreabilidade

| Requisito | Decisão arquitetural | Componente |
|---|---|---|
| RF-01, RNF-14 | Proxy transparente no contrato do provedor | Plano de dados: adapter de protocolo |
| RF-02 | Identidade de serviço, política resolvida no ingresso | Plano de dados: policy resolver |
| RF-03, RF-04, RNF-06, RNF-07 | Detecção determinística com validação de dígito verificador, não LLM | Plano de dados: PII engine |
| RF-05, P-03 | Cofre de tokens de curta duração em memória distribuída | Plano de dados + Redis |
| RF-06, RF-07 | Contador distribuído com janela deslizante | Plano de dados + Redis |
| RF-08, RNF-08, RNF-09, RNF-10 | Escrita assíncrona via fila, trilha append-only encadeada por hash | Serviço de auditoria + fila + Postgres |
| RF-09, RNF-05 | Circuit breaker por provedor, roteamento com prioridade | Plano de dados: router |
| RF-10, RNF-13 | Política declarativa versionada, recarga a quente | Plano de controle |
| RF-11, RNF-11 | Instrumentação OpenTelemetry desde o primeiro commit | Todos |
| RF-12 | Criptografia por titular com destruição de chave | Serviço de auditoria |
| RNF-04 | Separação de planos; degradação do controle não afeta dados | Decomposição em 3 serviços |
| RNF-01, RNF-02, RNF-03 | Cadeia de políticas síncrona enxuta; tudo o mais assíncrono | Plano de dados |

Esta matriz é o artefato central do documento: evidência de que cada decisão técnica
responde a um requisito, e não a preferência pessoal.

---

## 11. Escopo da implementação de referência v0.1

**Implementado e executável:** plano de dados completo, PII engine, rate limit e budget
cap, fallback entre dois provedores, trilha de auditoria, política em YAML, telemetria.
Docker Compose, Python, FastAPI, Redis, Postgres.

**Documentado como arquitetura alvo, não implementado:** provisionamento AWS completo,
autoscaling, WAF, alta disponibilidade multi-AZ, crypto-shredding do RF-12.

**Janela AWS:** provisionamento temporário para medição real, com destruição imediata
após captura de métricas. IaC em Terraform, declarada como projeto próprio, jamais como
uso em produção.

---

## 12. Critérios de aceite da v0.1

1. Requisição atravessa o gateway com PII mascarada e resposta re-hidratada corretamente
2. RNF-01 medido e publicado, atingido ou não
3. RNF-07 medido contra dataset sintético e publicado
4. Provedor primário derrubado manualmente resulta em fallback sem erro ao consumidor
5. Toda requisição do teste de carga tem registro correspondente na trilha
6. Política alterada em arquivo é aplicada sem reinício
7. Repositório com README, diagramas C4 em código e este documento

---

## 13. Lacunas abertas

| Lacuna | Impacto | Como resolver |
|---|---|---|
| Normativos setoriais vigentes | Risco de citar norma errada em publicação | Consulta a fonte oficial antes do conteúdo correspondente |
| Dataset sintético de PII brasileira | Sem ele não há RNF-07 | Gerar com dados fictícios válidos por dígito verificador |

---

*Documento vivo. Alterações relevantes são registradas em `docs/adr/`.*
