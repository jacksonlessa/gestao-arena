import { NextResponse, type NextRequest } from 'next/server';
import { PREFIXO, ehCaminhoFisico, superficiePorHost } from '@/lib/hosts';

const HOSTS = {
  operacao: process.env.NEXT_PUBLIC_HOST_OPERACAO,
  backoffice: process.env.NEXT_PUBLIC_HOST_BACKOFFICE,
};

/**
 * Roteamento por host (RF17 e RF18).
 *
 * Duas aplicações saem do mesmo build, servidas em hosts diferentes. O
 * middleware reescreve a requisição para o prefixo físico correspondente ao
 * host — e, tão importante quanto, **recusa o prefixo físico quando pedido
 * diretamente**. Sem essa segunda metade, `arenas.../backoffice` continuaria
 * servindo o backoffice e a separação não existiria de fato.
 */
export function middleware(request: NextRequest): NextResponse {
  const superficie = superficiePorHost(request.headers.get('host'), HOSTS);

  if (!superficie) {
    return new NextResponse('Host não reconhecido.', { status: 404 });
  }

  const { pathname } = request.nextUrl;

  if (ehCaminhoFisico(pathname)) {
    return new NextResponse('Not found', { status: 404 });
  }

  const url = request.nextUrl.clone();
  url.pathname = `${PREFIXO[superficie]}${pathname === '/' ? '' : pathname}`;

  return NextResponse.rewrite(url);
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
};
