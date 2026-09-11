Crie o TechSpec para a feature com slug: $ARGUMENTS

# Pré-condições

Verificar antes de iniciar — abortar com mensagem clara se ausente:
- `tasks/prd-$ARGUMENTS/prd.md` deve existir

# Workflow

## 1. Ler e analisar o PRD

- Leia o PRD completo em `tasks/prd-<slug>/prd.md`
- Extraia: requisitos funcionais, restrições, critérios de sucesso, itens fora de escopo

## 2. Análise profunda do projeto

Inspecione o código relevante para a feature:
- Módulos afetados em `backend/src/` e `front/src/`
- Services, DTOs, modelos Prisma, rotas e componentes existentes
- Pontos de integração e dados compartilhados
- Consulte CLAUDE.md para convenções do projeto

Consulte Context7 para Next.js, NestJS ou Prisma antes de propor decisões de arquitetura.

## 3. Clarificações técnicas (somente quando crítico)

- Fronteiras de domínio e ownership de módulo
- Fluxo de dados e definição de contratos
- Dependências externas e modos de falha
- Foco da estratégia de testes

## 4. Redigir o TechSpec

Use `ia-docs/templates/techspec-template.md` como estrutura exata.
- Foco em COMO implementar (o PRD é dono do quê/por quê)
- Inclua: arquitetura, design de componentes, endpoints de API, modelos de dados, pontos de integração, análise de impacto, estratégia de testes
- Mantenha em torno de 2.000 palavras

## 5. Salvar o artefato

- Salve como `tasks/prd-<slug>/techspec.md`
- Confirme o caminho salvo.

## 6. Report final

```
TechSpec salvo: tasks/prd-<slug>/techspec.md

Decisões arquiteturais-chave:
- [decisão 1]

Riscos:
- [risco 1]

Próximo passo: /create-tasks <slug>
```
