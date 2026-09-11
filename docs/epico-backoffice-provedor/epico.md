# PRD — Backoffice do Provedor

## Visão Geral

O Gestão de Arena é um SaaS de gestão operacional e financeira para estabelecimentos
que alugam campos e quadras por horário. Este PRD cobre o **Backoffice do Provedor**:
a área administrativa usada pela equipe do Gestão de Arena (hoje, uma pessoa) para
cadastrar estabelecimentos, controlar assinatura e liberar ou restringir o acesso de
cada cliente.

É a primeira fatia do produto porque nada existe sem ela — não há arena sem
organização cadastrada — e porque é ela que exercita ponta a ponta a decisão
estrutural mais arriscada do sistema: o isolamento de dados entre clientes.

O backoffice **não** é a aplicação que a arena usa. A operação diária (agenda,
reservas, clientes, caixa) é uma aplicação separada, servida em outro host, e será
especificada em PRDs próprios.

**Contexto do piloto:** duas arenas reais, por 12 meses, com assinatura de valor
R$ 0,00. Um único operador do provedor. Esse contexto justifica várias simplificações
deliberadas registradas em "Não-Objetivos".

## Objetivos

- Permitir que o provedor cadastre um estabelecimento completo (organização, unidade,
  espaços) e convide o proprietário, sem passar pelo banco de dados na mão.
- Garantir que uma organização nunca leia dados de outra, com barreira aplicada em
  camada única e testada automaticamente.
- Controlar o acesso de cada cliente a partir do ciclo de vida da conta e da situação
  da assinatura, sem intervenção manual em cada tela.
- Permitir que o provedor entre na conta do cliente para dar suporte e observar o uso
  real, com rastro completo de quem fez o quê.
- Registrar assinatura, faturas e pagamentos de forma que o piloto exercite o mesmo
  caminho de código de um cliente pagante.

**Métricas de sucesso**

1. Cadastrar uma arena completa e convidar o proprietário em menos de 10 minutos, sem
   acesso ao banco.
2. Teste automatizado de isolamento entre tenants passando em CI, com cobertura de
   todas as tabelas operacionais.
3. Nenhuma ação do provedor sobre dados de cliente sem registro de auditoria.
4. As seis empresas do ambiente de testes recriáveis por um comando idempotente.

## Histórias de Usuário

**Persona primária — Provedor (você).** Administra a carteira de clientes, cadastra
estabelecimentos, controla assinatura e presta suporte.

- Como provedor, quero entrar no backoffice com e-mail e senha, para administrar as
  organizações.
- Como provedor, quero cadastrar um estabelecimento com suas unidades e espaços, para
  que ele possa começar a usar o sistema.
- Como provedor, quero convidar o proprietário por e-mail, para que ele defina a
  própria senha sem eu conhecê-la.
- Como provedor, quero registrar o plano, gerar a fatura do período e dar baixa no
  pagamento, para acompanhar a situação comercial de cada cliente.
- Como provedor, quero que uma arena inadimplente perca a capacidade de operar sem
  perder o acesso à própria informação, para cobrar sem empurrá-la de volta ao caderno.
- Como provedor, quero entrar na conta da arena para ver o uso real e testar, sem
  manter um espelho do código nem pedir a senha do cliente.
- Como provedor, quero ver de relance quais clientes estão vencidos e quais convites
  estão parados, para saber o que fazer no dia.

**Persona secundária — Proprietário da arena.** Só aparece neste PRD no momento do
primeiro acesso.

- Como proprietário convidado, quero receber um link por e-mail, definir minha senha e
  aceitar os termos, para começar a usar o sistema.

**Ator fora de escopo neste PRD:** atendente, gerente, financeiro e o cliente final da
arena (jogador). Nenhum deles acessa o backoffice.

## Funcionalidades Principais

### 1. Autenticação do staff do provedor

Login próprio do backoffice, isolado do login da operação.

- **RF01** — O staff autentica com e-mail e senha, recebendo sessão via cookie
  `HttpOnly`.
- **RF02** — Existem dois papéis de staff: `ADMIN` (todas as ações) e `SUPORTE`
  (leitura e impersonation, sem alterar assinatura nem ciclo de vida). Deve existir
  **um único** conceito de papel de plataforma.
- **RF03** — Estão disponíveis: logout, logout de todas as sessões, recuperação de
  senha e verificação de e-mail.
- **RF04** — Rotas sensíveis (login e recuperação de senha) têm limite de 5 tentativas
  por minuto.
- **RF05** — A resposta de "esqueci a senha" é sempre genérica, exista ou não o e-mail
  cadastrado, para impedir enumeração de contas.
- **RF06** — Contas de staff não são criadas por interface. São criadas por seed ou
  comando de linha.

### 2. Isolamento multiempresa

A funcionalidade de maior risco do sistema. O banco escolhido não oferece Row-Level
Security, portanto **todo o isolamento vive na aplicação**.

- **RF07** — Toda tabela operacional possui `organizacaoId` obrigatório e indexado.
  Tabelas escopadas por unidade possuem também `unidadeId`.
- **RF08** — O acesso a dados operacionais passa por uma camada única que injeta o
  filtro de organização a partir do contexto da requisição.
- **RF09** — Consulta a tabela operacional sem organização em contexto **lança erro** e
  nunca retorna dados.
- **RF10** — As rotas do backoffice que legitimamente atravessam organizações usam um
  caminho explícito e auditado, distinto do caminho normal.
- **RF11** — Existem dois testes automatizados obrigatórios: (a) varredura do schema
  que falha se alguma tabela operacional não tiver `organizacaoId`; (b) teste de
  integração que, autenticado como organização A, tenta ler dado da organização B e
  espera erro ou resultado vazio.

### 3. Auditoria

- **RF12** — Toda ação relevante gera registro com: ator, ator real, organização alvo,
  ação, tipo e id da entidade, estado anterior, estado posterior, motivo, origem e
  data.
- **RF13** — A origem distingue `OPERACAO`, `BACKOFFICE` e `SUPORTE_IMPERSONADO`.
- **RF14** — Quando a ação ocorre em modo suporte, o ator real é o staff e o ator é o
  usuário assumido. Os dois são obrigatórios nesse caso.
- **RF15** — Dados pessoais não são gravados nos campos de estado anterior/posterior
  quando não forem necessários para entender a mudança.

### 4. Organizações

- **RF16** — Cadastro com: razão social, nome fantasia, documento, contato (nome,
  e-mail, telefone), fuso horário padrão e observações internas.
- **RF17** — O documento é validado quanto ao formato. Documento repetido **avisa mas
  não bloqueia** — o mesmo grupo pode operar sob CNPJs diferentes.
- **RF18** — A organização nasce no estado `EM_IMPLANTACAO`.
- **RF19** — Listagem com busca por nome ou documento e filtros por ciclo de vida e
  situação da assinatura.
- **RF20** — Cada linha da listagem exibe: nome, número de unidades, número de espaços
  ativos, ciclo de vida, situação da assinatura e dias de atraso.

### 5. Unidades

- **RF21** — Cadastro com: nome, endereço, fuso horário, horário de funcionamento
  padrão e situação ativa/inativa.
- **RF22** — A primeira unidade é criada junto com a organização, herdando o nome dela.
- **RF23** — Unidade com espaços vinculados não pode ser removida, apenas inativada.

### 6. Espaços e recursos físicos

O sistema atende campos, quadras e áreas de modalidades diferentes, e alguns espaços
compartilham a mesma área física — um campo de futebol que também é alugado como dois
campos de society. A disponibilidade precisa refletir isso.

- **RF24** — Espaço possui: nome, modalidade, situação ativa/inativa, duração sugerida
  de reserva, ordem de exibição e observações internas.
- **RF25** — Existe a entidade **RecursoFísico**, pertencente à unidade, representando
  a menor área de uso exclusivo. Ela é interna e nunca aparece para o operador da
  arena.
- **RF26** — Um espaço consome um conjunto de recursos físicos (relação N:N). Espaço
  criado pelo caminho simples recebe automaticamente um recurso próprio e exclusivo.
- **RF27** — Existe, apenas no backoffice, uma interface avançada para montar espaços
  que compartilham recursos.
- **RF28** — Espaço sem nenhum recurso associado é inválido.
- **RF29** — A regra de conflito de agenda, a ser usada pelos PRDs seguintes, é:
  **duas reservas conflitam quando se sobrepõem no tempo e os conjuntos de recursos de
  seus espaços têm interseção não vazia.**

### 7. Convite e primeiro acesso do proprietário

- **RF30** — O provedor dispara um convite por e-mail para o proprietário.
- **RF31** — O convite usa token de uso único, com hash armazenado e validade
  configurável.
- **RF32** — Ao aceitar, o proprietário define senha, aceita os termos (com registro de
  versão e data) e recebe vínculo com papel `PROPRIETARIO`.
- **RF33** — O aceite move a organização de `EM_IMPLANTACAO` para `ATIVA`.
- **RF34** — O reenvio de convite invalida o token anterior. Convite expirado exibe
  tela própria com opção de solicitar novo.

### 8. Assinatura

- **RF35** — Uma organização tem várias assinaturas ao longo do tempo, com **uma
  vigente por vez**. A situação da assinatura vive na assinatura, não na organização.
- **RF36** — Assinatura possui: plano (rótulo), ciclo (`MENSAL` ou `ANUAL`), valor
  base, valor negociado, limite de unidades, limite de espaços, dias de tolerância, dia
  de vencimento, início e fim de vigência.
- **RF37** — A situação (`EM_DIA` ou `VENCIDA`) é **derivada** das faturas em aberto e
  seus vencimentos. Nunca é um campo editável.
- **RF38** — Assinaturas de piloto usam valor negociado `0,00`. Não existe estado de
  isenção.
- **RF39** — Trocar de plano encerra a assinatura vigente e cria uma nova, preservando
  o histórico.
- **RF40** — Criar unidade ou espaço além do limite da assinatura vigente é bloqueado,
  com mensagem indicando o upgrade. Reduzir o limite abaixo do uso atual é permitido
  com aviso e **nunca inativa** unidade ou espaço existente.

### 9. Faturas da assinatura

- **RF41** — Fatura possui: competência, valor, vencimento, situação e observação.
- **RF42** — A fatura é gerada **manualmente**, por ação do provedor. Não há rotina
  agendada.
- **RF43** — É bloqueada a geração de fatura duplicada para a mesma competência da
  mesma assinatura.
- **RF44** — O valor da fatura é um snapshot do valor negociado no momento da geração e
  não muda se o plano for reajustado depois.
- **RF45** — Cancelar fatura exige motivo e mantém o registro. Fatura nunca é excluída.

### 10. Pagamentos da fatura

- **RF46** — Uma fatura admite **um ou mais** pagamentos, com valor, data, meio e
  observação.
- **RF47** — A situação da fatura (`ABERTA`, `PARCIAL`, `PAGA`, `CANCELADA`) é derivada
  da soma dos pagamentos comparada ao valor. Nunca é um campo editável.
- **RF48** — Estorno é registrado como lançamento de reversão, nunca como exclusão.
- **RF49** — Fatura de valor `0,00` aceita pagamento de `0,00`, percorrendo o mesmo
  caminho de uma fatura paga de verdade.

### 11. Nível de acesso derivado

- **RF50** — O nível de acesso da arena é calculado no servidor, a cada requisição, a
  partir do ciclo de vida da organização e da situação da assinatura, conforme:

  | Ciclo de vida | Situação | Atraso | Acesso |
  |---|---|---|---|
  | `EM_IMPLANTACAO` | — | — | apenas o link de convite |
  | `ATIVA` | `EM_DIA` | — | total |
  | `ATIVA` | `VENCIDA` | ≤ tolerância | total, com aviso discreto |
  | `ATIVA` | `VENCIDA` | > tolerância | somente leitura, com aviso persistente |
  | `SUSPENSA` | — | — | apenas exportação dos próprios dados |
  | `ENCERRADA` | — | — | nenhum |

- **RF51** — Em modo somente leitura, toda rota de escrita da operação responde 403 com
  código específico, e a interface exibe aviso persistente.
- **RF52** — **Não existe bloqueio total enquanto a organização está `ATIVA`.**
- **RF53** — A exportação dos próprios dados fica disponível até o encerramento,
  inclusive em organização suspensa.
- **RF54** — O nível de acesso nunca é decidido apenas no cliente.

### 12. Ciclo de vida da organização

- **RF55** — Transições permitidas: `EM_IMPLANTACAO → ATIVA`; `ATIVA ↔ SUSPENSA`;
  `ATIVA` ou `SUSPENSA → ENCERRADA`. `ENCERRADA` é terminal.
- **RF56** — Suspender e encerrar exigem motivo obrigatório, registrado em auditoria.
- **RF57** — Encerrar não apaga dados: inicia período de retenção de **12 meses**,
  após o qual os dados pessoais são anonimizados.
- **RF58** — No momento do encerramento, a exportação completa dos dados é oferecida
  ativamente ao cliente.

### 13. Acesso à organização como suporte

- **RF59** — A partir da ficha da organização, o staff pode iniciar uma sessão de
  suporte assumindo um usuário daquela organização.
- **RF60** — A sessão de suporte é separada da sessão de backoffice, tem validade curta
  e é encerrada explicitamente.
- **RF61** — Em toda tela, durante a sessão de suporte, é exibido aviso fixo e
  visualmente inconfundível com: organização acessada, usuário assumido, tempo restante
  e ação de sair do modo suporte.
- **RF62** — Existem dois modos: **somente leitura** (padrão) e **leitura e escrita**,
  este exigindo motivo registrado.
- **RF63** — Toda ação é gravada com ator real (staff), ator (usuário assumido) e
  origem `SUPORTE_IMPERSONADO`.
- **RF64** — Durante a sessão de suporte é **proibido**: alterar senha, criar ou
  remover usuários, alterar assinatura e aceitar termos.
- **RF65** — Início e fim da sessão de suporte são registrados, com duração.
- **RF66** — A possibilidade de acesso para suporte é prevista no termo de uso aceito
  pela arena.

### 14. Ambiente de testes

- **RF67** — Existe um comando idempotente que recria as empresas de teste:

  | Empresa | Configuração | O que valida |
  |---|---|---|
  | A | 1 unidade, 1 society | caso mínimo; formato do piloto 1 |
  | B | 2 unidades, 1 society cada | multi-unidade |
  | C | 1 unidade; campo de futebol que vira 2 society + 1 society independente | recursos compartilhados convivendo com espaço independente |
  | D | 1 unidade, 2 society | dois espaços independentes |
  | E | 1 unidade, 2 society + 1 beach tênis | multi-modalidade; formato do piloto 2 |
  | F | 1 unidade, 1 society, assinatura vencida além da tolerância | acesso degradado |

- **RF68** — A configuração de recursos da empresa C é: recursos `A`, `B` e `S3`; campo
  de futebol consome `{A, B}`; Society 1 consome `{A}`; Society 2 consome `{B}`;
  Society 3 consome `{S3}`.
- **RF69** — O comando cria também um usuário staff `ADMIN` e um proprietário por
  empresa, com credenciais conhecidas apenas em ambiente de desenvolvimento.

### 15. Painel inicial do backoffice

- **RF70** — Contadores: organizações por ciclo de vida, organizações por situação de
  assinatura e total de espaços ativos na carteira.
- **RF71** — Lista de faturas vencidas, ordenada por dias de atraso.
- **RF72** — Lista de organizações em implantação com convite pendente há mais de um
  número configurável de dias.

## Experiência do Usuário

**Fluxo principal — implantar uma arena.** O provedor cadastra a organização, confirma
a unidade criada automaticamente, cadastra os espaços, define a assinatura e dispara o
convite. O proprietário recebe o e-mail, define a senha, aceita os termos e entra na
aplicação de operação. Nesse momento a organização passa a `ATIVA`.

**Fluxo de acompanhamento.** O provedor abre o painel, vê faturas vencidas e convites
parados, entra na organização que precisa de atenção, gera a fatura da competência ou
registra o pagamento.

**Fluxo de suporte.** Da ficha da organização, o provedor inicia sessão de suporte em
modo leitura, observa o uso real e, quando precisa reproduzir um problema, troca para
modo escrita informando o motivo. O aviso fixo acompanha toda a navegação.

**Considerações de interface**

- O backoffice é ferramenta interna de um único operador. Densidade de informação vale
  mais que polimento visual: tabelas, filtros e formulários diretos.
- O aviso de sessão de suporte precisa ser impossível de ignorar — cor distinta,
  posição fixa, presente em todas as telas.
- O aviso de inadimplência exibido para a arena precisa ser firme sem ser hostil: ela
  continua enxergando a própria operação.
- Uso em desktop. Responsividade não é requisito do backoffice.
- Contraste e navegação por teclado nos formulários.

## Restrições Técnicas de Alto Nível

- **Hosts separados.** Operação em `arenas.entretimes.com.br`; backoffice em
  `backofficearenas.entretimes.com.br`. São origens distintas para o navegador,
  permitindo proteção adicional apenas no backoffice.
- **Sessões isoladas.** Cookies host-only, nomes distintos entre operação e backoffice,
  e verificação de audiência no token: um token de operação é recusado em rota de
  backoffice e vice-versa.
- **Sem Row-Level Security no banco.** O isolamento entre organizações é
  responsabilidade integral da aplicação. Os testes de RF11 são obrigatórios, não
  opcionais.
- **Datas e fusos.** Instantes armazenados em UTC, com conversão nas bordas. O fuso
  relevante é o da **unidade**, não o do usuário.
- **Valores monetários** em tipo decimal exato. Nunca ponto flutuante.
- **Um único schema de banco** para desenvolvimento e produção, com banco local em
  contêiner.
- **Deploy contínuo a partir da branch principal**, com filtros de caminho para que
  alterações restritas a um dos lados não disparem o deploy do outro.
- **LGPD.** A arena é controladora dos dados de seus clientes; o provedor é operador.
  Dados pessoais não aparecem em logs nem em respostas de erro. Exportação e
  anonimização conforme RF53, RF57 e RF58.
- **Reaproveitamento.** Autenticação, envio de e-mail transacional e auditoria são
  adaptados de um sistema existente do mesmo autor, por cópia — sem base de identidade
  compartilhada entre os dois produtos.

## Não-Objetivos (Fora de Escopo)

Fora deste PRD, previstos para PRDs seguintes:

- Agenda, reservas, clientes, mensalistas, cobranças da arena, caixa e indicadores.
- Matriz detalhada de permissões dos papéis da arena (gerente, atendente, financeiro).
  Aqui só existe `PROPRIETARIO`, porque é o único papel usado no piloto.
- Agendamento público e pagamento online.
- Venda de itens e rateio de cobrança entre pessoas.

Fora do produto neste momento, por decisão deliberada:

- **Autocadastro.** O provedor cria a organização e convida o proprietário.
- **Motor de cobrança recorrente.** Faturas são geradas por ação manual. Com dois
  clientes, uma rotina agendada é custo sem retorno.
- **Segundo fator de autenticação no backoffice.** Ferramenta de um único operador em
  um piloto de duas empresas; o esforço pertence à operação das arenas. Revisar quando
  houver staff além do provedor ou cliente pagante.
- **Gráficos e relatórios no painel.** Números e listas resolvem para esta escala.
- **Mesclagem de cadastros duplicados.**
- **Múltiplos idiomas e múltiplas moedas.**

## Questões em Aberto

1. **Validade do convite do proprietário** — sugestão de 7 dias, a confirmar.
2. **Duração da sessão de suporte** — sugestão de 60 minutos, a confirmar.
3. **Texto e tom do aviso de inadimplência** exibido para a arena, e o número de dias
   de tolerância padrão do plano.
4. **Confirmação jurídica do prazo de retenção de 12 meses** e redação da cláusula de
   acesso para suporte no termo de uso. Definido aqui como premissa de trabalho, não
   como orientação jurídica.
5. **Escopo do papel `SUPORTE`** — se ele deve poder iniciar sessão de suporte em modo
   escrita ou apenas leitura.
6. **Forma de cobrança da assinatura** — por espaço, por unidade ou por faixa de porte.
   Os limites são modelados como contadores genéricos justamente para manter a decisão
   em aberto.
