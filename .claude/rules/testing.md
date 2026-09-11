# Testing

Regras específicas do EntreTimes. Ver também [../../CLAUDE.md](../../CLAUDE.md).

## Backend (Jest)

- Testes unitários colocados ao lado do arquivo testado: `teams.service.ts` → `teams.service.spec.ts`, `create-team.dto.ts` → `create-team.dto.spec.ts`
- Testes e2e em `backend/test/`, rodados com `npm run test:e2e --prefix backend` (config própria: `test/jest-e2e.json`)
- Rodar `npm run test --prefix backend` antes de finalizar qualquer tarefa que toque `backend/`
- Mockar apenas fronteiras externas (Prisma/DB, rede, tempo) — nunca mockar a regra de negócio sendo testada
- Nomear casos como `should <comportamento> when <condição>`
- Cobrir happy path, erros esperados (validação, permissão) e edge cases relevantes ao domínio (ex.: expiração de convite, limites do plano gratuito vs Pro)

## Frontend (Jest + jsdom)

- Rodar `npm run test --prefix front` para os testes existentes; `npm run build --prefix front` também funciona como gate de tipos
- Testes de lógica pura ficam em `front/src/lib/__tests__/*.test.ts` (ex.: `card-availability.test.ts`, `og-metadata.test.ts`)
- Priorizar testes de comportamento para os fluxos de conversão (cadastro, cards, compartilhamento) — não é necessário cobrir toda página de CRUD administrativo com o mesmo rigor
- Evitar snapshot tests amplos; preferir asserções específicas de comportamento

## Quality Gates por Tarefa

Antes de marcar uma tarefa como `completed`:

- [ ] `npm run lint --prefix backend` (se arquivos de `backend/` mudaram)
- [ ] `npm run test --prefix backend` (se arquivos de `backend/` mudaram)
- [ ] `npm run build --prefix front` (se arquivos de `front/` mudaram)
- [ ] Testes adicionados/atualizados cobrindo o comportamento alterado
