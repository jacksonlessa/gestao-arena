# Gestão de Arena

SaaS de gestão para arenas esportivas. Ver `CLAUDE.md` para arquitetura e
convenções, `docs/` para regras de produto e `tasks/` para os PRDs.

## Subir o ambiente local

Pré-requisitos: Node 22+, Docker.

```bash
cp backend/.env.example backend/.env
cp front/.env.example  front/.env.local

npm run setup          # sobe o MySQL, instala tudo, aplica migrações
npm run dev:backend    # porta 3001
npm run dev:front      # porta 3000  (em outro terminal)
```

## Conferir se está tudo de pé

Três verificações independentes. As duas primeiras chamam a terceira a partir do
navegador, com credenciais — é isso que prova que CORS e conectividade estão
corretos, e não só que os processos subiram.

| O quê | Onde |
|---|---|
| Operação | http://arenas.localhost:3000/healthcheck |
| Backoffice | http://backoffice-arenas.localhost:3000/healthcheck |
| API | http://localhost:3001/health |

`*.localhost` resolve para 127.0.0.1 sozinho nos navegadores atuais. Se o seu não
resolver, adicione ao `/etc/hosts`:

```
127.0.0.1 arenas.localhost backoffice-arenas.localhost
```

### A separação entre as superfícies deve falhar quando testada

Estas duas URLs precisam devolver **404**. Se servirem conteúdo, o middleware
está quebrado e as duas aplicações deixaram de estar separadas:

- http://arenas.localhost:3000/backoffice
- http://backoffice-arenas.localhost:3000/operacao

## Produção

| Superfície | Domínio |
|---|---|
| Operação | `arenas.entretimes.com.br` |
| Backoffice | `backoffice-arenas.entretimes.com.br` |
| API | `arenas-api.entretimes.com.br` |

Front na Vercel: um projeto só, Root Directory `front`, com os dois domínios
apontados para ele. Backend no DigitalOcean por GitHub Actions.

Segredos necessários no repositório: `DO_HOST`, `DO_USER`, `DO_SSH_KEY`,
`DO_APP_PATH`.
