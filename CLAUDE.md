# Gestão de Arena

SaaS de gestão operacional e financeira para estabelecimentos que alugam campos e
quadras por horário. O usuário principal é quem **opera** a arena — proprietário,
gerente, recepcionista, caixa. Agendamento público não é o centro do produto.

Regras de produto e decisões: `docs/`. Épico e requisitos: `docs/epico-backoffice-provedor/`
e `tasks/`.

## Stack

| Camada | Tecnologia |
|---|---|
| Backend | NestJS 11, Prisma 6, MySQL 8.0, Jest |
| Frontend | Next.js 16 (App Router), React 19, Tailwind 4, Jest |
| Banco local | MySQL em contêiner (`docker compose`), mesma versão da produção |
| Publicação | Vercel (front) · GitHub Actions → DigitalOcean (backend) |

## Arquitetura

Monorepo único: `front/`, `backend/`, `docs/`, `ia-docs/`, `tasks/`. Um repositório
git só — mudança que atravessa front e back é um commit só.

### Duas superfícies, um build

| Superfície | Domínio | Prefixo físico |
|---|---|---|
| Operação | `arenas.entretimes.com.br` | `front/src/app/operacao` |
| Backoffice | `backoffice-arenas.entretimes.com.br` | `front/src/app/backoffice` |
| API | `arenas-api.entretimes.com.br` | `backend/` |

`front/src/middleware.ts` reescreve por host **e recusa o prefixo físico do outro
host com 404**. Sem essa segunda metade, a separação não existe — não remova.

Em desenvolvimento os hosts são `arenas.localhost` e `backoffice-arenas.localhost`,
que resolvem para 127.0.0.1 sem mexer em `/etc/hosts`.

Os três domínios compartilham o domínio registrável `entretimes.com.br`, portanto
são **same-site**: os cookies usam `SameSite=Lax`. Nunca troque para `SameSite=None`
sem entender que isso desliga a proteção contra CSRF entre sites.

### Backend (`backend/src/`)

Módulos por domínio, padrão NestJS: `*.controller.ts` fino, `*.service.ts` com a
regra, `*.module.ts` para wiring, `dto/*.dto.ts` com `class-validator`,
`*.spec.ts` ao lado do arquivo testado.

## Invariantes do domínio

Estas valem para todo código novo. Quebrar qualquer uma delas é bug, não estilo.

1. **Isolamento por organização.** Toda tabela operacional tem `organizacaoId`
   obrigatório. O banco não oferece isolamento em nível de linha — a garantia vive
   inteiramente na aplicação. Consulta sem organização em contexto deve **lançar
   erro**, nunca retornar dados.
2. **Um único `PrismaClient`**, dentro de `PrismaService`. Nunca instancie fora.
3. **Estado financeiro é derivado**, nunca campo editável. Situação de fatura sai da
   soma dos pagamentos; nunca de um `update`.
4. **Dado financeiro consumado é imutável.** Correção é lançamento de ajuste ou
   estorno — nunca edição, nunca exclusão.
5. **Preço é snapshot** no momento em que a cobrança nasce. Reajuste de tabela não
   altera o passado.
6. **Datas em UTC**, tipo sem conversão implícita, convertidas na borda. O fuso
   relevante é o da **unidade**, não o do usuário.
7. **Dinheiro em decimal exato.** Nunca ponto flutuante.
8. **CORS com lista explícita de origens**, por superfície, com credenciais. Nunca
   curinga.

## Convenções

- Prettier: aspas simples, trailing comma em tudo, igual nos dois lados
- TypeScript com `strictNullChecks`; decorators no backend
- Testes nomeados `should <comportamento> when <condição>`
- Conventional Commits com escopo `<slug>:<N>` referenciando a tarefa
- Detalhes em `.claude/rules/code-style.md` e `.claude/rules/testing.md`

## Fluxo de trabalho

`/create-prd` → `/create-techspec` → `/create-tasks` → `/run-next-task`, com duas
diferenças em relação ao EntreTimes:

- **Techspec só quando há decisão de design real.** Se a implementação cabe em três
  frases, o techspec vira transcrição do PRD. Nesse caso o `prd.md` declara que
  dispensa techspec.
- **Revisão por bloco de tarefas, não por tarefa.** Ver `.claude/commands/run-next-task.md`.

Durante a Fase 1 o trabalho vai direto para `main`. Quando a primeira arena real
entrar em produção, o pipeline passa a recusar publicação com teste vermelho — o
que já está configurado — e vale reavaliar branch de feature.

## Scripts

| Comando | O que faz |
|---|---|
| `npm run setup` | sobe o MySQL, instala dependências, gera o client e aplica migrações |
| `npm run dev:backend` | backend em watch (porta 3001) |
| `npm run dev:front` | frontend em dev (porta 3000) |
| `npm run lint` / `test` / `build` | quality gates dos dois lados |
| `npm run db:up` / `db:down` | apenas o contêiner do banco |

## O que não fazer

- Não colocar regra de negócio em controller nem em `app/**/page.tsx`
- Não instanciar Prisma fora do `PrismaService`
- Não commitar `.env`, segredos ou valores reais em `.env.example`
- Não usar `git add -A` em commit de tarefa — stage explícito
- Não pular lint, teste e build antes de marcar tarefa como completa
- Não criar um segundo schema Prisma para desenvolvimento
