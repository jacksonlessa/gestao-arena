Faça uma revisão técnica do seguinte escopo: $ARGUMENTS

Use o sub-agente `code-reviewer` para executar a revisão completa.

# Workflow

1. Identifique o app afetado (`front` ou `back`) e a camada impactada.
2. Verifique conformidade com as regras em CLAUDE.md (especialmente security, testing, LGPD).
3. Valide fronteiras de arquitetura (sem fat controllers, sem lógica de negócio em páginas).
4. Liste findings por severidade: critical, high, medium, low.
5. Sugira correções concretas com justificativa.

# Comandos de Verificação

```bash
npm run build --prefix front
npm run lint --prefix backend
npm run test --prefix backend
```

# Output

- Resumo do escopo
- Checklist de findings
- Riscos e regressões
- Plano de ação recomendado
