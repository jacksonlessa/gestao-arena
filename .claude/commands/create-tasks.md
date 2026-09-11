Quebre a feature em tasks executáveis. Slug: $ARGUMENTS

# Pré-condições

Verificar antes de iniciar — abortar com mensagem clara se ausente:
- `tasks/prd-$ARGUMENTS/prd.md` deve existir
- `tasks/prd-$ARGUMENTS/techspec.md` deve existir

# Workflow

## 1. Ler os dois documentos

- Extraia do PRD: requisitos e critérios de aceite
- Extraia do TechSpec: componentes, modelos, endpoints, sequenciamento

## 2. Identificar unidades de task

Agrupe por domínio: `front` / `back` / `infra` / `docs`

Cada task deve ser:
- Completável de forma independente (início e fim claros)
- Focada em uma única responsabilidade
- Associada a critérios de aceite explícitos

## 3. Construir o grafo de dependências

Para cada task, identifique:
- `blocked_by`: IDs de tasks que devem completar primeiro
- `parallelizable`: se pode rodar em paralelo com tasks de outros domínios
- `unblocks`: quais tasks ela desbloqueia

## 4. Gerar arquivos

Use templates de `ia-docs/templates/`:
- `tasks-template.md` para `tasks.md`
- `task-template.md` para cada `<N>_task.md`

Salve tudo em `tasks/prd-<slug>/`:
- `tasks/prd-<slug>/tasks.md`
- `tasks/prd-<slug>/1_task.md`, `2_task.md`, etc.

Frontmatter de cada task:
```yaml
status: pending
parallelizable: true|false
blocked_by: ["X.0"]
```

## 5. Análise de paralelização

- Lane A (back): tasks X.0, Y.0
- Lane B (front): tasks Z.0
- Caminho crítico: tasks que bloqueiam mais trabalho downstream

## 6. Aguardar confirmação do usuário antes de finalizar

Apresente o resumo e grafo de dependências. Peça confirmação antes de marcar completo.

## 7. Report final

```
tasks.md salvo: tasks/prd-<slug>/tasks.md
Task files: tasks/prd-<slug>/1_task.md ... N_task.md

Caminho crítico: [X.0 -> Y.0 -> Z.0]
Lanes paralelas: [A: ..., B: ...]

Próximo passo: /run-next-task <slug>
```
