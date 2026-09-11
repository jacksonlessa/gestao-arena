Crie um PRD para a seguinte feature: $ARGUMENTS

# Workflow

## 1. Clarificação (obrigatório antes de escrever)

Faça as seguintes perguntas ao usuário antes de prosseguir:
- Qual problema essa feature resolve?
- Quem são os usuários primários?
- Quais são os fluxos e ações principais?
- O que está explicitamente FORA de escopo?
- Há restrições técnicas ou de compliance (LGPD, performance, integrações)?

Somente prossiga com respostas suficientes para escrever o PRD sem adivinhar.

## 2. Determinar o slug

Derive um identificador curto, lowercase, kebab-case a partir do nome da feature.
Exemplo: "Checkout de planos" → `checkout-planos`

## 3. Redigir o PRD

Use `ia-docs/templates/prd-template.md` como estrutura exata.
- Foco em O QUÊ e POR QUÊ — nunca COMO (isso pertence ao TechSpec).
- Inclua requisitos funcionais numerados.
- Mantenha o documento em torno de 1.000 palavras.

## 4. Salvar o artefato

- Crie o diretório `tasks/prd-<slug>/`
- Salve como `tasks/prd-<slug>/prd.md`
- Confirme o caminho salvo.

## 5. Report final

```
PRD salvo: tasks/prd-<slug>/prd.md

Decisões-chave:
- [decisão 1]

Questões em aberto:
- [questão 1]

Próximo passo: /create-techspec <slug>
```
