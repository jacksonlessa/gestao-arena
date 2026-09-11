import type { ReactNode } from 'react';
import Link from 'next/link';

export default function PaginaBackoffice(): ReactNode {
  return (
    <main className="mx-auto flex max-w-2xl flex-col gap-4 p-8">
      <h1 className="text-xl font-semibold">Gestão de Arena — Backoffice</h1>
      <p className="text-sm text-neutral-500">
        Administração das organizações, assinaturas e acessos. Ainda sem
        funcionalidade: esta é a página mínima do PRD 00.
      </p>
      <Link href="/healthcheck" className="text-sm underline">
        Healthcheck
      </Link>
    </main>
  );
}
