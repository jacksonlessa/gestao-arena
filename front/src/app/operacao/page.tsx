import type { ReactNode } from 'react';
import Link from 'next/link';

export default function PaginaOperacao(): ReactNode {
  return (
    <main className="mx-auto flex max-w-2xl flex-col gap-4 p-8">
      <h1 className="text-xl font-semibold">Gestão de Arena — Operação</h1>
      <p className="text-sm text-neutral-500">
        Agenda, reservas, clientes e caixa da arena. Ainda sem funcionalidade:
        esta é a página mínima do PRD 00.
      </p>
      <Link href="/healthcheck" className="text-sm underline">
        Healthcheck
      </Link>
    </main>
  );
}
