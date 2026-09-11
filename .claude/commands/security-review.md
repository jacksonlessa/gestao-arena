Execute uma revisão de segurança focada em: $ARGUMENTS

Use o sub-agente `security-auditor` para executar a auditoria completa.

# Workflow

1. Mapeie fronteiras de confiança e pontos de entrada sensíveis.
2. Verifique validação de input e exposição de output.
3. Revise uso de secrets e variáveis de ambiente.
4. Confronte com as regras de security e LGPD do CLAUDE.md.
5. Produza correções priorizadas.

# Escopo prioritário

- Mudanças em auth, guards JWT, rotas de API
- Parsing de input em boundaries externas
- Uso de secrets e `.env`
- Scripts de deploy e workflows CI/CD

# Report

- Escopo auditado
- Ameaças identificadas (com file:line)
- Correções obrigatórias
- Recomendações de hardening opcionais
