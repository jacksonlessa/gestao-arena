# PRD — Acesso e Isolamento

## Visão Geral

Duas fundações que precisam nascer juntas: **quem entra** e **o que cada um
enxerga**.

O Gestão de Arena é multiempresa. Cada estabelecimento é uma organização, e nenhuma
organização pode enxergar dado de outra em nenhuma circunstância. O banco escolhido
não oferece isolamento em nível de linha, então essa garantia vive inteiramente na
aplicação — o que a torna a decisão de maior risco do sistema e a razão de ela vir
antes de qualquer entidade de negócio.

Junto vem a autenticação do staff do provedor, que é o primeiro login a existir, e a
trilha de auditoria, que precisa estar de pé antes da primeira ação sobre dado de
cliente.

Este PRD não cria organizações — cria a fundação sobre a qual elas serão criadas no
PRD seguinte.

## Objetivos

- Impedir, por construção e não por disciplina, que uma consulta retorne dado de
  outra organização.
- Dar ao staff do provedor um login isolado do login da operação, servido em outro
  host.
- Registrar toda ação relevante com autoria completa, incluindo ação feita em nome
  de outro usuário.

**Métricas de sucesso**

1. Teste automatizado de isolamento passando em CI, cobrindo todas as tabelas
   operacionais.
2. Consulta a dado operacional sem organização em contexto falha, em vez de retornar
   tudo.
3. Nenhuma ação sobre dado de cliente sem registro correspondente de auditoria.

## Histórias de Usuário

- Como staff do provedor, quero entrar no backoffice com e-mail e senha, para
  administrar as organizações.
- Como staff, quero recuperar minha senha por e-mail, para não depender de outra
  pessoa quando esquecer.
- Como provedor, quero que seja impossível uma organização ler dados de outra, mesmo
  que uma consulta futura esqueça o filtro.
- Como provedor, quero saber quem fez cada alteração e quando, para investigar
  problemas e responder a pedidos do cliente.

## Funcionalidades Principais

### 1. Autenticação do staff do provedor

- **RF01** — Autenticação por e-mail e senha, com sessão em cookie `HttpOnly`,
  usando token de acesso de vida curta e token de renovação opaco com hash
  armazenado.
- **RF02** — Estão disponíveis: login, logout, logout de todas as sessões,
  recuperação de senha e verificação de e-mail.
- **RF03** — Existem exatamente dois papéis de staff: `ADMIN`, com todas as ações, e
  `SUPORTE`, com leitura. Existe **um único** conceito de papel de plataforma no
  sistema.
- **RF04** — Login e recuperação de senha aceitam no máximo 5 tentativas por minuto.
- **RF05** — A resposta de recuperação de senha é sempre genérica, exista ou não o
  e-mail, para impedir enumeração de contas.
- **RF06** — Contas de staff não são criadas por interface; apenas por seed ou
  comando de linha.
- **RF07** — Os cookies do backoffice têm nomes distintos dos da operação. Como as
  duas superfícies conversam com a mesma API, o navegador envia ambos para lá; a
  separação real vem do nome do cookie, da audiência do token (RF08) e da validação
  de origem no servidor.
- **RF08** — O token carrega a audiência a que pertence. Token emitido para o
  backoffice é recusado em rota da operação, e vice-versa.
- **RF09** — A sessão do backoffice tem duração menor que a da operação.

### 2. Isolamento entre organizações

- **RF10** — Toda tabela operacional possui `organizacaoId` obrigatório e indexado.
  Tabelas escopadas por unidade possuem também `unidadeId`.
- **RF11** — Existe uma camada única de acesso a dados que injeta o filtro de
  organização a partir do contexto da requisição, sem depender de cada consulta
  lembrar de fazê-lo.
- **RF12** — Consulta a tabela operacional sem organização em contexto **lança
  erro** e nunca retorna dados.
- **RF13** — Rotas do backoffice que legitimamente atravessam organizações usam um
  caminho explícito e separado do caminho normal, e toda passagem por ele é
  auditada.
- **RF14** — Existe teste automatizado que varre o schema e **falha** se alguma
  tabela operacional não tiver `organizacaoId`.
- **RF15** — Existe teste de integração que, autenticado como organização A, tenta
  ler dado da organização B e espera erro ou resultado vazio.
- **RF16** — Ambos os testes rodam em CI e bloqueiam a publicação.

### 3. Auditoria

- **RF17** — Toda ação relevante gera registro com: ator, ator real, organização
  alvo, ação, tipo e identificador da entidade, estado anterior, estado posterior,
  motivo, origem e data.
- **RF18** — A origem distingue `OPERACAO`, `BACKOFFICE` e `SUPORTE_IMPERSONADO`.
- **RF19** — Quando a ação é feita em nome de outro usuário, o ator real e o ator
  são diferentes e ambos obrigatórios. Nos demais casos são iguais.
- **RF20** — Dados pessoais não são gravados nos campos de estado anterior e
  posterior quando não forem necessários para entender a mudança.
- **RF21** — Registro de auditoria nunca é alterado nem excluído pela aplicação.

## Experiência do Usuário

O staff acessa o host do backoffice, entra com e-mail e senha e chega a uma tela
autenticada mínima — a listagem de organizações vem no PRD seguinte. Recuperação de
senha segue o padrão de dois passos: solicitação com resposta genérica e link por
e-mail com token de uso único.

O isolamento e a auditoria não têm interface. São verificados por teste.

Interface do backoffice é ferramenta interna de desktop; densidade de informação vale
mais que polimento. Contraste adequado e navegação por teclado nos formulários.

## Restrições Técnicas de Alto Nível

- Autenticação, envio de e-mail transacional e auditoria são **adaptados por cópia**
  de um sistema existente do mesmo autor. Não há base de identidade compartilhada
  entre os dois produtos.
- O modelo de usuário copiado deve ser reduzido ao necessário: sem data de
  nascimento, que existia no sistema de origem por regras de menor de idade
  inexistentes aqui.
- Não replicar a coexistência de dois conceitos paralelos de papel administrativo do
  sistema de origem.
- O banco não oferece isolamento em nível de linha. A camada de RF11 é a única
  barreira, e os testes de RF14 a RF16 são obrigatórios, não opcionais.
- Dados pessoais não aparecem em logs nem em respostas de erro.

## Não-Objetivos (Fora de Escopo)

- Cadastro de organizações, unidades e espaços.
- Papéis de usuário da arena além da existência do vínculo; a matriz de permissões
  de gerente, atendente e financeiro vem depois.
- Segundo fator de autenticação. Ferramenta de um único operador em piloto de duas
  empresas; revisar quando houver staff além do provedor ou cliente pagante.
- Sessão de suporte assumindo outro usuário, que tem PRD próprio. Aqui só existe o
  campo de ator real que a tornará possível.
- Autocadastro e convite, que vêm com o cadastro de estabelecimento.
- Interface de consulta à auditoria.

## Questões em Aberto

1. Duração da sessão de backoffice e da sessão de operação.
2. Se o papel `SUPORTE` deve enxergar dados financeiros da carteira ou apenas
   cadastro.
3. Política mínima de senha do staff.
4. Se a auditoria fica na mesma base ou em base separada desde o início — decisão
   com efeito em volume e retenção.
