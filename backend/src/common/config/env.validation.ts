/**
 * Validação das variáveis obrigatórias na inicialização (RF09).
 * Falha rápido e com mensagem clara: variável faltando em produção é
 * incidente, não aviso.
 */
const SEMPRE_OBRIGATORIAS = [
  'DATABASE_URL',
  'CORS_ORIGIN_OPERACAO',
  'CORS_ORIGIN_BACKOFFICE',
] as const;

export function validarAmbiente(env: NodeJS.ProcessEnv): void {
  const faltando = SEMPRE_OBRIGATORIAS.filter((chave) => !env[chave]?.trim());

  if (faltando.length > 0) {
    throw new Error(
      `Variáveis de ambiente obrigatórias ausentes: ${faltando.join(', ')}. ` +
        'Consulte backend/.env.example.',
    );
  }

  if (env.NODE_ENV === 'production') {
    const origens = [env.CORS_ORIGIN_OPERACAO, env.CORS_ORIGIN_BACKOFFICE];

    for (const origem of origens) {
      if (origem === '*' || origem?.includes('*')) {
        throw new Error(
          'CORS com curinga não é permitido: o navegador recusa curinga junto ' +
            'com credenciais, e a lista de origens precisa ser explícita.',
        );
      }
      if (!origem?.startsWith('https://')) {
        throw new Error(
          `Origem de CORS inválida em produção: "${origem}". Use https.`,
        );
      }
    }
  }
}
