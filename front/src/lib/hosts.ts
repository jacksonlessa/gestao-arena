export type Superficie = 'operacao' | 'backoffice';

/** Prefixo físico de rota de cada superfície dentro de `src/app`. */
export const PREFIXO: Record<Superficie, string> = {
  operacao: '/operacao',
  backoffice: '/backoffice',
};

export const ROTULO: Record<Superficie, string> = {
  operacao: 'Operação da arena',
  backoffice: 'Backoffice do provedor',
};

function normalizar(host: string): string {
  return host.split(':')[0].trim().toLowerCase();
}

/**
 * Resolve qual superfície um host representa. Retorna `null` para host
 * desconhecido — que o middleware trata como 404, em vez de servir uma
 * aplicação arbitrária.
 */
export function superficiePorHost(
  host: string | null,
  hosts: { operacao?: string; backoffice?: string },
): Superficie | null {
  if (!host) return null;

  const alvo = normalizar(host);

  if (hosts.backoffice && alvo === normalizar(hosts.backoffice)) {
    return 'backoffice';
  }
  if (hosts.operacao && alvo === normalizar(hosts.operacao)) {
    return 'operacao';
  }
  return null;
}

/** Verdadeiro quando o caminho pedido é o prefixo físico de alguma superfície. */
export function ehCaminhoFisico(pathname: string): boolean {
  return Object.values(PREFIXO).some(
    (prefixo) => pathname === prefixo || pathname.startsWith(`${prefixo}/`),
  );
}
