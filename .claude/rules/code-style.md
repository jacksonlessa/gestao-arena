# Code Style

Regras específicas do EntreTimes. Ver também [../../CLAUDE.md](../../CLAUDE.md).

## Formatação

- Prettier: aspas simples (`singleQuote: true`), trailing comma em tudo (`trailingComma: "all"`) — configs equivalentes em `backend/.prettierrc` e no ESLint do `front/`
- Rodar `npm run lint --prefix backend` (ESLint + Prettier, com `--fix`) e `npm run lint --prefix front` antes de finalizar qualquer tarefa
- `endOfLine: "auto"` no backend — não force LF/CRLF manualmente

## TypeScript

- Backend: `strictNullChecks` ativo, decorators experimentais habilitados (`emitDecoratorMetadata`), `noImplicitAny: false` — tipar explicitamente parâmetros e retornos de métodos públicos mesmo assim
- Frontend: segue `strict` padrão do Next.js/TypeScript
- `@typescript-eslint/no-explicit-any` está desligado no backend, mas evite `any` em código novo — prefira tipos do Prisma Client ou DTOs

## Backend (NestJS)

- Um módulo por domínio em `backend/src/<dominio>/` (ver módulos existentes: `teams`, `matches`, `player-links`, `venues`, `users`, `auth`, `moderation`, `reports`, `opponents`, `audit`, `mail`)
- `*.controller.ts` fino: delega para o service, não contém lógica de negócio nem acesso direto ao Prisma
- `*.service.ts` concentra a lógica de negócio; acesso a dados sempre via `PrismaService` injetado
- Entrada validada em `dto/*.dto.ts` com `class-validator`; validadores customizados ficam em `validators/*.validator.ts` ou `*.guard.ts` (ex.: `reserved-terms.guard.ts`)
- Nomes de arquivo em kebab-case (`contact-channel.dto.ts`, `crest-image-processing.spec.ts`)

## Frontend (Next.js)

- Rotas em `front/src/app/` usam nomes em português, refletindo a navegação do produto (`cadastro`, `conta/preferencias`, `partidas/[id]`, `times/[slug]`)
- Clientes de API centralizados em `front/src/lib/*-api.ts`, usando o `apiRequest`/`ApiResult` compartilhado em `api-client.ts` — não duplique essa lógica em um novo arquivo `*-api.ts`
- Componentes organizados por domínio em `front/src/components/<dominio>/` (`team`, `match`, `player`, `venue`, `account`), com `ui/` para primitivos reutilizáveis
- CRUD administrativo: decompor em Atomic Design (atoms/molecules/organisms implícitos na pasta do domínio)
- Fluxos de conversão (cadastro, cards, compartilhamento): Clean Code com UseCase explícito, não lógica solta em `page.tsx`

## Comentários

- Comentário apenas quando explica um porquê não óbvio (constraint, workaround, decisão de extração — ver cabeçalho de `front/src/lib/api-client.ts` como exemplo do nível de detalhe esperado quando a extração de código gera contexto não óbvio)
- Não comentar o que o código já deixa claro pelo nome dos identificadores
