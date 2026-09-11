Execute a próxima task disponível da feature. Slug (e opcionalmente task ID): $ARGUMENTS

# Pré-condições

Verificar antes de iniciar — abortar com mensagem clara se ausente:
- `tasks/prd-<slug>/prd.md`
- `tasks/prd-<slug>/techspec.md` — obrigatório, salvo quando o `prd.md` declarar
  explicitamente que dispensa techspec (PRDs sem decisão de design real)
- `tasks/prd-<slug>/tasks.md`
- Pelo menos um `<N>_task.md` com `status: pending`

# Workflow

## 1. Carregar o grafo de tasks

Leia `tasks.md` e todos os `<N>_task.md`. Para cada task colete:
- `id`, `status`, `parallelizable`, `blocked_by`, domínio

## 2. Resolver tasks disponíveis

Uma task está disponível quando:
- `status: pending`
- Todos os IDs em `blocked_by` têm `status: completed`

Se um task ID específico foi fornecido, valide que está disponível antes de prosseguir.

## 3. Plano de execução (apresentar ao usuário antes de iniciar)

```
Plano de execução:
  Lane A (back): 1.0 → 3.0
  Lane B (front): 2.0
  Bloqueadas: 4.0 (aguarda 1.0, 2.0)
```

Máximo 2 lanes simultâneas. Tasks no mesmo domínio rodam sequencialmente.

## 4. Executar cada task

### 4a. Marcar in-progress
Atualize o frontmatter do `<N>_task.md`:
```yaml
status: in-progress
```
Atualize o checkbox em `tasks.md`.

### 4b. Implementar
Use o sub-agente `task-implementer` passando:
- Caminho do task file, PRD, TechSpec e slug

O agente implementa, roda quality gates (lint + test + build) e **faz o commit das mudanças**.

### 4c. Revisar por bloco

A revisão acontece **por bloco de tarefas**, não por tarefa.

Um bloco fecha no que vier primeiro:
- todas as tarefas disponíveis do mesmo domínio foram implementadas;
- o bloco chegou a 4 tarefas;
- não há mais tarefa desbloqueada.

Ao fechar o bloco, invoque o sub-agente `task-reviewer` **uma vez**, passando a
lista de tarefas do bloco e o diff acumulado. Ele gera
`tasks/prd-<slug>/<N>-<M>_bloco_review.md` e **commita o arquivo de review**.

> Por que por bloco: o reviewer relê PRD e TechSpec a cada invocação, e o
> contexto dele não é reaproveitado entre chamadas. Revisar por bloco corta a
> maior parte dessas releituras — e costuma achar mais, porque um review que
> enxerga o conjunto pega inconsistência entre arquivos que o review de
> fragmento não tem como ver.

### 4d. Avaliar resultado da revisão
- Review do bloco aprovada → marcar **todas as tarefas do bloco** como `completed`, atualizar os checkboxes em `tasks.md`, fazer commit de status
- Findings críticos/altos → retornar ao `task-implementer` apenas para as tarefas apontadas (novo commit de fix), depois re-revisar o bloco (novo commit de review)
- NÃO marcar nenhuma tarefa do bloco como completed até a revisão aprovar explicitamente

### 4e. Commit de status após aprovação
Quando a review aprovar, atualize `tasks.md` e o `<N>_task.md` (se ainda não estiver como `completed`) e faça:

```
git add tasks/prd-<slug>/tasks.md tasks/prd-<slug>/<N>_task.md
git commit -m "$(cat <<'EOF'
chore(<slug>:<N>): mark task <N>.0 as completed

EOF
)"
```

> Se o `task-implementer` já tiver commitado o `<N>_task.md` com `status: completed`, inclua apenas o `tasks.md` no stage.

## 5. Desbloquear próximas tasks

Após cada task `completed`, re-avalie o grafo. Repita até todas as tasks estarem `completed` ou `excluded`.

## 6. Report final

```
Feature: <slug>
Completadas: [lista de IDs]
Excluídas: [lista com razões]
Restantes: [lista se houver]

Review files: tasks/prd-<slug>/1_task_review.md ...

Feature pronta para revisão de deploy.
```
